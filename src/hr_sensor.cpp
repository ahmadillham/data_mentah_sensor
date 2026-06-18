/**
 * @file hr_sensor.cpp
 * @brief AD8232 ECG heart rate sensor driver.
 *
 * Performs derivative and adaptive peak detection on the AD8232 output to compute BPM.
 * This method is robust against baseline wander and motion artifacts.
 *
 * Algorithm:
 * 1. Read ADC value at ~200 Hz.
 * 2. Calculate derivative (dx) and square it (sq_dx) to amplify peaks.
 * 3. Use an adaptive threshold that decays over time.
 * 4. When sq_dx crosses threshold → mark peak and adjust threshold upwards.
 * 5. Measure time between consecutive peaks = IBI.
 * 6. BPM = 60000 / IBI (with moving average smoothing).
 */

#include "hr_sensor.h"
#include "config.h"

// HR algorithm constants (local to this module)
#define HR_DERIV_MIN_THRESH         1500.0f // Minimum squared derivative threshold
#define HR_MIN_IBI_MS               300     // Min inter-beat interval (200 BPM max)
#define HR_MAX_IBI_MS               1500    // Max inter-beat interval (40 BPM min)
#define HR_TIMEOUT_MS               3000    // No peak for 3s = signal lost

// ── State variables ──
static volatile uint16_t s_bpm = 0;
static int s_lastAdc = 0;
static float s_threshold = 1500.0f; // Initialize with HR_DERIV_MIN_THRESH
static bool s_peakActive = false;
static unsigned long s_lastPeakMs = 0;

// Moving average for BPM smoothing (last 5 readings)
#define BPM_AVG_SIZE  5
static uint16_t s_bpmBuffer[BPM_AVG_SIZE] = {0};
static uint8_t  s_bpmIndex = 0;
static uint8_t  s_bpmCount = 0;  // How many valid readings we have

void hr_init() {
    pinMode(PIN_HR_LO_PLUS, INPUT);
    pinMode(PIN_HR_LO_MINUS, INPUT);
    // GPIO 34 is input-only, no need for pinMode on ADC pins
    analogReadResolution(12);       // 12-bit ADC (0–4095)
    analogSetAttenuation(ADC_11db); // Full 0–3.3V range

    // Initialize state
    s_lastAdc = analogRead(PIN_HR_OUTPUT);
    s_threshold = HR_DERIV_MIN_THRESH;

    Serial.println("[HR] AD8232 initialized.");
}

bool hr_leads_on() {
    // AD8232: LO+/LO- are HIGH when leads are OFF (disconnected)
    return (digitalRead(PIN_HR_LO_PLUS) == LOW &&
            digitalRead(PIN_HR_LO_MINUS) == LOW);
}

uint16_t hr_update() {
    // Check leads-off first
    if (!hr_leads_on()) {
        s_bpm = 0;
        s_peakActive = false;
        s_lastPeakMs = 0;
        s_threshold = HR_DERIV_MIN_THRESH;
        // Reset moving average buffer so reconnection starts fresh
        s_bpmCount = 0;
        s_bpmIndex = 0;
        s_lastAdc = analogRead(PIN_HR_OUTPUT);
        return 0;
    }

    int adcValue = analogRead(PIN_HR_OUTPUT);
    unsigned long now = millis();

    // 1. Derivative & Squaring
    int dx = adcValue - s_lastAdc;
    s_lastAdc = adcValue;
    float sq_dx = (float)(dx * dx);

    // Timeout: if no peak detected within 3 seconds, signal is lost
    if (s_lastPeakMs > 0 && (now - s_lastPeakMs) > HR_TIMEOUT_MS) {
        s_bpm = 0;
        s_lastPeakMs = 0;
        s_bpmCount = 0;
        s_bpmIndex = 0;
        s_threshold = HR_DERIV_MIN_THRESH;
    }

    // 2. Adaptive Threshold Decay
    if (s_threshold > HR_DERIV_MIN_THRESH) {
        s_threshold -= (s_threshold - HR_DERIV_MIN_THRESH) * 0.01f; // Decay factor
    }

    // 3. Peak Detection Logic
    if (sq_dx > s_threshold && !s_peakActive) {
        s_peakActive = true;

        // Calculate IBI from the last peak
        if (s_lastPeakMs > 0) {
            unsigned long ibi = now - s_lastPeakMs;

            // Validate IBI is physiologically plausible
            if (ibi >= HR_MIN_IBI_MS && ibi <= HR_MAX_IBI_MS) {
                uint16_t instantBpm = (uint16_t)(60000UL / ibi);

                // Add to moving average buffer
                s_bpmBuffer[s_bpmIndex] = instantBpm;
                s_bpmIndex = (s_bpmIndex + 1) % BPM_AVG_SIZE;
                if (s_bpmCount < BPM_AVG_SIZE) s_bpmCount++;

                // Compute average
                uint32_t sum = 0;
                for (uint8_t i = 0; i < s_bpmCount; i++) {
                    sum += s_bpmBuffer[i];
                }
                s_bpm = (uint16_t)(sum / s_bpmCount);

                // Adaptive threshold adjustment
                // Next peak must be at least 50% of this valid peak's energy
                s_threshold = sq_dx * 0.50f;
                if (s_threshold < HR_DERIV_MIN_THRESH) {
                    s_threshold = HR_DERIV_MIN_THRESH;
                }
            }
        }
        s_lastPeakMs = now;
    }
    else if (sq_dx < (s_threshold * 0.40f)) {
        // Hysteresis: energy must drop below 40% of threshold to reset
        s_peakActive = false;
    }

    return s_bpm;
}

uint16_t hr_get_bpm() {
    return s_bpm;
}
