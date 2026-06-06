/**
 * @file main.cpp
 * @brief Entry point for the ESP32 Sports Tracker firmware.
 *
 * Creates FreeRTOS tasks pinned to specific cores:
 *   Core 0: BLE task (GATT notifications)
 *   Core 1: Sensor task (IMU + HR), GPS task, Buzzer task
 *
 * Shared data protected by xDataMutex.
 */

#include <Arduino.h>
#include "config.h"
#include "ble_server.h"
#include "imu_sensor.h"
#include "gps_sensor.h"
#include "hr_sensor.h"
#include "sport_algo.h"
#include "buzzer.h"

// ──────────────────────────────────────────────
//  Global Shared Data (declared extern in config.h)
// ──────────────────────────────────────────────
SemaphoreHandle_t xDataMutex    = nullptr;
SensorData        g_sensorData  = {0, 0, 0, 0.0f, 0.0f};
GPSData           g_gpsData     = {0.0, 0.0, 0.0f, 0.0f, 0, 0};
CommandData       g_commandData = {MODE_IDLE, 180};
RawSensorData     g_rawSensorData = {0, 0, 0, 0, 0, 0, 0};
volatile bool     g_bleConnected    = false;
volatile bool     g_gpsLockAcquired = false;
volatile unsigned long g_hrMutedUntil = 0;

// Track if GPS lock buzzer has already fired
static volatile bool s_gpsLockBuzzed = false;

