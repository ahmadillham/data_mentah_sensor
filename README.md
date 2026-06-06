# ESP32 Headless Sports Tracker

A headless (no screen, no physical buttons) wearable sports tracker based on the ESP32. All data is transmitted via Bluetooth Low Energy (BLE) to a companion Flutter app for real-time monitoring and history tracking.

## Hardware Components
*   **Microcontroller:** ESP32 Development Board
*   **Heart Rate Sensor:** AD8232 (ECG module)
*   **IMU:** GY-85 / HW579 (9-DOF Accelerometer, Gyroscope, Magnetometer)
*   **GPS:** NEO-7M
*   **Feedback:** Active Buzzer (Active Low)
*   **Power:** 18650 Battery with a Power Bank Module

## Wiring Guide

Here is the connection table between the ESP32 and the various hardware components.

| Component | Component Pin | ESP32 Pin | Notes / Description |
| :--- | :--- | :--- | :--- |
| **AD8232 (Heart Rate)** | OUTPUT | **GPIO 34** | Analog signal input (ADC1_CH6) |
| | LO+ | **GPIO 25** | Leads-off detection + (Digital Input) |
| | LO- | **GPIO 26** | Leads-off detection - (Digital Input) |
| | 3.3V | 3.3V | Power supply |
| | GND | GND | Ground |
| **GY-85 (IMU)** | SDA | **GPIO 21** | I2C Data |
| | SCL | **GPIO 22** | I2C Clock |
| | VCC | 3.3V / 5V | Power supply (check module specs) |
| | GND | GND | Ground |
| **NEO-7M (GPS)** | TX | **GPIO 16** | Connects to ESP32 HardwareSerial2 RX |
| | RX | **GPIO 17** | Connects to ESP32 HardwareSerial2 TX |
| | VCC | 3.3V / 5V | Power supply (check module specs) |
| | GND | GND | Ground |
| **Active Buzzer** | I/O (Signal) | **GPIO 27** | Active LOW logic (LOW = ON, HIGH = OFF) |
| | VCC | 3.3V / 5V | Power supply |
| | GND | GND | Ground |
## Software Architecture

### Firmware (PlatformIO)
*   Uses FreeRTOS with dual-core processing to ensure BLE connection stability while processing IMU and GPS algorithms.
*   **Core 0:** Handles BLE GATT server (NimBLE) and characteristic notifications.
*   **Core 1:** Handles sensor polling (IMU @ 50Hz, HR @ 200Hz, GPS @ 1Hz), algorithm calculations (peak detection, complementary filter), and non-blocking buzzer patterns.

### Companion App (Flutter)
*   Communicates with the ESP32 over BLE.
*   Uses Riverpod for state management.
*   Calculates calories based on the Keytel et al. HR formula.
*   Maps live GPS coordinates using `flutter_map` (OpenStreetMap).
*   Saves workout sessions locally using Hive.
# sports_tracker
