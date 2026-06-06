import 'dart:typed_data';
import '../../core/constants/ble_constants.dart';

/// Parsed sensor data from BLE characteristic (18 bytes).
class SensorData {
  final int heartRate;
  final int stepCount;
  final int jumpCount;
  final double pitch;
  final double roll;

  const SensorData({
    this.heartRate = 0,
    this.stepCount = 0,
    this.jumpCount = 0,
    this.pitch = 0.0,
    this.roll = 0.0,
  });

  SensorData copyWith({
    int? heartRate,
    int? stepCount,
    int? jumpCount,
    double? pitch,
    double? roll,
  }) {
    return SensorData(
      heartRate: heartRate ?? this.heartRate,
      stepCount: stepCount ?? this.stepCount,
      jumpCount: jumpCount ?? this.jumpCount,
      pitch: pitch ?? this.pitch,
      roll: roll ?? this.roll,
    );
  }
}

/// Parsed GPS data from BLE characteristic (26 bytes).
class GpsData {
  final double latitude;
  final double longitude;
  final double speed;
  final double distance;
  final int satellites;
  final bool fixValid;

  const GpsData({
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.speed = 0.0,
    this.distance = 0.0,
    this.satellites = 0,
    this.fixValid = false,
  });

  GpsData copyWith({
    double? latitude,
    double? longitude,
    double? speed,
    double? distance,
    int? satellites,
    bool? fixValid,
  }) {
    return GpsData(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      speed: speed ?? this.speed,
      distance: distance ?? this.distance,
      satellites: satellites ?? this.satellites,
      fixValid: fixValid ?? this.fixValid,
    );
  }
}

/// Device connection and hardware status.
class DeviceStatus {
  final bool isConnected;
  final bool isScanning;
  final bool gpsLock;
  final SportMode currentMode;
  final int maxHR;

  const DeviceStatus({
    this.isConnected = false,
    this.isScanning = false,
    this.gpsLock = false,
    this.currentMode = SportMode.idle,
    this.maxHR = 180,
  });

  DeviceStatus copyWith({
    bool? isConnected,
    bool? isScanning,
    bool? gpsLock,
    SportMode? currentMode,
    int? maxHR,
  }) {
    return DeviceStatus(
      isConnected: isConnected ?? this.isConnected,
      isScanning: isScanning ?? this.isScanning,
      gpsLock: gpsLock ?? this.gpsLock,
      currentMode: currentMode ?? this.currentMode,
      maxHR: maxHR ?? this.maxHR,
    );
  }
}

/// Saved workout session for history.
class WorkoutSession {
  final String id;
  final SportMode mode;
  final DateTime startTime;
  final int durationSeconds;
  final double calories;
  final double distance;
  final int steps;
  final int jumps;
  final int avgHeartRate;
  final int maxHeartRate;
  final List<List<double>> routePoints; // [[lat, lng], ...]
  final List<int> hrHistory; // HR per tick

  const WorkoutSession({
    required this.id,
    required this.mode,
    required this.startTime,
    this.durationSeconds = 0,
    this.calories = 0.0,
    this.distance = 0.0,
    this.steps = 0,
    this.jumps = 0,
    this.avgHeartRate = 0,
    this.maxHeartRate = 0,
    this.routePoints = const [],
    this.hrHistory = const [],
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'mode': mode.code,
        'startTime': startTime.toIso8601String(),
        'durationSeconds': durationSeconds,
        'calories': calories,
        'distance': distance,
        'steps': steps,
        'jumps': jumps,
        'avgHeartRate': avgHeartRate,
        'maxHeartRate': maxHeartRate,
        'routePoints': routePoints,
        'hrHistory': hrHistory,
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String,
      mode: SportMode.values.firstWhere(
        (m) => m.code == json['mode'],
        orElse: () => SportMode.idle,
      ),
      startTime: DateTime.parse(json['startTime'] as String),
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      calories: (json['calories'] as num?)?.toDouble() ?? 0.0,
      distance: (json['distance'] as num?)?.toDouble() ?? 0.0,
      steps: json['steps'] as int? ?? 0,
      jumps: json['jumps'] as int? ?? 0,
      avgHeartRate: json['avgHeartRate'] as int? ?? 0,
      maxHeartRate: json['maxHeartRate'] as int? ?? 0,
      routePoints: (json['routePoints'] as List<dynamic>?)
              ?.map((p) => (p as List<dynamic>).map((v) => (v as num).toDouble()).toList())
              .toList() ??
          [],
      hrHistory: (json['hrHistory'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
    );
  }

  String get formattedDuration {
    final h = durationSeconds ~/ 3600;
    final m = (durationSeconds % 3600) ~/ 60;
    final s = durationSeconds % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

/// BLE byte parser utilities.
class DataParser {
  DataParser._();

  /// Parse 18-byte sensor data characteristic.
  static SensorData parseSensorData(List<int> bytes) {
    if (bytes.length < 18) return const SensorData();

    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return SensorData(
      heartRate: data.getUint16(0, Endian.little),
      stepCount: data.getUint32(2, Endian.little),
      jumpCount: data.getUint32(6, Endian.little),
      pitch: data.getFloat32(10, Endian.little),
      roll: data.getFloat32(14, Endian.little),
    );
  }

  /// Parse 26-byte GPS data characteristic.
  static GpsData parseGpsData(List<int> bytes) {
    if (bytes.length < 26) return const GpsData();

    final data = ByteData.sublistView(Uint8List.fromList(bytes));
    return GpsData(
      latitude: data.getFloat64(0, Endian.little),
      longitude: data.getFloat64(8, Endian.little),
      speed: data.getFloat32(16, Endian.little),
      distance: data.getFloat32(20, Endian.little),
      satellites: data.getUint8(24),
      fixValid: data.getUint8(25) == 1,
    );
  }

  /// Pack command: [SportMode:u8][MaxHR:u16 LE][MuteFlag:u8] = 4 bytes.
  static List<int> packCommand(SportMode mode, int maxHR, {bool muteWarning = false}) {
    final data = ByteData(4);
    data.setUint8(0, mode.code);
    data.setUint16(1, maxHR, Endian.little);
    data.setUint8(3, muteWarning ? 1 : 0);
    return data.buffer.asUint8List().toList();
  }
}