// ──────────────────────────────────────────────
//  Task: Sensor Polling (Core 1, 50 Hz)
//  Reads IMU + HR, runs sport algorithms,
//  writes to shared data under mutex.
// ──────────────────────────────────────────────
void taskSensor(void *param) {
    (void)param;
    TickType_t xLastWake = xTaskGetTickCount();
    unsigned long lastSensorUs = micros();

    for (;;) {
        unsigned long nowUs = micros();
        float dt = (nowUs - lastSensorUs) / 1000000.0f;
        lastSensorUs = nowUs;

        // ── Read IMU ──
        IMURawData imuRaw;
        bool imuOk = imu_read(imuRaw);

        // ── Read HR (from dedicated HR task) ──
        uint16_t bpm = hr_get_bpm();

        // ── Run algorithms based on sport mode ──
        SportMode currentMode;
        uint16_t  currentMaxHR;
        if (xSemaphoreTake(xDataMutex, pdMS_TO_TICKS(5)) == pdTRUE) {
            currentMode  = g_commandData.sportMode;
            currentMaxHR = g_commandData.maxHR;
            xSemaphoreGive(xDataMutex);
        } else {
            currentMode  = MODE_IDLE;
            currentMaxHR = 180;
        }

        PostureData posture = {0.0f, 0.0f};

        if (imuOk && currentMode != MODE_IDLE) {
            // Rep counting modes
            if (currentMode == MODE_RUNNING) {
                algo_detect_step(imuRaw);
            } else if (currentMode == MODE_JUMP_ROPE) {
                algo_detect_jump(imuRaw);
            } else if (currentMode == MODE_PUSHUP) {
                algo_detect_pushup(imuRaw);
            } else if (currentMode == MODE_SQUAT) {
                algo_detect_squat(imuRaw);
            }

            // Posture tracking (Calculated for all active modes)
            posture = algo_update_posture(imuRaw, dt);
                
            if (currentMode == MODE_PLANK) {
                uint8_t warning = algo_check_plank_posture(posture.pitch);
                if (warning == 1 && !buzzer_is_playing()) {
                    buzzer_trigger(BUZZ_HR_WARNING); // Double beep
                }
            }
            
            // General Posture Warning Timer (for all active modes except Plank which has its own logic)
            static unsigned long s_badPostureStartTime = 0;
            static bool s_badPostureActive = false;

            if (currentMode != MODE_PLANK && currentMode != MODE_HR_MONITOR && currentMode != MODE_PUSHUP && currentMode != MODE_SQUAT) {
                if (fabs(posture.pitch) > POSTURE_MAX_ANGLE || fabs(posture.roll) > POSTURE_MAX_ANGLE) {
                    if (!s_badPostureActive) {
                        s_badPostureActive = true;
                        s_badPostureStartTime = millis();
                    } else if (millis() - s_badPostureStartTime >= POSTURE_WARN_DELAY_MS) {
                        if (!buzzer_is_playing() || buzzer_get_pattern() == BUZZ_POSTURE_WARN) {
                            if (buzzer_get_pattern() != BUZZ_POSTURE_WARN) {
                                buzzer_trigger(BUZZ_POSTURE_WARN);
                            }
                        }
                    }
                } else {
                    s_badPostureActive = false;
                    if (buzzer_get_pattern() == BUZZ_POSTURE_WARN) {
                        buzzer_stop();
                    }
                }
            } else {
                // If switching out of a posture-tracked mode, clear the posture buzzer
                s_badPostureActive = false;
                if (buzzer_get_pattern() == BUZZ_POSTURE_WARN) {
                    buzzer_stop();
                }
            }
        }

        // ── HR Warning Check ──
        static unsigned long s_hrWarnStartTime = 0;
        static bool s_hrWarnActive = false;
        
        if (bpm > 0 && currentMaxHR > 0 && bpm > currentMaxHR) {
            unsigned long currentMs = millis();
            if (currentMs >= g_hrMutedUntil) {
                if (!s_hrWarnActive) {
                    s_hrWarnActive = true;
                    s_hrWarnStartTime = currentMs;
                }
                
                unsigned long elapsed = currentMs - s_hrWarnStartTime;
                if (elapsed < HR_WARN_ACTIVE_MS) {
                    // Active buzzing phase
                    if (!buzzer_is_playing()) {
                        buzzer_trigger(BUZZ_HR_WARNING);
                    }
                } else if (elapsed < HR_WARN_ACTIVE_MS + HR_WARN_COOLDOWN_MS) {
                    // Cooldown phase
                    if (buzzer_is_playing() && buzzer_get_pattern() == BUZZ_HR_WARNING) {
                        buzzer_stop();
                    }
                } else {
                    // Reset cycle
                    s_hrWarnStartTime = currentMs;
                }
            }
        } else {
            // HR is normal, reset state
            s_hrWarnActive = false;
            if (buzzer_is_playing() && buzzer_get_pattern() == BUZZ_HR_WARNING) {
                buzzer_stop();
            }
        }

        // ── Update shared sensor data ──
        if (xSemaphoreTake(xDataMutex, pdMS_TO_TICKS(5)) == pdTRUE) {
            g_sensorData.heartRate = bpm;
            g_sensorData.stepCount = algo_get_steps();
            
            // Reuse jumpCount for reps or plank posture flag
            if (currentMode == MODE_PLANK) {
                // Use cached posture from algo_update_posture above
                g_sensorData.jumpCount = algo_check_plank_posture(posture.pitch);
            } else {
                g_sensorData.jumpCount = algo_get_reps();
            }
            
            g_sensorData.pitch     = posture.pitch;
            g_sensorData.roll      = posture.roll;
            
            // Update raw IMU data
            if (imuOk) {
                g_rawSensorData.ax = imuRaw.ax;
                g_rawSensorData.ay = imuRaw.ay;
                g_rawSensorData.az = imuRaw.az;
                g_rawSensorData.gx = imuRaw.gx;
                g_rawSensorData.gy = imuRaw.gy;
                g_rawSensorData.gz = imuRaw.gz;
            }
            xSemaphoreGive(xDataMutex);
        }

        vTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(SENSOR_POLL_INTERVAL_MS));
    }
}

// ──────────────────────────────────────────────
//  Task: GPS Polling (Core 1, 1 Hz)
// ──────────────────────────────────────────────
void taskGPS(void *param) {
    (void)param;
    TickType_t xLastWake = xTaskGetTickCount();

    for (;;) {
        GPSOutput gpsOut;
        gps_update(gpsOut);

        // GPS lock buzzer (once)
        if (gpsOut.fixValid && !s_gpsLockBuzzed) {
            s_gpsLockBuzzed = true;
            g_gpsLockAcquired = true;
            buzzer_trigger(BUZZ_GPS_LOCK);
            Serial.println("[GPS] Fix acquired!");
        }

        // Update shared GPS data
        if (xSemaphoreTake(xDataMutex, pdMS_TO_TICKS(5)) == pdTRUE) {
            g_gpsData.latitude   = gpsOut.latitude;
            g_gpsData.longitude  = gpsOut.longitude;
            g_gpsData.speed      = gpsOut.speedKmh;
            g_gpsData.distance   = gpsOut.distanceKm;
            g_gpsData.satellites = gpsOut.satellites;
            g_gpsData.fixValid   = gpsOut.fixValid ? 1 : 0;
            xSemaphoreGive(xDataMutex);
        }

        // Poll every 100ms (10Hz) to drain UART buffer frequently
        // and prevent NMEA data loss from higher-priority tasks
        vTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(100));
    }
}

