/**
 * @file imu_sensor.h
 * @brief GY-85 (ADXL345 + ITG3200 + HMC5883L) IMU driver interface.
 *
 * Provides raw I2C register-level access to all three sensors on the
 * GY-85 module. No external IMU library required.
 */

#ifndef IMU_SENSOR_H
#define IMU_SENSOR_H

#include <Arduino.h>

/**
 * @brief Raw IMU readings from all three GY-85 sensors.
 */
struct IMURawData {
    // ADXL345 Accelerometer (raw counts → ±16g range)
    int16_t ax, ay, az;

    // ITG3200 Gyroscope (raw counts → ±2000 °/s)
    int16_t gx, gy, gz;

    // HMC5883L Magnetometer (raw counts)
    int16_t mx, my, mz;
};

/**
 * @brief Initialize I2C and configure all three GY-85 sensors.
 * @return true if all sensors responded on the I2C bus.
 */
bool imu_init();

/**
 * @brief Read raw data from all three sensors.
 * @param[out] data  Populated with raw accelerometer, gyroscope, and magnetometer values.
 * @return true on successful read.
 */
bool imu_read(IMURawData &data);

/**
 * @brief Convert raw accelerometer counts to G-force.
 * @param raw  Raw ADC count from ADXL345 (±16g, 13-bit).
 * @return Acceleration in g.
 */
float imu_accel_to_g(int16_t raw);

/**
 * @brief Convert raw gyroscope counts to degrees per second.
 * @param raw  Raw ADC count from ITG3200.
 * @return Angular rate in °/s.
 */
float imu_gyro_to_dps(int16_t raw);

#endif // IMU_SENSOR_H
