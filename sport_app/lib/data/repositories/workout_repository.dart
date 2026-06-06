import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/models.dart';

/// Hive-based local storage for workout history.
class WorkoutRepository {
  static const String _boxName = 'workouts';
  late Box<String> _box;

  Future<void> init() async {
    _box = await Hive.openBox<String>(_boxName);
  }

  /// Save a completed workout session.
  Future<void> saveWorkout(WorkoutSession session) async {
    final json = jsonEncode(session.toJson());
    await _box.put(session.id, json);
  }

  /// Get all saved workouts, sorted by date (newest first).
  List<WorkoutSession> getAllWorkouts() {
    final sessions = <WorkoutSession>[];
    for (final json in _box.values) {
      try {
        final map = jsonDecode(json) as Map<String, dynamic>;
        sessions.add(WorkoutSession.fromJson(map));
      } catch (e) {
        print('[WorkoutRepo] Failed to parse workout: $e');
      }
    }
    sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
    return sessions;
  }

  /// Delete a workout by ID.
  Future<void> deleteWorkout(String id) async {
    await _box.delete(id);
  }

  /// Clear all workouts.
  Future<void> clearAll() async {
    await _box.clear();
  }
}
