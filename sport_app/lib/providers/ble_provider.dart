import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/models.dart';
import '../data/services/ble_service.dart';

// ── BLE Service Singleton ──
final bleServiceProvider = Provider<BleService>((ref) {
  final service = BleService();
  ref.onDispose(() => service.dispose());
  return service;
});

// ── Connection State ──
final connectionStateProvider = StreamProvider<bool>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.connectionStream;
});

// ── Sensor Data Stream ──
final sensorDataProvider = StreamProvider<SensorData>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.sensorStream;
});

// ── GPS Data Stream ──
final gpsDataProvider = StreamProvider<GpsData>((ref) {
  final bleService = ref.watch(bleServiceProvider);
  return bleService.gpsStream;
});


