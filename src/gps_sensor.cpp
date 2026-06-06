/**
 * @file gps_sensor.cpp
 * @brief NEO-7M GPS driver using TinyGPS++ and HardwareSerial2.
 *
 * Parses NMEA sentences to extract coordinates, speed, satellite count,
 * and computes cumulative distance via Haversine formula (built into TinyGPS++).
 */

#include "gps_sensor.h"
#include "config.h"
#include <TinyGPSPlus.h>

static TinyGPSPlus gps;
static HardwareSerial &gpsSerial = Serial2;

// Cumulative distance tracking
static double  s_totalDistanceKm = 0.0;
static double  s_lastLat = 0.0;
static double  s_lastLng = 0.0;
static bool    s_hasLastPos = false;
static bool    s_fixEverAcquired = false;

void gps_init() {
    gpsSerial.begin(GPS_BAUD, SERIAL_8N1, PIN_GPS_RX, PIN_GPS_TX);
    Serial.println("[GPS] Serial2 initialized at 9600 baud.");
}

bool gps_update(GPSOutput &output) {
    bool newSentence = false;

    // Feed all available bytes to the parser
    while (gpsSerial.available() > 0) {
        char c = gpsSerial.read();
        if (gps.encode(c)) {
            newSentence = true;
        }
    }

    // Populate output regardless of whether we got a new sentence
    output.satellites = (uint8_t)gps.satellites.value();
    // Note: Only use isValid() — isUpdated() resets after each read and causes flicker
    output.fixValid   = gps.location.isValid();

    if (gps.location.isValid()) {
        output.latitude  = gps.location.lat();
        output.longitude = gps.location.lng();

        if (!s_fixEverAcquired) {
            s_fixEverAcquired = true;
        }

        // Cumulative distance: add segment from last known position
        if (s_hasLastPos) {
            double segmentKm = TinyGPSPlus::distanceBetween(
                s_lastLat, s_lastLng,
                output.latitude, output.longitude
            ) / 1000.0; // distanceBetween returns meters

            // Only accumulate if segment is plausible (<1km in one update, >2m)
            // and GPS speed indicates actual movement (>1 km/h) to filter drift
            bool isMoving = gps.speed.isValid() && gps.speed.kmph() > 1.0;
            if (segmentKm > 0.002 && segmentKm < 1.0 && isMoving) {
                s_totalDistanceKm += segmentKm;
            }
        }

        s_lastLat = output.latitude;
        s_lastLng = output.longitude;
        s_hasLastPos = true;
    } else {
        output.latitude  = 0.0;
        output.longitude = 0.0;
    }

    // Speed from GPS (km/h)
    if (gps.speed.isValid()) {
        output.speedKmh = (float)gps.speed.kmph();
    } else {
        output.speedKmh = 0.0f;
    }

    output.distanceKm = (float)s_totalDistanceKm;

    return newSentence;
}

void gps_reset_distance() {
    s_totalDistanceKm = 0.0;
    s_hasLastPos = false;
}

bool gps_has_fix() {
    return s_fixEverAcquired;
}
