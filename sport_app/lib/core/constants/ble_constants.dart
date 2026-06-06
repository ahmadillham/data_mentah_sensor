/// BLE Service and Characteristic UUIDs matching the ESP32 firmware.
/// Sport mode enum mirroring the firmware's SportMode.
library;

import 'package:flutter/material.dart';

class BleConstants {
  BleConstants._();

  // ── Custom Sport Service ──
  static const String sportServiceUuid =
      '6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c10';
  static const String sensorDataCharUuid =
      '6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c11';
  static const String gpsDataCharUuid =
      '6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c12';
  static const String commandCharUuid =
      '6e57fc85-a1b3-4f8e-9bd2-0a5e8e6e5c13';

  // ── BLE Device Name ──
  static const String deviceName = 'SportTracker';

  // ── Scan timeout ──
  static const Duration scanTimeout = Duration(seconds: 10);

  // ── Reconnect delay ──
  static const Duration reconnectDelay = Duration(seconds: 3);
}

/// Sport modes matching ESP32 firmware enum.
enum SportMode {
  idle(0x00, 'Idle', Icons.pause_circle_outline, 'No active tracking'),
  running(0x01, 'Running', Icons.directions_run, 'Distance · Pace · Steps · Posture'),
  cycling(0x02, 'Cycling', Icons.directions_bike, 'Distance · Speed · Lean Angle'),
  jumpRope(0x03, 'Jump Rope', Icons.fitness_center, 'Reps · Calories · Posture',
      customIconAsset: 'assets/icons/skipping-rope.png'),
  pushup(0x04, 'Push-up', Icons.accessibility_new, 'Reps · Calories',
      customIconAsset: 'assets/icons/push_up.png'),
  squat(0x05, 'Squat', Icons.sports_martial_arts, 'Reps · Calories',
      customIconAsset: 'assets/icons/squat.png'),
  plank(0x06, 'Plank', Icons.self_improvement, 'Duration · Posture Feedback',
      customIconAsset: 'assets/icons/plank.png'),
  hrMonitor(0x07, 'HR Monitor', Icons.favorite, 'Real-time Heart Rate'),
  postureCorrection(0x08, 'Posture', Icons.balance, 'Live Posture Calibration');

  const SportMode(this.code, this.label, this.icon, this.subtitle,
      {this.customIconAsset});
  final int code;
  final String label;
  final IconData icon;
  final String subtitle;
  final String? customIconAsset;

  /// Whether this mode has a custom PNG icon asset.
  bool get hasCustomIcon => customIconAsset != null;

  /// Whether this mode is a GPS/outdoor activity
  bool get isOutdoor => this == running || this == cycling;

  /// Whether this mode is an indoor calisthenics mode
  bool get isIndoor => !isOutdoor && !isHealthTool && this != idle;

  /// Whether this mode is a health/tool mode
  bool get isHealthTool => this == hrMonitor || this == postureCorrection;
}
