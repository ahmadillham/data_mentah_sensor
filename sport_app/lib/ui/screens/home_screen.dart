import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/theme/app_theme.dart';
import '../../providers/ble_provider.dart';
import '../widgets/pulse_animation.dart';
import 'main_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isScanning = false;
  String _status = 'Ready to Connect';

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      Permission.location,
    ].request();
  }

  Future<void> _scanAndConnect() async {
    await _requestPermissions();

    setState(() {
      _isScanning = true;
      _status = 'Searching for SportTracker...';
    });

    final bleService = ref.read(bleServiceProvider);
    
    // Disconnect if already connected
    if (bleService.isConnected) {
      await bleService.disconnect();
    }

    final device = await bleService.scan();

    if (device == null) {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _status = 'Device not found. Make sure it is powered on.';
        });
      }
      return;
    }

    if (mounted) {
      setState(() {
        _status = 'Found device! Connecting...';
      });
    }

    final success = await bleService.connect(device);

    if (mounted) {
      setState(() {
        _isScanning = false;
        if (success) {
          _status = 'Connected!';
          _navigateToDashboard();
        } else {
          _status = 'Connection failed. Please try again.';
        }
      });
    }
  }

  void _navigateToDashboard() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MainScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.background,
              AppTheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 2),

                  // Logo with pulse animation
                  PulseAnimation(
                    isAnimating: _isScanning,
                    size: 200,
                    child: Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primary,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_run,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Text(
                    'SportTracker',
                    style: Theme.of(context).textTheme.displayMedium?.copyWith(
                          fontSize: 40,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Your smart fitness companion',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                  const SizedBox(height: 24),

                  // Feature chips
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: const [
                      _FeatureChip(icon: Icons.fitness_center, label: '6 Modes'),
                      _FeatureChip(icon: Icons.gps_fixed, label: 'Real-time GPS'),
                      _FeatureChip(icon: Icons.favorite, label: 'Heart Rate'),
                    ],
                  ),

                  const Spacer(flex: 2),

                  // Status text
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Text(
                      _status,
                      key: ValueKey(_status),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _status.contains('failed') || _status.contains('not found')
                                ? AppTheme.danger
                                : AppTheme.textSecondary,
                          ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Connect button
                  SizedBox(
                    width: double.infinity,
                    height: 64,
                    child: _isScanning
                        ? Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                  color: AppTheme.primary.withValues(alpha: 0.3)),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: AppTheme.primary,
                                  strokeWidth: 3,
                                ),
                              ),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: _scanAndConnect,
                            icon: const Icon(Icons.bluetooth, size: 22),
                            label: Text(
                              'CONNECT DEVICE',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    color: Colors.white,
                                    letterSpacing: 2.0,
                                  ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(32)),
                              elevation: 0,
                            ),
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Make sure your device is powered on',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textMuted,
                        ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeatureChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceLight.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppTheme.accent),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}
