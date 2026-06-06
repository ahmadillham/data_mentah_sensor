import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/utils/calorie_calculator.dart';
import '../core/constants/ble_constants.dart';
import '../data/models/models.dart';
import '../data/models/user_profile.dart';
import '../data/repositories/workout_repository.dart';
import 'ble_provider.dart';

// ── Repository & Profile Providers ──

final workoutRepositoryProvider = Provider<WorkoutRepository>((ref) {
  throw UnimplementedError('Initialize in main.dart');
});

final userProfileRepoProvider = Provider<UserProfileRepository>((ref) {
  throw UnimplementedError('Initialize in main.dart');
});

final userProfileProvider =
    StateNotifierProvider<UserProfileNotifier, UserProfile>((ref) {
  final repo = ref.watch(userProfileRepoProvider);
  return UserProfileNotifier(repo);
});

class UserProfileNotifier extends StateNotifier<UserProfile> {
  final UserProfileRepository _repo;

  UserProfileNotifier(this._repo) : super(_repo.getProfile());

  Future<void> update(UserProfile profile) async {
    await _repo.saveProfile(profile);
    state = profile;
  }
}

// ── Workout History ──

final workoutHistoryProvider =
    StateNotifierProvider<WorkoutHistoryNotifier, List<WorkoutSession>>((ref) {
  final repo = ref.watch(workoutRepositoryProvider);
  return WorkoutHistoryNotifier(repo);
});

class WorkoutHistoryNotifier extends StateNotifier<List<WorkoutSession>> {
  final WorkoutRepository _repo;

  WorkoutHistoryNotifier(this._repo) : super([]) {
    loadWorkouts();
  }

  void loadWorkouts() {
    state = _repo.getAllWorkouts();
  }

  Future<void> deleteWorkout(String id) async {
    await _repo.deleteWorkout(id);
    loadWorkouts();
  }
}

// ── Active Workout State ──

enum WorkoutStatus { idle, running, paused, finished }

class ActiveWorkoutState {
  final WorkoutStatus status;
  final SportMode mode;
  final int durationSeconds;
  final double caloriesBurned;
  final List<List<double>> routePoints;
  final int hrSum;
  final int hrCount;
  final int hrMax;
  final List<int> hrHistory;
  // Snapshot values for summary screen
  final int lastSteps;
  final int lastJumps;
  final double lastDistance;

  const ActiveWorkoutState({
    this.status = WorkoutStatus.idle,
    this.mode = SportMode.idle,
    this.durationSeconds = 0,
    this.caloriesBurned = 0.0,
    this.routePoints = const [],
    this.hrSum = 0,
    this.hrCount = 0,
    this.hrMax = 0,
    this.hrHistory = const [],
    this.lastSteps = 0,
    this.lastJumps = 0,
    this.lastDistance = 0.0,
  });

  bool get isActive => status == WorkoutStatus.running || status == WorkoutStatus.paused;
  bool get isPaused => status == WorkoutStatus.paused;
  bool get isFinished => status == WorkoutStatus.finished;
  int get avgHeartRate => hrCount > 0 ? (hrSum / hrCount).round() : 0;
  int get maxHeartRate => hrMax;

  ActiveWorkoutState copyWith({
    WorkoutStatus? status,
    SportMode? mode,
    int? durationSeconds,
    double? caloriesBurned,
    List<List<double>>? routePoints,
    int? hrSum,
    int? hrCount,
    int? hrMax,
    List<int>? hrHistory,
    int? lastSteps,
    int? lastJumps,
    double? lastDistance,
  }) {
    return ActiveWorkoutState(
      status: status ?? this.status,
      mode: mode ?? this.mode,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      caloriesBurned: caloriesBurned ?? this.caloriesBurned,
      routePoints: routePoints ?? this.routePoints,
      hrSum: hrSum ?? this.hrSum,
      hrCount: hrCount ?? this.hrCount,
      hrMax: hrMax ?? this.hrMax,
      hrHistory: hrHistory ?? this.hrHistory,
      lastSteps: lastSteps ?? this.lastSteps,
      lastJumps: lastJumps ?? this.lastJumps,
      lastDistance: lastDistance ?? this.lastDistance,
    );
  }
}

// ── Active Workout Notifier ──

final activeWorkoutProvider =
    StateNotifierProvider<ActiveWorkoutNotifier, ActiveWorkoutState>((ref) {
  return ActiveWorkoutNotifier(ref);
});

class ActiveWorkoutNotifier extends StateNotifier<ActiveWorkoutState> {
  final Ref _ref;
  Timer? _timer;
  final List<List<double>> _routePoints = [];
  final List<int> _hrHistory = [];

