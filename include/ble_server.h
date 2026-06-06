/**
 * @file ble_server.h
 * @brief BLE GATT Server interface for the Sports Tracker.
 *
 * Manages the NimBLE stack, GATT services (Custom Sport + Battery),
 * characteristics, notifications, and connection callbacks.
 */

#ifndef BLE_SERVER_H
#define BLE_SERVER_H

#include <Arduino.h>

/**
 * @brief Initialize the NimBLE BLE stack, create services and characteristics.
 * Must be called once during setup().
 */
void ble_init();

/**
 * @brief Start BLE advertising.
 */
void ble_start_advertising();

/**
 * @brief Pack and notify the Sensor Data characteristic.
 * Reads from g_sensorData under mutex protection.
 */
void ble_notify_sensors();

/**
 * @brief Pack and notify the GPS Data characteristic.
 * Reads from g_gpsData under mutex protection.
 */
void ble_notify_gps();

/**
 * @brief Pack and notify the Raw Sensor Data characteristic.
 * Reads from g_rawSensorData under mutex protection.
 */
void ble_notify_raw();

/**
 * @brief Check if a BLE client is currently connected.
 */
bool ble_is_connected();

#endif // BLE_SERVER_H
