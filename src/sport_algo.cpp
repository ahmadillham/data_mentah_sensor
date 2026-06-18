/**
 * @file sport_algo.cpp
 * @brief Sport algorithms: step/jump counting and posture.
 */

#include "sport_algo.h"
#include "config.h"
#include <math.h>

// Algorithm constants (local to this module)
#define STEP_THRESHOLD              1.25f
#define STEP_DEBOUNCE_MS            300
#define JUMP_THRESHOLD              1.90f
#define JUMP_DEBOUNCE_MS            0
#define PUSHUP_THRESHOLD            1.25f
#define PUSHUP_DEBOUNCE_MS          1000
#define SQUAT_THRESHOLD             1.15f
#define SQUAT_DEBOUNCE_MS           800
#define PLANK_ANGLE_TOLERANCE       15.0f
#define COMPLEMENTARY_ALPHA         0.96f
#define IMU_PITCH_OFFSET            -13.3f
#define IMU_ROLL_OFFSET             -3.7f

static uint32_t s_stepCount = 0;
static float    s_stepFiltered = 1.0f;
static bool     s_stepAbove = false;
static unsigned long s_lastStepMs = 0;

static uint32_t s_repCount = 0; // Shared for jumps, push-ups, squats
static float    s_repFiltered = 1.0f;
static bool     s_repAbove = false;
static unsigned long s_lastRepMs = 0;

static float s_pitch = 0.0f;
static float s_roll  = 0.0f;
static bool  s_postureInit = false;

static float s_plankInitialPitch = 0.0f;
static bool  s_plankInit = false;

#define EMA_ALPHA  0.3f

void algo_init() {
    s_stepCount = 0; s_repCount = 0;
    s_stepFiltered = 1.0f; s_repFiltered = 1.0f;
    s_stepAbove = false; s_repAbove = false;
    s_lastStepMs = 0; s_lastRepMs = 0;
    s_postureInit = false;
    s_plankInit = false;
}

bool algo_detect_step(const IMURawData &data) {
    float ax = imu_accel_to_g(data.ax);
    float ay = imu_accel_to_g(data.ay);
    float az = imu_accel_to_g(data.az);
    float mag = sqrtf(ax*ax + ay*ay + az*az);
    s_stepFiltered = EMA_ALPHA * mag + (1.0f - EMA_ALPHA) * s_stepFiltered;

    unsigned long now = millis();
    if (s_stepFiltered > STEP_THRESHOLD && !s_stepAbove) {
        s_stepAbove = true;
    } else if (s_stepFiltered < (STEP_THRESHOLD - 0.15f) && s_stepAbove) {
        s_stepAbove = false;
        if (now - s_lastStepMs >= STEP_DEBOUNCE_MS) {
            s_stepCount++;
            s_lastStepMs = now;
            return true;
        }
    }
    return false;
}

bool algo_detect_jump(const IMURawData &data) {
    float ax = imu_accel_to_g(data.ax);
    float ay = imu_accel_to_g(data.ay);
    float az = imu_accel_to_g(data.az);
    float mag = sqrtf(ax*ax + ay*ay + az*az);
    s_repFiltered = EMA_ALPHA * mag + (1.0f - EMA_ALPHA) * s_repFiltered;

    unsigned long now = millis();
    if (s_repFiltered > JUMP_THRESHOLD && !s_repAbove) {
        s_repAbove = true;
    } else if (s_repFiltered < (JUMP_THRESHOLD - 0.2f) && s_repAbove) {
        s_repAbove = false;
        if (now - s_lastRepMs >= JUMP_DEBOUNCE_MS) {
            s_repCount++;
            s_lastRepMs = now;
            return true;
        }
    }
    return false;
}

