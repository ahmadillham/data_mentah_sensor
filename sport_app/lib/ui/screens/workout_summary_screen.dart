import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/ble_constants.dart';
import '../../data/models/models.dart';

/// Post-workout summary screen displayed after finishing a workout.
class WorkoutSummaryScreen extends StatelessWidget {
  final WorkoutSession session;
  final VoidCallback onSave;

  const WorkoutSummaryScreen({
    super.key,
    required this.session,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final polylinePoints =
        session.routePoints.map((p) => LatLng(p[0], p[1])).toList();

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.surface, AppTheme.background],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      // Congrats icon
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primary.withValues(alpha: 0.15),
                        ),
                        child: const Icon(Icons.emoji_events,
                            color: AppTheme.primary, size: 40),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Workout Complete!',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        session.mode.label.toUpperCase(),
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: AppTheme.primary),
                      ),
                      const SizedBox(height: 32),

                      // Duration hero
                      Text(
                        session.formattedDuration,
                        style: Theme.of(context)
                            .textTheme
                            .displayLarge
                            ?.copyWith(fontSize: 56),
                      ),
                      Text(
                        'DURATION',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(color: AppTheme.textMuted),
                      ),
                      const SizedBox(height: 32),

                      // Stats grid
                      _buildStatsGrid(context),
                      const SizedBox(height: 24),

                      // Route map (outdoor only)
                      if (session.mode.isOutdoor &&
                          polylinePoints.length >= 2)
                        _buildRouteMap(polylinePoints),
                    ],
                  ),
                ),
              ),

              // Save button
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28)),
                    ),
                    onPressed: onSave,
                    child: Text(
                      'SAVE & CLOSE',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            color: Colors.white,
                            letterSpacing: 2.0,
                          ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context) {
    final stats = <_StatItem>[];

    if (session.mode == SportMode.running ||
        session.mode == SportMode.cycling) {
      stats.add(_StatItem(
          'Distance', '${session.distance.toStringAsFixed(2)} km',
          icon: Icons.straighten));
    }

    stats.add(_StatItem(
        'Calories', '${session.calories.toStringAsFixed(0)} kcal',
        icon: Icons.local_fire_department));

    stats.add(_StatItem('Avg HR', '${session.avgHeartRate} bpm',
        icon: Icons.favorite));
    stats.add(_StatItem('Max HR', '${session.maxHeartRate} bpm',
        icon: Icons.favorite_border));

    if (session.mode == SportMode.running) {
      stats.add(
          _StatItem('Steps', '${session.steps}', icon: Icons.directions_walk));
    }

    if (session.mode == SportMode.jumpRope ||
        session.mode == SportMode.pushup ||
        session.mode == SportMode.squat) {
      stats.add(
          _StatItem('Reps', '${session.jumps}', icon: Icons.fitness_center));
    }

    if (session.mode == SportMode.running ||
        session.mode == SportMode.cycling) {
      final pace = session.distance > 0
          ? (session.durationSeconds / 60 / session.distance)
              .toStringAsFixed(1)
          : '--';
      stats.add(_StatItem('Avg Pace', '$pace min/km', icon: Icons.speed));
    }

    return Wrap(
      spacing: 16,
      runSpacing: 16,
      children: stats.map((s) => _buildStatCard(context, s)).toList(),
    );
  }

  Widget _buildStatCard(BuildContext context, _StatItem stat) {
    return Container(
      width: 140,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassmorphicDecoration(),
      child: Column(
        children: [
          Icon(stat.icon, color: AppTheme.accent, size: 20),
          const SizedBox(height: 8),
          Text(
            stat.value,
            style: Theme.of(context)
                .textTheme
                .displaySmall
                ?.copyWith(fontSize: 22),
          ),
          const SizedBox(height: 4),
          Text(
            stat.label,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppTheme.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildRouteMap(List<LatLng> points) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        height: 200,
        child: FlutterMap(
          options: MapOptions(
            initialCameraFit: CameraFit.bounds(
              bounds: LatLngBounds.fromPoints(points),
              padding: const EdgeInsets.all(40),
            ),
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.none,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate:
                  'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.sporttracker.app',
              tileBuilder: (context, tileWidget, tile) {
                return ColorFiltered(
                  colorFilter: const ColorFilter.matrix([
                    -1, 0, 0, 0, 255,
                    0, -1, 0, 0, 255,
                    0, 0, -1, 0, 255,
                    0, 0, 0, 1, 0,
                  ]),
                  child: tileWidget,
                );
              },
            ),
            PolylineLayer(
              polylines: [
                Polyline(
                  points: points,
                  color: AppTheme.primary,
                  strokeWidth: 4.0,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatItem {
  final String label;
  final String value;
  final IconData icon;

  _StatItem(this.label, this.value, {required this.icon});
}
