/**
 * @file config.h
 * @brief Central configuration for the ESP32 Sports Tracker.
 *
 * All pin definitions, BLE UUIDs, timing constants, sport mode enums,
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

// Custom Sport Service
#define SERVICE_SPORT_UUID          "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c10"
#define CHAR_SENSOR_DATA_UUID       "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c11"
#define CHAR_GPS_DATA_UUID          "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c12"
#define CHAR_COMMAND_UUID           "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c13"
#define CHAR_RAW_DATA_UUID          "6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c14"

// BLE Device Name
#define BLE_DEVICE_NAME             "SportTrackerRaw"

// ──────────────────────────────────────────────
//  Sport Mode Enum
// ──────────────────────────────────────────────
enum SportMode : uint8_t {
    MODE_IDLE       = 0x00,
    MODE_RUNNING    = 0x01,
    MODE_CYCLING    = 0x02,
    MODE_JUMP_ROPE  = 0x03,
    MODE_PUSHUP     = 0x04,
    MODE_SQUAT      = 0x05,
    MODE_PLANK      = 0x06,
    MODE_HR_MONITOR = 0x07,
    MODE_POSTURE    = 0x08
};

// ──────────────────────────────────────────────
//  Shared Data Structures
// ──────────────────────────────────────────────

/**
 * @brief Sensor data shared between Core 1 (writer) and Core 0 (BLE reader).
 */
struct SensorData {
    uint16_t heartRate;     // BPM (0 = leads off)
    uint32_t stepCount;     // Running steps
    uint32_t jumpCount;     // Jump rope reps
    float    pitch;         // Posture: pitch in degrees
    float    roll;          // Posture: roll in degrees
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
 * @brief Command data received from the phone via BLE RX characteristic.
 */
struct CommandData {
    SportMode sportMode;
    uint16_t  maxHR;        // Maximum heart rate threshold for warning
};

/**
 * @brief Raw sensor data directly from hardware.
 */
struct RawSensorData {
    int16_t ax, ay, az;
    int16_t gx, gy, gz;
    uint16_t hrRaw;         // Raw ADC value from AD8232
};

// ──────────────────────────────────────────────
//  Extern Globals (defined in main.cpp)
// ──────────────────────────────────────────────
extern SemaphoreHandle_t xDataMutex;
extern SensorData        g_sensorData;
extern GPSData           g_gpsData;
extern CommandData       g_commandData;
extern RawSensorData     g_rawSensorData;
extern volatile bool     g_bleConnected;
extern volatile bool     g_gpsLockAcquired;
extern volatile unsigned long g_hrMutedUntil;

// ──────────────────────────────────────────────
//  Timing Constants (milliseconds)
// ──────────────────────────────────────────────
#define SENSOR_POLL_INTERVAL_MS     20    // 50 Hz for IMU + HR
#define BLE_NOTIFY_INTERVAL_MS      20    // 50 Hz BLE notifications (Real-time over USB)
#define BUZZER_TICK_INTERVAL_MS     10    // 100 Hz buzzer state machine

// ──────────────────────────────────────────────
//  Algorithm Constants
// ──────────────────────────────────────────────

// Step detection
#define STEP_THRESHOLD              1.25f   // G-force threshold for step peak
#define STEP_DEBOUNCE_MS            300     // Minimum ms between steps

// Jump detection
#define JUMP_THRESHOLD              1.90f   // G-force threshold for jump peak
#define JUMP_DEBOUNCE_MS            0       // Disabled as requested (was 450)

// Push-up detection
#define PUSHUP_THRESHOLD            1.25f   // G-force threshold for push-up peak
#define PUSHUP_DEBOUNCE_MS          1000    // Minimum ms between push-ups

// Squat detection
#define SQUAT_THRESHOLD             1.15f   // G-force threshold for squat peak
#define SQUAT_DEBOUNCE_MS           800     // Minimum ms between squats

// Plank & Posture
#define PLANK_ANGLE_TOLERANCE       15.0f   // Max degrees of deviation before warning
#define POSTURE_MAX_ANGLE           15.0f   // Max degrees for general posture (pitch/roll)
#define POSTURE_WARN_DELAY_MS       5000    // 5 seconds delay before buzzer sounds

// HR detection
#define HR_SAMPLE_RATE_MS           5       // 200 Hz analog sampling
#define HR_DERIV_MIN_THRESH         1500.0f // Minimum squared derivative threshold
#define HR_MIN_IBI_MS               300     // Min inter-beat interval (200 BPM max)
#define HR_MAX_IBI_MS               1500    // Max inter-beat interval (40 BPM min)
#define HR_TIMEOUT_MS               3000    // No peak for 3s = signal lost
#define HR_WARN_ACTIVE_MS           30000   // Warning buzzes for 30s
#define HR_WARN_COOLDOWN_MS         30000   // Warning rests for 30s
#define HR_WARN_MUTE_DURATION_MS    300000  // Muted via app for 5 mins

// Posture complementary filter
#define COMPLEMENTARY_ALPHA         0.96f

// IMU Calibration Offsets (in degrees)
#define IMU_PITCH_OFFSET            -13.3f
#define IMU_ROLL_OFFSET             -3.7f

// FreeRTOS Task Stack Sizes
#define STACK_SIZE_BLE              4096
#define STACK_SIZE_SENSOR           4096
#define STACK_SIZE_HR               2048
#define STACK_SIZE_GPS              2048
#define STACK_SIZE_BUZZER           1024

#endif // CONFIG_H
