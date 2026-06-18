/**
 * @file main.cpp
 * @brief Entry point for the ESP32 Raw Sensor Monitor firmware.
 *
 * Creates FreeRTOS tasks pinned to specific cores:
 *   Core 0: BLE task (GATT notifications)
 *   Core 1: Sensor task (IMU + algorithms), HR task (ADC), GPS task, Buzzer task
 *
 * Reads raw data from all sensors, runs sport algorithms,
 * and transmits both raw + processed data via BLE.
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
SemaphoreHandle_t xDataMutex      = nullptr;
SensorData        g_sensorData    = {0, 0, 0, 0.0f, 0.0f};
GPSData           g_gpsData       = {0.0, 0.0, 0.0f, 0.0f, 0, 0};
RawSensorData     g_rawSensorData = {0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
volatile bool     g_bleConnected    = false;
volatile bool     g_gpsLockAcquired = false;

// Track if GPS lock buzzer has already fired
static volatile bool s_gpsLockBuzzed = false;

// ──────────────────────────────────────────────
//  Task: IMU Polling (Core 1, 50 Hz)
//  Reads raw IMU, runs step/pushup/posture algorithms.
// ──────────────────────────────────────────────
void taskSensor(void *param) {
    (void)param;
    TickType_t xLastWake = xTaskGetTickCount();
    unsigned long lastSensorUs = micros();

    for (;;) {
        unsigned long nowUs = micros();
        float dt = (nowUs - lastSensorUs) / 1000000.0f;
        lastSensorUs = nowUs;

        IMURawData imuRaw;
        bool imuOk = imu_read(imuRaw);

        PostureData posture = {0.0f, 0.0f};

        if (imuOk) {
            // Always run algorithms (no mode switching)
            algo_detect_step(imuRaw);
            algo_detect_pushup(imuRaw);
            posture = algo_update_posture(imuRaw, dt);
        }

        if (xSemaphoreTake(xDataMutex, pdMS_TO_TICKS(5)) == pdTRUE) {
            // Update raw IMU data
            if (imuOk) {
                g_rawSensorData.ax = imuRaw.ax;
                g_rawSensorData.ay = imuRaw.ay;
                g_rawSensorData.az = imuRaw.az;
                g_rawSensorData.gx = imuRaw.gx;
                g_rawSensorData.gy = imuRaw.gy;
                g_rawSensorData.gz = imuRaw.gz;
                g_rawSensorData.mx = imuRaw.mx;
                g_rawSensorData.my = imuRaw.my;
                g_rawSensorData.mz = imuRaw.mz;
            }

            // Update processed data
            g_sensorData.stepCount   = algo_get_steps();
            g_sensorData.pushupCount = algo_get_reps();
            g_sensorData.pitch       = posture.pitch;
            g_sensorData.roll        = posture.roll;

            xSemaphoreGive(xDataMutex);
        }

        vTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(SENSOR_POLL_INTERVAL_MS));
    }
}

// ──────────────────────────────────────────────
//  Task: HR Sampling (Core 1, 200 Hz)
//  Reads raw ADC value from AD8232 and computes BPM.
// ──────────────────────────────────────────────
void taskHR(void *param) {
    (void)param;
    TickType_t xLastWake = xTaskGetTickCount();

    for (;;) {
        uint16_t bpm = hr_update();
        uint16_t adcVal = analogRead(PIN_HR_OUTPUT);

        if (xSemaphoreTake(xDataMutex, pdMS_TO_TICKS(1)) == pdTRUE) {
            g_rawSensorData.hrRaw = adcVal;
            g_sensorData.heartRate = bpm;
            xSemaphoreGive(xDataMutex);
        }

        vTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(HR_SAMPLE_RATE_MS));
    }
}

// ──────────────────────────────────────────────
//  Task: GPS Polling (Core 1, 10 Hz)
//  Reads position, speed, satellites from NEO-7M.
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

        vTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(100));
    }
}

// ──────────────────────────────────────────────
//  Task: BLE Notifications (Core 0)
//  Sends raw + processed sensor data to client.
// ──────────────────────────────────────────────
void taskBLE(void *param) {
    (void)param;
    TickType_t xLastWake = xTaskGetTickCount();

    for (;;) {
        ble_notify_raw();
        ble_notify_sensors();
        ble_notify_gps();
        vTaskDelayUntil(&xLastWake, pdMS_TO_TICKS(BLE_NOTIFY_INTERVAL_MS));
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
    Serial.println("   ESP32 Raw Sensor Monitor - Booting...");
    Serial.println("========================================\n");

    // Create mutex
    xDataMutex = xSemaphoreCreateMutex();

    // Initialize peripherals
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

    // Core 0: BLE (priority 1)
    xTaskCreatePinnedToCore(
        taskBLE, "TaskBLE",
        STACK_SIZE_BLE, nullptr, 1, nullptr, 0
    );

    // Core 1: IMU polling (priority 2)
    xTaskCreatePinnedToCore(
        taskSensor, "TaskSensor",
        STACK_SIZE_SENSOR, nullptr, 2, nullptr, 1
    );

    // Core 1: GPS polling (priority 1)
    xTaskCreatePinnedToCore(
        taskGPS, "TaskGPS",
        STACK_SIZE_GPS, nullptr, 1, nullptr, 1
    );

    // Core 1: HR sampling at 200 Hz (priority 3 — timing-critical)
    xTaskCreatePinnedToCore(
        taskHR, "TaskHR",
        STACK_SIZE_HR, nullptr, 3, nullptr, 1
    );

    // Core 1: Buzzer (priority 1)
    xTaskCreatePinnedToCore(
        taskBuzzer, "TaskBuzzer",
        STACK_SIZE_BUZZER, nullptr, 1, nullptr, 1
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
