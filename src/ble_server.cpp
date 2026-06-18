/**
 * @file ble_server.cpp
 * @brief BLE GATT Server using NimBLE for the Raw Sensor Monitor.
 *
 * Service:
 *   Custom Sport Service — Raw Data (TX), GPS Data (TX)
 *
 * Data is packed as raw bytes for efficiency over BLE.
 */

#include "ble_server.h"
#include "config.h"
#include "buzzer.h"

#include <NimBLEDevice.h>

// ── BLE Objects ──
static NimBLEServer         *pServer = nullptr;
static NimBLECharacteristic *pSensorChar = nullptr;
static NimBLECharacteristic *pGPSChar = nullptr;
static NimBLECharacteristic *pRawChar = nullptr;

// ──────────────────────────────────────────────
//  Server Callbacks (Connect / Disconnect)
// ──────────────────────────────────────────────
class ServerCB : public NimBLEServerCallbacks {
    void onConnect(NimBLEServer *s) override {
        g_bleConnected = true;
        buzzer_trigger(BUZZ_BLE_CONNECTED);
        Serial.println("[BLE] Client connected.");
    }

    void onDisconnect(NimBLEServer *s) override {
        g_bleConnected = false;
        Serial.println("[BLE] Client disconnected.");
        NimBLEDevice::startAdvertising();
    }
};

// ──────────────────────────────────────────────
//  Public API
// ──────────────────────────────────────────────

void ble_init() {
    NimBLEDevice::init(BLE_DEVICE_NAME);
    NimBLEDevice::setPower(ESP_PWR_LVL_P3);
    NimBLEDevice::setMTU(185);

    static ServerCB serverCB;

    pServer = NimBLEDevice::createServer();
    pServer->setCallbacks(&serverCB);

    // Custom Sport Service
    NimBLEService *pSportSvc = pServer->createService(SERVICE_SPORT_UUID);

    // Processed Sensor Data (TX): Read + Notify
    pSensorChar = pSportSvc->createCharacteristic(
        CHAR_SENSOR_DATA_UUID,
        NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
    );

    // GPS Data (TX): Read + Notify
    pGPSChar = pSportSvc->createCharacteristic(
        CHAR_GPS_DATA_UUID,
        NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
    );

    // Raw Data (TX): Read + Notify
    pRawChar = pSportSvc->createCharacteristic(
        CHAR_RAW_DATA_UUID,
        NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY
    );

    pSportSvc->start();

    // ── Advertising ──
    NimBLEAdvertising *pAdv = NimBLEDevice::getAdvertising();
    pAdv->addServiceUUID(SERVICE_SPORT_UUID);
    pAdv->setScanResponse(true);

    ble_start_advertising();
    Serial.println("[BLE] GATT Server started, advertising...");
}

void ble_start_advertising() {
    NimBLEDevice::startAdvertising();
}

void ble_notify_gps() {
    if (!g_bleConnected || pGPSChar == nullptr) return;

    GPSData local;
    if (xSemaphoreTake(xDataMutex, pdMS_TO_TICKS(5)) == pdTRUE) {
        local = g_gpsData;
        xSemaphoreGive(xDataMutex);
    } else {
        return;
    }

    // Pack: [Lat:f64][Lng:f64][Speed:f32][Dist:f32][Sats:u8][Fix:u8] = 26 bytes
    uint8_t buf[26];
    memcpy(&buf[0],  &local.latitude,   8);
    memcpy(&buf[8],  &local.longitude,  8);
    memcpy(&buf[16], &local.speed,      4);
    memcpy(&buf[20], &local.distance,   4);
    buf[24] = local.satellites;
    buf[25] = local.fixValid;

    pGPSChar->setValue(buf, sizeof(buf));
    pGPSChar->notify();
}

void ble_notify_sensors() {
    if (!g_bleConnected || pSensorChar == nullptr) return;

    SensorData local;
    if (xSemaphoreTake(xDataMutex, pdMS_TO_TICKS(5)) == pdTRUE) {
        local = g_sensorData;
        xSemaphoreGive(xDataMutex);
    } else {
        return;
    }

    // Pack: [HR:u16][Step:u32][Pushup:u32][Pitch:f32][Roll:f32] = 18 bytes
    uint8_t buf[18];
    memcpy(&buf[0],  &local.heartRate,   2);
    memcpy(&buf[2],  &local.stepCount,   4);
    memcpy(&buf[6],  &local.pushupCount, 4);
    memcpy(&buf[10], &local.pitch,       4);
    memcpy(&buf[14], &local.roll,        4);

    pSensorChar->setValue(buf, sizeof(buf));
    pSensorChar->notify();
}

void ble_notify_raw() {
    if (!g_bleConnected || pRawChar == nullptr) return;

    RawSensorData local;
    if (xSemaphoreTake(xDataMutex, pdMS_TO_TICKS(5)) == pdTRUE) {
        local = g_rawSensorData;
        xSemaphoreGive(xDataMutex);
    } else {
        return;
    }

    // Pack: [ax:16][ay:16][az:16][gx:16][gy:16][gz:16][mx:16][my:16][mz:16][hrRaw:16] = 20 bytes
    uint8_t buf[20];
    memcpy(&buf[0],  &local.ax, 2);
    memcpy(&buf[2],  &local.ay, 2);
    memcpy(&buf[4],  &local.az, 2);
    memcpy(&buf[6],  &local.gx, 2);
    memcpy(&buf[8],  &local.gy, 2);
    memcpy(&buf[10], &local.gz, 2);
    memcpy(&buf[12], &local.mx, 2);
    memcpy(&buf[14], &local.my, 2);
    memcpy(&buf[16], &local.mz, 2);
    memcpy(&buf[18], &local.hrRaw, 2);

    pRawChar->setValue(buf, sizeof(buf));
    pRawChar->notify();
}

bool ble_is_connected() {
    return g_bleConnected;
}
