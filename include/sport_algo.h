/**
 * @file sport_algo.h
 * @brief Sport-specific algorithms: step counting, jump counting, posture.
 *
 * Uses accelerometer magnitude peak detection for step/jump counting
 * and complementary filter for stable pitch/roll posture angles.
 */

#ifndef SPORT_ALGO_H
#define SPORT_ALGO_H

#include <Arduino.h>
#include "imu_sensor.h"

/**
 * @brief Processed posture angles.
 */
struct PostureData {
    float pitch;    // degrees, nose up = positive
    float roll;     // degrees, right side down = positive
};

/**
 * @brief Initialize algorithm state (counters, filters).
 */
void algo_init();

/**
 * @brief Process one IMU sample for step detection.
 * Uses acceleration magnitude peak detection with debouncing.
 *
 * @param data  Raw IMU data from imu_read().
 * @return true if a new step was detected on this call.
 */
bool algo_detect_step(const IMURawData &data);

/**
 * @brief Process one IMU sample for jump detection.
 * Similar to step detection but with higher threshold tuned for jumps.
 *
 * @param data  Raw IMU data from imu_read().
 * @return true if a new jump was detected on this call.
 */
bool algo_detect_jump(const IMURawData &data);

/**
 * @brief Update posture angles using complementary filter.
 *
 * @param data  Raw IMU data from imu_read().
 * @param dt    Time delta in seconds since last call.
 * @return Filtered pitch and roll angles.
 */
PostureData algo_update_posture(const IMURawData &data, float dt);

/**
 * @brief Process one IMU sample for push-up detection.
 */
bool algo_detect_pushup(const IMURawData &data);

/**
 * @brief Process one IMU sample for squat detection.
 */
bool algo_detect_squat(const IMURawData &data);

/**
 * @brief Check if current plank posture deviates from initial capture.
 * @param pitch Current pitch from algo_update_posture
 * @return 0 for Good, 1 for Warning
 */
uint8_t algo_check_plank_posture(float pitch);

/**
 * @brief Get current step count.
 */
uint32_t algo_get_steps();

/**
 * @brief Get current generic rep count (used for jumps, push-ups, squats).
 */
uint32_t algo_get_reps();

/**
 * @brief Reset step and jump counters to zero.
 */
void algo_reset_counters();

#endif // SPORT_ALGO_H
