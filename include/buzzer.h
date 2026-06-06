/**
 * @file buzzer.h
 * @brief Non-blocking buzzer pattern driver.
 *
 * Uses a state machine driven by millis() to produce various beep
 * patterns without blocking execution. Designed to run inside a
 * dedicated FreeRTOS task.
 *
 * Active LOW buzzer: LOW = ON, HIGH = OFF.
 */

#ifndef BUZZER_H
#define BUZZER_H

#include <Arduino.h>

/**
 * @brief Available buzzer patterns.
 */
enum BuzzerPattern : uint8_t {
    BUZZ_NONE           = 0,
    BUZZ_POWER_ON       = 1,   // 1 short beep (100ms)
    BUZZ_BLE_CONNECTED  = 2,   // 2 short beeps (100ms ON, 100ms OFF, 100ms ON)
    BUZZ_GPS_LOCK       = 3,   // 1 long beep (500ms)
    BUZZ_HR_WARNING     = 4,   // 3 rapid beeps repeating (80ms ON/OFF × 3, 2s pause)
    BUZZ_POSTURE_WARN   = 5    // 1 short beep every 5 seconds
};

/**
 * @brief Initialize buzzer GPIO pin.
 */
void buzzer_init();

/**
 * @brief Trigger a buzzer pattern. Overrides any currently playing pattern.
 * @param pattern  The pattern to play.
 */
void buzzer_trigger(BuzzerPattern pattern);

/**
 * @brief Stop the currently playing pattern immediately.
 */
void buzzer_stop();

/**
 * @brief Update the buzzer state machine. Call this frequently (every ~10ms).
 * Non-blocking — uses millis() internally for timing.
 */
void buzzer_update();

/**
 * @brief Check if a pattern is currently playing.
 */
bool buzzer_is_playing();

/**
 * @brief Get the currently playing pattern.
 */
BuzzerPattern buzzer_get_pattern();

#endif // BUZZER_H
