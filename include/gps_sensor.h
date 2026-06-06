/**
 * @file gps_sensor.h
 * @brief NEO-7M GPS driver interface using TinyGPS++.
 *
 * Wraps TinyGPS++ parsing of NMEA sentences from HardwareSerial2.
 * Provides position, speed, satellite count, and cumulative distance.
 */

#ifndef GPS_SENSOR_H
#define GPS_SENSOR_H

#include <Arduino.h>

/**
 * @brief Parsed GPS output data.
 */
struct GPSOutput {
    double   latitude;
    double   longitude;
    float    speedKmh;
    float    distanceKm;    // Cumulative distance since reset
    uint8_t  satellites;
    bool     fixValid;
};

/**
 * @brief Initialize Serial2 for GPS communication.
 */
void gps_init();

/**
 * @brief Feed available serial bytes to the parser and update output.
 * Call this in a loop at ≥1 Hz.
 *
 * @param[out] output  Populated with latest GPS data.
 * @return true if a new valid sentence was processed.
 */
bool gps_update(GPSOutput &output);

/**
 * @brief Reset cumulative distance to zero.
 */
void gps_reset_distance();

/**
 * @brief Check if a valid GPS fix has ever been acquired.
 */
bool gps_has_fix();

#endif // GPS_SENSOR_H
