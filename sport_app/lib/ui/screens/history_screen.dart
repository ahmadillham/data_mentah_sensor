import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/workout_provider.dart';
import '../../data/models/models.dart';
import 'history_detail_screen.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final workouts = ref.watch(workoutHistoryProvider);

    // Group workouts by month and year
    final Map<String, List<WorkoutSession>> groupedWorkouts = {};
    for (var session in workouts) {
      final month = DateFormat('MMMM yyyy').format(session.startTime);
      if (!groupedWorkouts.containsKey(month)) {
        groupedWorkouts[month] = [];
      }
      groupedWorkouts[month]!.add(session);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('HISTORY'),
        automaticallyImplyLeading: false,
      ),
      body: workouts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_run, size: 64, color: AppTheme.surfaceLight),
                  const SizedBox(height: 16),
                  Text(
                    'No activities yet.',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: groupedWorkouts.length,
              itemBuilder: (context, index) {
                final monthKey = groupedWorkouts.keys.elementAt(index);
                final monthSessions = groupedWorkouts[monthKey]!;
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      child: Text(
                        monthKey.toUpperCase(),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.primary,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    ...monthSessions.map((session) => Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _WorkoutCard(session: session),
                    )).toList(),
                  ],
                );
              },
            ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  final WorkoutSession session;

  const _WorkoutCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => HistoryDetailScreen(session: session),
          ),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.surfaceLight.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.background,
                  child: session.mode.hasCustomIcon
                      ? Image.asset(
                          session.mode.customIconAsset!,
                          width: 20,
                          height: 20,
                          color: AppTheme.primary,
                        )
                      : Icon(session.mode.icon, color: AppTheme.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${session.mode.label} Activity',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      DateFormat('EEEE, MMM d @ h:mm a').format(session.startTime),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Builder(builder: (context) {
                    if (session.mode == SportMode.running || session.mode == SportMode.cycling) {
                      return _MiniStat(label: 'Distance', value: session.distance <= 0 ? '--' : '${session.distance.toStringAsFixed(2)} km');
                    } else if (session.mode == SportMode.plank) {
                      return _MiniStat(label: 'Posture', value: session.jumps == 0 ? 'Good' : 'Warning');
                    } else {
                      return _MiniStat(label: 'Reps', value: session.jumps <= 0 ? '--' : '${session.jumps}');
                    }
                  }),
                ),
                Expanded(
                  child: _MiniStat(label: 'Time', value: session.formattedDuration == '0s' ? '--' : session.formattedDuration),
                ),
                Expanded(
                  child: _MiniStat(label: 'Avg HR', value: session.avgHeartRate <= 0 ? '--' : '${session.avgHeartRate} bpm'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: value == '--' ? AppTheme.textMuted : AppTheme.textPrimary,
          ),
        ),
      ],
    );
  }
}