  ActiveWorkoutNotifier(this._ref) : super(const ActiveWorkoutState());

  void startWorkout(SportMode mode) {
    _routePoints.clear();
    _hrHistory.clear();
    state = ActiveWorkoutState(status: WorkoutStatus.running, mode: mode);
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void pauseWorkout() {
    if (state.status != WorkoutStatus.running) return;
    _timer?.cancel();
    state = state.copyWith(status: WorkoutStatus.paused);
  }

  void resumeWorkout() {
    if (state.status != WorkoutStatus.paused) return;
    state = state.copyWith(status: WorkoutStatus.running);
    _timer = Timer.periodic(const Duration(seconds: 1), _onTick);
  }

  void muteHrWarning() {
    final profile = _ref.read(userProfileProvider);
    _ref.read(bleServiceProvider).sendCommand(
          state.mode,
          profile.maxHR,
          muteWarning: true,
        );
  }

  void _onTick(Timer timer) {
    if (state.status != WorkoutStatus.running) return;

    final sensorData =
        _ref.read(sensorDataProvider).valueOrNull ?? const SensorData();
    final hr = sensorData.heartRate;
    final profile = _ref.read(userProfileProvider);

    // GPS route accumulation
    final gpsData = _ref.read(gpsDataProvider).valueOrNull;
    if (gpsData != null && gpsData.fixValid && gpsData.latitude != 0.0) {
      if (_routePoints.isEmpty ||
          _distSq(_routePoints.last[0], _routePoints.last[1],
                  gpsData.latitude, gpsData.longitude) >
              0.0000001) {
        _routePoints.add([gpsData.latitude, gpsData.longitude]);
      }
    }

    // HR stats
    int newHrSum = state.hrSum;
    int newHrCount = state.hrCount;
    int newHrMax = state.hrMax;
    if (hr > 0) {
      newHrSum += hr;
      newHrCount += 1;
      if (hr > newHrMax) newHrMax = hr;
      _hrHistory.add(hr);
    }

    // Incremental calories
    final incrementalCals =
        CalorieCalculator.caloriesPerMinute(hr, profile: profile) / 60.0;

    state = state.copyWith(
      durationSeconds: state.durationSeconds + 1,
      caloriesBurned: state.caloriesBurned + incrementalCals,
      routePoints: List.unmodifiable(_routePoints),
      hrSum: newHrSum,
      hrCount: newHrCount,
      hrMax: newHrMax,
      hrHistory: List.unmodifiable(_hrHistory),
    );
  }

  double _distSq(double lat1, double lon1, double lat2, double lon2) {
    return (lat1 - lat2) * (lat1 - lat2) + (lon1 - lon2) * (lon1 - lon2);
  }

  /// Stop workout and transition to "finished" state for the summary screen.
  /// Returns the WorkoutSession for display, but does NOT save yet.
  WorkoutSession? finishWorkout() {
    _timer?.cancel();

    if (state.durationSeconds < 5 || state.mode.isHealthTool) {
      reset();
      return null;
    }

    final sensorData =
        _ref.read(sensorDataProvider).valueOrNull ?? const SensorData();
    final gpsData =
        _ref.read(gpsDataProvider).valueOrNull ?? const GpsData();

    final session = WorkoutSession(
      id: const Uuid().v4(),
      mode: state.mode,
      startTime: DateTime.now()
          .subtract(Duration(seconds: state.durationSeconds)),
      durationSeconds: state.durationSeconds,
      calories: state.caloriesBurned,
      distance: gpsData.distance,
      steps: sensorData.stepCount,
      jumps: sensorData.jumpCount,
      avgHeartRate: state.avgHeartRate,
      maxHeartRate: state.maxHeartRate,
      routePoints: List.from(_routePoints),
      hrHistory: List.from(_hrHistory),
    );

    state = state.copyWith(
      status: WorkoutStatus.finished,
      lastSteps: sensorData.stepCount,
      lastJumps: sensorData.jumpCount,
      lastDistance: gpsData.distance,
    );

    return session;
  }

  /// Save the workout and reset state.
  Future<void> saveAndReset(WorkoutSession session) async {
    await _ref.read(workoutRepositoryProvider).saveWorkout(session);
    _ref.read(workoutHistoryProvider.notifier).loadWorkouts();
    reset();
  }

  void reset() {
    _timer?.cancel();
    _routePoints.clear();
    _hrHistory.clear();
    state = const ActiveWorkoutState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
