/// Calorie calculator using heart rate based formula.
/// Reference: Keytel et al. (2005) prediction equation.
library;

import '../../data/models/user_profile.dart';

class CalorieCalculator {
  CalorieCalculator._();

  /// Calculate calories burned per minute based on heart rate.
  ///
  /// Male formula:
  ///   cal/min = (-55.0969 + 0.6309×HR + 0.1988×weight + 0.2017×age) / 4.184
  ///
  /// Female formula:
  ///   cal/min = (-20.4022 + 0.4472×HR - 0.1263×weight + 0.074×age) / 4.184
  static double caloriesPerMinute(int heartRate, {UserProfile? profile}) {
    if (heartRate <= 0) return 0.0;

    final p = profile ?? const UserProfile();

    double calPerMin;
    if (p.isMale) {
      calPerMin = (-55.0969 +
              0.6309 * heartRate +
              0.1988 * p.weightKg +
              0.2017 * p.age) /
          4.184;
    } else {
      calPerMin = (-20.4022 +
              0.4472 * heartRate -
              0.1263 * p.weightKg +
              0.074 * p.age) /
          4.184;
    }

    return calPerMin > 0 ? calPerMin : 0.0;
  }

  /// Calculate total calories for a given duration.
  /// [heartRate] - average BPM
  /// [durationSeconds] - total workout duration in seconds
  static double totalCalories(int heartRate, int durationSeconds,
      {UserProfile? profile}) {
    final minutes = durationSeconds / 60.0;
    return caloriesPerMinute(heartRate, profile: profile) * minutes;
  }
}