// ──────────────────────────────────────────────
//  Task: BLE Notifications (Core 0, 2 Hz)
// ──────────────────────────────────────────────
void taskBLE(void *param) {
    (void)param;
    TickType_t xLastWake = xTaskGetTickCount();
    for (;;) {
        // Notify sensor + GPS data
        ble_notify_sensors();
        ble_notify_gps();
        ble_notify_raw();

        vTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(BLE_NOTIFY_INTERVAL_MS));
    }
}

// ──────────────────────────────────────────────
//  Task: HR Sampling (Core 1, 200 Hz)
//  Dedicated task for AD8232 analog sampling at
//  the correct rate for R-wave peak detection.
// ──────────────────────────────────────────────
void taskHR(void *param) {
    (void)param;
    TickType_t xLastWake = xTaskGetTickCount();

    for (;;) {
        hr_update();
        
        uint16_t adcVal = analogRead(PIN_HR_OUTPUT);
        if (xSemaphoreTake(xDataMutex, pdMS_TO_TICKS(1)) == pdTRUE) {
            g_rawSensorData.hrRaw = adcVal;
            xSemaphoreGive(xDataMutex);
        }
        
        vTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(HR_SAMPLE_RATE_MS));
    }
}

// ──────────────────────────────────────────────
//  Task: Buzzer State Machine (Core 1, 100 Hz)
// ──────────────────────────────────────────────
void taskBuzzer(void *param) {
    (void)param;
    TickType_t xLastWake = xTaskGetTickCount();

    for (;;) {
        buzzer_update();
        vTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(BUZZER_TICK_INTERVAL_MS));
    }
}

// Guard against test builds (test files provide their own setup/loop)
#ifndef UNIT_TEST

// ──────────────────────────────────────────────
//  Arduino Setup
// ──────────────────────────────────────────────
void setup() {
    Serial.begin(115200);
    delay(500);
    Serial.println("\n========================================");
    Serial.println("   ESP32 Sports Tracker - Booting...");
    Serial.println("========================================\n");

    // Create mutex
    xDataMutex = xSemaphoreCreateMutex();

    // Initialize all peripherals
    buzzer_init();
    buzzer_trigger(BUZZ_POWER_ON);

    bool imuOk = imu_init();
    if (!imuOk) {
        Serial.println("[MAIN] WARNING: IMU init failed!");
    }

    gps_init();
    hr_init();
    algo_init();
    ble_init();

    Serial.println("\n[MAIN] All systems initialized.");
    Serial.println("[MAIN] Creating FreeRTOS tasks...\n");

    // ── Create tasks pinned to cores ──

    // Core 0: BLE (priority 1)
    xTaskCreatePinnedToCore(
        taskBLE, "TaskBLE",
        STACK_SIZE_BLE, nullptr, 1, nullptr,
        0  // Core 0
    );

    // Core 1: Sensor polling (priority 2 — highest on this core)
    xTaskCreatePinnedToCore(
        taskSensor, "TaskSensor",
        STACK_SIZE_SENSOR, nullptr, 2, nullptr,
        1  // Core 1
    );

    // Core 1: GPS polling (priority 1)
    xTaskCreatePinnedToCore(
        taskGPS, "TaskGPS",
        STACK_SIZE_GPS, nullptr, 1, nullptr,
        1  // Core 1
    );

    // Core 1: HR sampling at 200 Hz (priority 3 — highest, timing-critical)
    xTaskCreatePinnedToCore(
        taskHR, "TaskHR",
        STACK_SIZE_HR, nullptr, 3, nullptr,
        1  // Core 1
    );

    // Core 1: Buzzer (priority 1 — low, non-timing-critical)
    xTaskCreatePinnedToCore(
        taskBuzzer, "TaskBuzzer",
        STACK_SIZE_BUZZER, nullptr, 1, nullptr,
        1  // Core 1
    );

    Serial.println("[MAIN] All tasks started. Entering idle loop.");
}

// ──────────────────────────────────────────────
//  Arduino Loop (empty — all work in tasks)
// ──────────────────────────────────────────────
void loop() {
    vTaskDelay(pdMS_TO_TICKS(1000));
}

#endif // UNIT_TEST
