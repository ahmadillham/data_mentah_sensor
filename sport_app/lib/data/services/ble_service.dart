import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/constants/ble_constants.dart';
import '../models/models.dart';

/// BLE Service: handles scanning, connecting, discovering services,
/// subscribing to notifications, and writing commands.
class BleService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _sensorChar;
  BluetoothCharacteristic? _gpsChar;
  BluetoothCharacteristic? _commandChar;

  final _sensorController = StreamController<SensorData>.broadcast();
  final _gpsController = StreamController<GpsData>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  bool _isConnected = false;
  bool _shouldReconnect = true;
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<ScanResult>>? _scanSub;
  final List<StreamSubscription> _notifySubs = [];

  // ── Public Streams ──
  Stream<SensorData> get sensorStream => _sensorController.stream;
  Stream<GpsData> get gpsStream => _gpsController.stream;
  Stream<bool> get connectionStream => _connectionController.stream;
  bool get isConnected => _isConnected;
  BluetoothDevice? get device => _device;

  /// Scan for the SportTracker device.
  Future<BluetoothDevice?> scan() async {
    BluetoothDevice? found;
    final completer = Completer<BluetoothDevice?>();

    await FlutterBluePlus.startScan(
      timeout: BleConstants.scanTimeout,
      androidUsesFineLocation: true,
    );

    _scanSub = FlutterBluePlus.scanResults.listen((results) {
      for (final r in results) {
        if (r.device.platformName == BleConstants.deviceName) {
          found = r.device;
          FlutterBluePlus.stopScan();
          if (!completer.isCompleted) completer.complete(found);
          return;
        }
      }
    });

    // Wait for scan to finish or device found
    Future.delayed(BleConstants.scanTimeout + const Duration(seconds: 1), () {
      if (!completer.isCompleted) completer.complete(null);
    });

    final device = await completer.future;
    _scanSub?.cancel();
    return device;
  }

  /// Connect to a discovered device and set up notifications.
  Future<bool> connect(BluetoothDevice device) async {
    try {
      _device = device;
      _shouldReconnect = true;

      await device.connect(
        autoConnect: false,
        timeout: const Duration(seconds: 10),
      );

      // Listen for disconnection
      _connectionSub?.cancel();
      _connectionSub = device.connectionState.listen((state) {
        final connected = state == BluetoothConnectionState.connected;
        _isConnected = connected;
        _connectionController.add(connected);

        if (!connected && _shouldReconnect) {
          _handleDisconnect();
        }
      });

      // Discover services
      await _discoverAndSubscribe(device);

      _isConnected = true;
      _connectionController.add(true);
      return true;
    } catch (e) {
      print('[BLE] Connect error: $e');
      _isConnected = false;
      _connectionController.add(false);
      return false;
    }
  }

  /// Discover GATT services and subscribe to notification characteristics.
  Future<void> _discoverAndSubscribe(BluetoothDevice device) async {
    // Cancel any existing notification subscriptions to prevent duplicates
    for (final sub in _notifySubs) {
      sub.cancel();
    }
    _notifySubs.clear();

    final services = await device.discoverServices();

    for (final svc in services) {
      final svcUuid = svc.uuid.toString().toLowerCase();

      // ── Sport Service ──
      if (svcUuid == BleConstants.sportServiceUuid) {
        for (final char in svc.characteristics) {
          final charUuid = char.uuid.toString().toLowerCase();

          if (charUuid == BleConstants.sensorDataCharUuid) {
            _sensorChar = char;
            await char.setNotifyValue(true);
            _notifySubs.add(char.onValueReceived.listen((bytes) {
              _sensorController.add(DataParser.parseSensorData(bytes));
            }));
          } else if (charUuid == BleConstants.gpsDataCharUuid) {
            _gpsChar = char;
            await char.setNotifyValue(true);
            _notifySubs.add(char.onValueReceived.listen((bytes) {
              _gpsController.add(DataParser.parseGpsData(bytes));
            }));
          } else if (charUuid == BleConstants.commandCharUuid) {
            _commandChar = char;
          }
        }
      }
    }
  }

  /// Send sport mode, max HR threshold, and optional mute flag to the ESP32.
  Future<void> sendCommand(SportMode mode, int maxHR, {bool muteWarning = false}) async {
    if (_commandChar == null) return;
    final bytes = DataParser.packCommand(mode, maxHR, muteWarning: muteWarning);
    try {
      await _commandChar!.write(bytes, withoutResponse: false);
      print('[BLE] Sent command: mode=${mode.label}, maxHR=$maxHR, mute=$muteWarning');
    } catch (e) {
      print('[BLE] Write error: $e');
    }
  }

  /// Handle unexpected disconnection with auto-reconnect.
  void _handleDisconnect() async {
    print('[BLE] Disconnected. Attempting reconnection...');
    _sensorChar = null;
    _gpsChar = null;
    _commandChar = null;

    if (_device == null || !_shouldReconnect) return;

    // Retry loop
    for (int attempt = 1; attempt <= 5; attempt++) {
      if (!_shouldReconnect) break;
      await Future.delayed(BleConstants.reconnectDelay);

      try {
        print('[BLE] Reconnect attempt $attempt/5...');
        await _device!.connect(
          autoConnect: false,
          timeout: const Duration(seconds: 10),
        );
        await _discoverAndSubscribe(_device!);
        _isConnected = true;
        _connectionController.add(true);
        print('[BLE] Reconnected successfully!');
        return;
      } catch (e) {
        print('[BLE] Reconnect attempt $attempt failed: $e');
      }
    }
    print('[BLE] Gave up reconnecting after 5 attempts.');
  }

  /// Disconnect and clean up.
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _connectionSub?.cancel();
    _scanSub?.cancel();

    // Cancel all notification subscriptions
    for (final sub in _notifySubs) {
      sub.cancel();
    }
    _notifySubs.clear();

    try {
      await _device?.disconnect();
    } catch (_) {}

    _device = null;
    _sensorChar = null;
    _gpsChar = null;
    _commandChar = null;
    _isConnected = false;
    _connectionController.add(false);
  }

  /// Dispose all stream controllers.
  void dispose() {
    disconnect();
    _sensorController.close();
    _gpsController.close();
    _connectionController.close();
  }
}
