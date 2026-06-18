/**
 * @file config.h
 * @brief Central configuration for the ESP32 Raw Sensor Monitor.
 *
 * All pin definitions, BLE UUIDs, timing constants,
 * and shared data structures are defined here.
 */

#ifndef CONFIG_H
#define CONFIG_H

#include <Arduino.h>
#include <freertos/FreeRTOS.h>
#include <freertos/semphr.h>

// ──────────────────────────────────────────────
//  GPIO Pin Definitions
// ──────────────────────────────────────────────

// AD8232 Heart Rate Sensor
#define PIN_HR_OUTPUT       34   // Analog output (ADC1_CH6)
#define PIN_HR_LO_PLUS      25   // Leads-off detection +
#define PIN_HR_LO_MINUS     26   // Leads-off detection -

// GY-85 IMU (I2C)
#define PIN_I2C_SDA         21
#define PIN_I2C_SCL         22

// NEO-7M GPS (HardwareSerial2)
#define PIN_GPS_RX          16   // ESP32 RX ← GPS TX
#define PIN_GPS_TX          17   // ESP32 TX → GPS RX
#define GPS_BAUD            9600

// Active Buzzer (Active LOW: LOW = ON, HIGH = OFF)
#define PIN_BUZZER          27

// ──────────────────────────────────────────────
//  I2C Addresses (GY-85 Module)
// ──────────────────────────────────────────────
#define ADXL345_ADDR        0x53  // Accelerometer
#define ITG3200_ADDR        0x68  // Gyroscope
#define HMC5883L_ADDR       0x1E  // Magnetometer

// ──────────────────────────────────────────────
//  BLE UUIDs
// ──────────────────────────────────────────────
#define SERVICE_SPORT_UUID          "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c10"
#define CHAR_SENSOR_DATA_UUID       "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c11"
#define CHAR_GPS_DATA_UUID          "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c12"
#define CHAR_RAW_DATA_UUID          "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c14"

// BLE Device Name
#define BLE_DEVICE_NAME             "SportTrackerRaw"

// ──────────────────────────────────────────────
//  Shared Data Structures
// ──────────────────────────────────────────────

/**
 * @brief Processed sensor data for dashboard display.
 */
struct SensorData {
    uint16_t heartRate;     // Processed BPM
    uint32_t stepCount;
    uint32_t pushupCount;
    float    pitch;         // Posture pitch in degrees
    float    roll;          // Posture roll in degrees
};

/**
 * @brief GPS data shared between Core 1 (writer) and Core 0 (BLE reader).
 */
struct GPSData {
    double   latitude;
    double   longitude;
    float    speed;         // km/h
    float    distance;      // km (cumulative)
    uint8_t  satellites;
    uint8_t  fixValid;      // 1 = valid fix, 0 = no fix
};

/**
 * @brief Raw sensor data directly from hardware.
 */
struct RawSensorData {
    int16_t ax, ay, az;
    int16_t gx, gy, gz;
    int16_t mx, my, mz;     // Raw magnetometer values from HMC5883L
    uint16_t hrRaw;          // Raw ADC value from AD8232
};

// ──────────────────────────────────────────────
//  Extern Globals (defined in main.cpp)
// ──────────────────────────────────────────────
extern SemaphoreHandle_t xDataMutex;
extern SensorData        g_sensorData;
extern GPSData           g_gpsData;
extern RawSensorData     g_rawSensorData;
extern volatile bool     g_bleConnected;
extern volatile bool     g_gpsLockAcquired;

// ──────────────────────────────────────────────
//  Timing Constants (milliseconds)
// ──────────────────────────────────────────────
#define SENSOR_POLL_INTERVAL_MS     20    // 50 Hz for IMU
#define BLE_NOTIFY_INTERVAL_MS      20    // 50 Hz BLE notifications
#define BUZZER_TICK_INTERVAL_MS     10    // 100 Hz buzzer state machine
#define HR_SAMPLE_RATE_MS           5     // 200 Hz analog sampling

// FreeRTOS Task Stack Sizes
#define STACK_SIZE_BLE              4096
#define STACK_SIZE_SENSOR           4096
#define STACK_SIZE_HR               2048
#define STACK_SIZE_GPS              2048
#define STACK_SIZE_BUZZER           1024

#endif // CONFIG_H