PostureData algo_update_posture(const IMURawData &data, float dt) {
    float ax = imu_accel_to_g(data.ax);
    float ay = imu_accel_to_g(data.ay);
    float az = imu_accel_to_g(data.az);
    float gx = imu_gyro_to_dps(data.gx);
    float gy = imu_gyro_to_dps(data.gy);
    float gz = imu_gyro_to_dps(data.gz);

    // Y pointing downwards (ay = -1g) is 0 degrees.
    // Leaning forward/backwards (Pitch) rotates around X-axis.
    float accelPitch = (atan2f(-az, -ay) * 180.0f / M_PI) - IMU_PITCH_OFFSET;
    
    // Leaning left/right (Roll) rotates around Z-axis.
    float accelRoll  = (atan2f(-ax, -ay) * 180.0f / M_PI) - IMU_ROLL_OFFSET;

    if (!s_postureInit) {
        s_pitch = accelPitch;
        s_roll  = accelRoll;
        s_postureInit = true;
    } else {
        // Pitch uses gx (rotation around X axis)
        s_pitch = COMPLEMENTARY_ALPHA * (s_pitch + gx * dt) +
                  (1.0f - COMPLEMENTARY_ALPHA) * accelPitch;
        // Roll uses gz (rotation around Z axis)
        s_roll  = COMPLEMENTARY_ALPHA * (s_roll  + gz * dt) +
                  (1.0f - COMPLEMENTARY_ALPHA) * accelRoll;
    }

    PostureData p;
    p.pitch = s_pitch;
    p.roll  = s_roll;
    return p;
}

uint32_t algo_get_steps() { return s_stepCount; }
uint32_t algo_get_reps() { return s_repCount; }

void algo_reset_counters() {
    s_stepCount = 0; s_repCount = 0;
    s_stepFiltered = 1.0f; s_repFiltered = 1.0f;
    s_stepAbove = false; s_repAbove = false;
    s_lastStepMs = 0; s_lastRepMs = 0;
    s_plankInit = false;
}

bool algo_detect_pushup(const IMURawData &data) {
    float ax = imu_accel_to_g(data.ax);
    float ay = imu_accel_to_g(data.ay);
    float az = imu_accel_to_g(data.az);
    float mag = sqrtf(ax*ax + ay*ay + az*az);
    s_repFiltered = EMA_ALPHA * mag + (1.0f - EMA_ALPHA) * s_repFiltered;

    unsigned long now = millis();
    if (s_repFiltered > PUSHUP_THRESHOLD && !s_repAbove) {
        s_repAbove = true;
    } else if (s_repFiltered < (PUSHUP_THRESHOLD - 0.15f) && s_repAbove) {
        s_repAbove = false;
        if (now - s_lastRepMs >= PUSHUP_DEBOUNCE_MS) {
            s_repCount++;
            s_lastRepMs = now;
            return true;
        }
    }
    return false;
}

bool algo_detect_squat(const IMURawData &data) {
    float ax = imu_accel_to_g(data.ax);
    float ay = imu_accel_to_g(data.ay);
    float az = imu_accel_to_g(data.az);
    float mag = sqrtf(ax*ax + ay*ay + az*az);
    s_repFiltered = EMA_ALPHA * mag + (1.0f - EMA_ALPHA) * s_repFiltered;

    unsigned long now = millis();
    if (s_repFiltered > SQUAT_THRESHOLD && !s_repAbove) {
        s_repAbove = true;
    } else if (s_repFiltered < (SQUAT_THRESHOLD - 0.15f) && s_repAbove) {
        s_repAbove = false;
        if (now - s_lastRepMs >= SQUAT_DEBOUNCE_MS) {
            s_repCount++;
            s_lastRepMs = now;
            return true;
        }
    }
    return false;
}

uint8_t algo_check_plank_posture(float pitch) {
    if (!s_plankInit) {
        s_plankInitialPitch = pitch;
        s_plankInit = true;
        return 0; // Good
    }

    if (fabs(pitch - s_plankInitialPitch) > PLANK_ANGLE_TOLERANCE) {
        return 1; // Warning: Hips sagging or raised
    }
    return 0; // Good
}
