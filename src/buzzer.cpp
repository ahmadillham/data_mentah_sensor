/**
 * @file buzzer.cpp
 * @brief Non-blocking buzzer pattern state machine.
 * Active LOW: LOW = buzzer ON, HIGH = buzzer OFF.
 */

#include "buzzer.h"
#include "config.h"

#define BUZZER_ON()   digitalWrite(PIN_BUZZER, LOW)
#define BUZZER_OFF()  digitalWrite(PIN_BUZZER, HIGH)

// Pattern definitions: sequence of {duration_ms, is_on} pairs
// Terminated by {0, false}
struct BeepStep {
    uint16_t durationMs;
    bool     on;
};

// Power ON: 1 short beep
static const BeepStep PAT_POWER_ON[] = {
    {100, true}, {0, false}
};

// BLE Connected: 2 short beeps
static const BeepStep PAT_BLE_CONN[] = {
    {100, true}, {100, false}, {100, true}, {0, false}
};

// GPS Lock: 1 long beep
static const BeepStep PAT_GPS_LOCK[] = {
    {500, true}, {0, false}
};

// HR Warning: 3 rapid beeps, then 2s pause, repeating
static const BeepStep PAT_HR_WARN[] = {
    {80, true}, {80, false},
    {80, true}, {80, false},
    {80, true}, {2000, false},
    {0, false}  // Will loop back to start
};

// Posture Warning: 1 short beep, 5s pause, repeating
static const BeepStep PAT_POSTURE_WARN[] = {
    {150, true}, {4850, false},
    {0, false}
};

// State
static BuzzerPattern  s_currentPattern = BUZZ_NONE;
static const BeepStep *s_steps = nullptr;
static uint8_t        s_stepIndex = 0;
static unsigned long  s_stepStartMs = 0;
static bool           s_repeating = false;

// Spinlock for thread safety between taskSensor and taskBuzzer
static portMUX_TYPE s_buzzerMux = portMUX_INITIALIZER_UNLOCKED;

static const BeepStep* getPatternSteps(BuzzerPattern pat, bool &repeat) {
    repeat = false;
    switch (pat) {
        case BUZZ_POWER_ON:      return PAT_POWER_ON;
        case BUZZ_BLE_CONNECTED: return PAT_BLE_CONN;
        case BUZZ_GPS_LOCK:      return PAT_GPS_LOCK;
        case BUZZ_HR_WARNING:    repeat = true; return PAT_HR_WARN;
        case BUZZ_POSTURE_WARN:  repeat = true; return PAT_POSTURE_WARN;
        default:                 return nullptr;
    }
}

void buzzer_init() {
    pinMode(PIN_BUZZER, OUTPUT);
    BUZZER_OFF();
    Serial.println("[Buzzer] Initialized (active LOW).");
}

void buzzer_trigger(BuzzerPattern pattern) {
    if (pattern == BUZZ_NONE) {
        buzzer_stop();
        return;
    }

    portENTER_CRITICAL(&s_buzzerMux);
    s_currentPattern = pattern;
    s_steps = getPatternSteps(pattern, s_repeating);
    s_stepIndex = 0;
    s_stepStartMs = millis();

    if (s_steps && s_steps[0].durationMs > 0) {
        if (s_steps[0].on) BUZZER_ON();
        else BUZZER_OFF();
    }
    portEXIT_CRITICAL(&s_buzzerMux);
}

void buzzer_stop() {
    portENTER_CRITICAL(&s_buzzerMux);
    BUZZER_OFF();
    s_currentPattern = BUZZ_NONE;
    s_steps = nullptr;
    s_stepIndex = 0;
    portEXIT_CRITICAL(&s_buzzerMux);
}

void buzzer_update() {
    portENTER_CRITICAL(&s_buzzerMux);
    if (s_steps == nullptr || s_currentPattern == BUZZ_NONE) {
        portEXIT_CRITICAL(&s_buzzerMux);
        return;
    }

    const BeepStep &step = s_steps[s_stepIndex];

    // Check if current step is the terminator
    if (step.durationMs == 0) {
        if (s_repeating) {
            // Loop back to beginning
            s_stepIndex = 0;
            s_stepStartMs = millis();
            if (s_steps[0].on) BUZZER_ON();
            else BUZZER_OFF();
        } else {
            BUZZER_OFF();
            s_currentPattern = BUZZ_NONE;
            s_steps = nullptr;
            s_stepIndex = 0;
        }
        portEXIT_CRITICAL(&s_buzzerMux);
        return;
    }

    // Check if current step's duration has elapsed
    if (millis() - s_stepStartMs >= step.durationMs) {
        s_stepIndex++;
        s_stepStartMs = millis();

        // Check next step
        if (s_steps[s_stepIndex].durationMs == 0) {
            if (s_repeating) {
                s_stepIndex = 0;
                if (s_steps[0].on) BUZZER_ON();
                else BUZZER_OFF();
            } else {
                BUZZER_OFF();
                s_currentPattern = BUZZ_NONE;
                s_steps = nullptr;
                s_stepIndex = 0;
            }
        } else {
            if (s_steps[s_stepIndex].on) BUZZER_ON();
            else BUZZER_OFF();
        }
    }
    portEXIT_CRITICAL(&s_buzzerMux);
}

bool buzzer_is_playing() {
    portENTER_CRITICAL(&s_buzzerMux);
    bool playing = (s_currentPattern != BUZZ_NONE && s_steps != nullptr);
    portEXIT_CRITICAL(&s_buzzerMux);
    return playing;
}

BuzzerPattern buzzer_get_pattern() {
    portENTER_CRITICAL(&s_buzzerMux);
    BuzzerPattern pat = s_currentPattern;
    portEXIT_CRITICAL(&s_buzzerMux);
    return pat;
}
