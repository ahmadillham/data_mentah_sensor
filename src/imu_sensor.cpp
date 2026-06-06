/**
 * @file imu_sensor.cpp
 * @brief GY-85 IMU driver — raw I2C register access for ADXL345,
 *        ITG3200, and HMC5883L.
 */

#include "imu_sensor.h"
#include "config.h"
#include <Wire.h>

// ──────────────────────────────────────────────
//  ADXL345 Register Definitions
// ──────────────────────────────────────────────
#define ADXL345_REG_POWER_CTL   0x2D
#define ADXL345_REG_DATA_FORMAT 0x31
#define ADXL345_REG_BW_RATE     0x2C
#define ADXL345_REG_DATAX0      0x32  // 6 bytes: X0,X1,Y0,Y1,Z0,Z1

// ──────────────────────────────────────────────
//  ITG3200 Register Definitions
// ──────────────────────────────────────────────
#define ITG3200_REG_DLPF_FS     0x16
#define ITG3200_REG_SMPLRT_DIV  0x15
#define ITG3200_REG_PWR_MGM     0x3E
#define ITG3200_REG_GYRO_XOUT_H 0x1D  // 6 bytes: XH,XL,YH,YL,ZH,ZL

// ──────────────────────────────────────────────
//  HMC5883L Register Definitions
// ──────────────────────────────────────────────
#define HMC5883L_REG_CONFIG_A   0x00
#define HMC5883L_REG_CONFIG_B   0x01
#define HMC5883L_REG_MODE       0x02
#define HMC5883L_REG_DATAX_H    0x03  // 6 bytes: XH,XL,ZH,ZL,YH,YL (note Z before Y!)

// ── Cached magnetometer availability ──
static bool s_hasHMC = false;

// ──────────────────────────────────────────────
//  Helper: Write a single byte to an I2C register
// ──────────────────────────────────────────────
static void writeRegister(uint8_t addr, uint8_t reg, uint8_t value) {
    Wire.beginTransmission(addr);
    Wire.write(reg);
    Wire.write(value);
    Wire.endTransmission();
}

// ──────────────────────────────────────────────
//  Helper: Read N bytes starting from a register
// ──────────────────────────────────────────────
static bool readRegisters(uint8_t addr, uint8_t reg, uint8_t *buf, uint8_t len) {
    Wire.beginTransmission(addr);
    Wire.write(reg);
    if (Wire.endTransmission(false) != 0) return false;

    Wire.requestFrom(addr, len);
    if (Wire.available() < len) return false;

    for (uint8_t i = 0; i < len; i++) {
        buf[i] = Wire.read();
    }
    return true;
}

// ──────────────────────────────────────────────
//  Helper: Check if a device responds on I2C
// ──────────────────────────────────────────────
static bool devicePresent(uint8_t addr) {
    Wire.beginTransmission(addr);
    return (Wire.endTransmission() == 0);
}

// ──────────────────────────────────────────────
//  Public API
// ──────────────────────────────────────────────

bool imu_init() {
    Wire.begin(PIN_I2C_SDA, PIN_I2C_SCL);
    Wire.setClock(400000); // 400 kHz Fast I2C

    // Check all three devices (Magnetometer is optional as newer clones use QMC5883L at 0x0D)
    if (!devicePresent(ADXL345_ADDR)) {
        Serial.println("[IMU] ADXL345 not found!");
        return false;
    }
    if (!devicePresent(ITG3200_ADDR)) {
        Serial.println("[IMU] ITG3200 not found!");
        return false;
    }
    
    s_hasHMC = devicePresent(HMC5883L_ADDR);
    if (!s_hasHMC) {
        Serial.println("[IMU] HMC5883L not found (Likely QMC5883L at 0x0D). Magnetometer disabled.");
    }

    // ── ADXL345 Init ──
    // Set measurement mode
    writeRegister(ADXL345_ADDR, ADXL345_REG_POWER_CTL, 0x08);
    // Full resolution, ±16g range
    writeRegister(ADXL345_ADDR, ADXL345_REG_DATA_FORMAT, 0x0B);
    // 100 Hz output data rate
    writeRegister(ADXL345_ADDR, ADXL345_REG_BW_RATE, 0x0A);

    // ── ITG3200 Init ──
    // Reset power management, use internal oscillator
    writeRegister(ITG3200_ADDR, ITG3200_REG_PWR_MGM, 0x00);
    delay(10);
    // Full scale range ±2000°/s, DLPF bandwidth 42 Hz
    writeRegister(ITG3200_ADDR, ITG3200_REG_DLPF_FS, 0x1B);
    // Sample rate divider = 9 → 100 Hz (1000 / (1+9))
    writeRegister(ITG3200_ADDR, ITG3200_REG_SMPLRT_DIV, 0x09);

    // ── HMC5883L Init (Optional) ──
    if (s_hasHMC) {
        // 8 samples averaged, 75 Hz output rate, normal measurement
        writeRegister(HMC5883L_ADDR, HMC5883L_REG_CONFIG_A, 0x78);
        // Gain = ±1.3 Ga (default)
        writeRegister(HMC5883L_ADDR, HMC5883L_REG_CONFIG_B, 0x20);
        // Continuous measurement mode
        writeRegister(HMC5883L_ADDR, HMC5883L_REG_MODE, 0x00);
    }

    Serial.println("[IMU] All GY-85 sensors initialized OK.");
    return true;
}

bool imu_read(IMURawData &data) {
    uint8_t buf[6];

    // ── Read ADXL345 (little-endian: LSB first) ──
    if (!readRegisters(ADXL345_ADDR, ADXL345_REG_DATAX0, buf, 6)) {
        return false;
    }
    data.ax = (int16_t)(buf[1] << 8 | buf[0]);
    data.ay = (int16_t)(buf[3] << 8 | buf[2]);
    data.az = (int16_t)(buf[5] << 8 | buf[4]);

    // ── Read ITG3200 (big-endian: MSB first) ──
    if (!readRegisters(ITG3200_ADDR, ITG3200_REG_GYRO_XOUT_H, buf, 6)) {
        return false;
    }
    data.gx = (int16_t)(buf[0] << 8 | buf[1]);
    data.gy = (int16_t)(buf[2] << 8 | buf[3]);
    data.gz = (int16_t)(buf[4] << 8 | buf[5]);

    // ── Read HMC5883L (Optional — uses cached presence from init) ──
    if (s_hasHMC) {
        if (readRegisters(HMC5883L_ADDR, HMC5883L_REG_DATAX_H, buf, 6)) {
            data.mx = (int16_t)(buf[0] << 8 | buf[1]);
            data.mz = (int16_t)(buf[2] << 8 | buf[3]);  // Z comes before Y
            data.my = (int16_t)(buf[4] << 8 | buf[5]);
        }
    } else {
        data.mx = 0; data.my = 0; data.mz = 0;
    }

    return true;
}

float imu_accel_to_g(int16_t raw) {
    // ADXL345 full resolution mode: 3.9 mg/LSB = 0.0039 g/LSB
    return raw * 0.0039f;
}

float imu_gyro_to_dps(int16_t raw) {
    // ITG3200: sensitivity = 14.375 LSB/(°/s)
    return raw / 14.375f;
}
