/**
 * @file hr_sensor.h
 * @brief AD8232 ECG heart rate sensor driver interface.
 *
 * Reads the analog output of the AD8232 module and performs peak
 * detection to compute beats-per-minute (BPM). Includes leads-off
 * detection via LO+/LO- pins.
 */

#ifndef HR_SENSOR_H
#define HR_SENSOR_H

#include <Arduino.h>

/**
 * @brief Initialize ADC and leads-off detection pins.
 */
void hr_init();

/**
 * @brief Process one analog sample and update BPM calculation.
 * Must be called at a consistent rate (e.g., every 5ms / 200 Hz).
 *
 * @return Current BPM (0 if leads are off or no valid reading yet).
 */
uint16_t hr_update();

/**
 * @brief Check if the electrode leads are properly connected.
 * @return true if leads are ON (good contact), false if leads are OFF.
 */
bool hr_leads_on();

/**
 * @brief Get the last computed BPM without triggering a new sample.
 */
uint16_t hr_get_bpm();

#endif // HR_SENSOR_H
