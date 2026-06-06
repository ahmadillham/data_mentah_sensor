import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/ble_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/workout_provider.dart';
import '../../providers/ble_provider.dart';
import '../widgets/status_bar.dart';
import '../widgets/osm_live_map.dart';
import '../widgets/hr_ring_widget.dart';
import '../widgets/glassmorphic_card.dart';
import '../widgets/hr_zone_bar.dart';
import '../widgets/slide_to_action.dart';

import 'workout_summary_screen.dart';

/// A Riverpod provider to track the currently *selected* mode before starting.
final selectedModeProvider = StateProvider<SportMode>((ref) => SportMode.running);

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeWorkout = ref.watch(activeWorkoutProvider);
    final selectedMode = ref.watch(selectedModeProvider);
    final sensorData = ref.watch(sensorDataProvider).valueOrNull;
    final gpsData = ref.watch(gpsDataProvider).valueOrNull;
    final profile = ref.watch(userProfileProvider);

    final hr = sensorData?.heartRate ?? 0;
    final steps = sensorData?.stepCount ?? 0;
    final jumps = sensorData?.jumpCount ?? 0;
    final pitch = sensorData?.pitch ?? 0.0;
    final speed = gpsData?.speed.toStringAsFixed(1) ?? '0.0';
    final distance = gpsData?.distance.toStringAsFixed(2) ?? '0.00';

    return Scaffold(
      appBar: AppBar(
        title: const Text('SPORT TRACKER'),
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: [
          const StatusBar(),
          Expanded(
            child: activeWorkout.isActive
                ? _buildActiveWorkout(
                    context, ref, activeWorkout,
                    hr, steps, jumps, speed, distance, pitch,
                    gpsData?.fixValid ?? false,
                    gpsData?.latitude ?? 0.0,
                    gpsData?.longitude ?? 0.0,
                    profile.maxHR,
                  )
                : _buildIdleDashboard(context, ref, selectedMode, gpsData),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  IDLE STATE — Preview + Activity Picker + START
  // ═══════════════════════════════════════════════
  Widget _buildIdleDashboard(
      BuildContext context, WidgetRef ref, SportMode selectedMode, dynamic gpsData) {
    final gpsFix = gpsData?.fixValid ?? false;
    final lat = gpsData?.latitude ?? 0.0;
    final lng = gpsData?.longitude ?? 0.0;

    return Column(
      children: [
        // ── Preview area based on selected mode ──
        Expanded(
          child: selectedMode.isOutdoor
              ? _buildMapPreview(gpsFix, lat, lng)
              : _buildIndoorPreview(context, selectedMode),
        ),

        // ── Activity Selector Chip ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
          child: InkWell(
            onTap: () => _showModePicker(context, ref),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.surfaceLight),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  selectedMode.hasCustomIcon
                      ? Image.asset(
                          selectedMode.customIconAsset!,
                          width: 24,
                          height: 24,
                          color: AppTheme.primary,
                        )
                      : Icon(selectedMode.icon, color: AppTheme.primary, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    selectedMode.label.toUpperCase(),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: AppTheme.textPrimary,
                          letterSpacing: 1.5,
                        ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.keyboard_arrow_down, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
        ),

        // ── START button with breathing animation ──
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: _AnimatedStartButton(
            onPressed: () {
              final mode = ref.read(selectedModeProvider);
              final profile = ref.read(userProfileProvider);
              ref.read(bleServiceProvider).sendCommand(mode, profile.maxHR);
              ref.read(activeWorkoutProvider.notifier).startWorkout(mode);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMapPreview(bool gpsFix, double lat, double lng) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: OsmLiveMap(
        routePoints: const [],
        currentLat: lat,
        currentLng: lng,
        hasFix: gpsFix,
      ),
    );
  }

  Widget _buildIndoorPreview(BuildContext context, SportMode mode) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          mode.hasCustomIcon
              ? Image.asset(
                  mode.customIconAsset!,
                  width: 100,
                  height: 100,
                  color: AppTheme.primary.withValues(alpha: 0.3),
                )
              : Icon(
                  mode.icon,
                  size: 100,
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
          const SizedBox(height: 24),
          Text(
            mode.label.toUpperCase(),
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.textMuted,
                  letterSpacing: 2.0,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            mode.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  ACTIVITY PICKER — Bottom Sheet
  // ═══════════════════════════════════════════════
  void _showModePicker(BuildContext context, WidgetRef ref) {
    final currentMode = ref.read(selectedModeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'SELECT ACTIVITY',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        letterSpacing: 1.5,
                      ),
                ),
                const SizedBox(height: 16),

                // Outdoor
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('OUTDOOR', style: Theme.of(context).textTheme.labelSmall),
                ),
                const SizedBox(height: 8),
                _buildModeItem(context, ref, SportMode.running, currentMode),
                const SizedBox(height: 8),
                _buildModeItem(context, ref, SportMode.cycling, currentMode),
                const SizedBox(height: 16),

                // Indoor
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('INDOOR', style: Theme.of(context).textTheme.labelSmall),
                ),
                const SizedBox(height: 8),
                _buildModeItem(context, ref, SportMode.jumpRope, currentMode),
                const SizedBox(height: 8),
                _buildModeItem(context, ref, SportMode.pushup, currentMode),
                const SizedBox(height: 8),
                _buildModeItem(context, ref, SportMode.squat, currentMode),
                const SizedBox(height: 8),
                _buildModeItem(context, ref, SportMode.plank, currentMode),
                const SizedBox(height: 16),
                
                // Health / Tools
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text('HEALTH / TOOLS', style: Theme.of(context).textTheme.labelSmall),
                ),
                const SizedBox(height: 8),
                _buildModeItem(context, ref, SportMode.hrMonitor, currentMode),
                const SizedBox(height: 8),
                _buildModeItem(context, ref, SportMode.postureCorrection, currentMode),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModeItem(
      BuildContext context, WidgetRef ref, SportMode mode, SportMode selected) {
    final isSelected = mode == selected;
    return InkWell(
      onTap: () => _selectMode(ref, context, mode),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary.withValues(alpha: 0.12) : AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.surfaceLight,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            mode.hasCustomIcon
                ? Image.asset(
                    mode.customIconAsset!,
                    width: 28,
                    height: 28,
                    color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                  )
                : Icon(
                    mode.icon,
                    color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                    size: 28,
                  ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label.toUpperCase(),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                          letterSpacing: 1.0,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.subtitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                        ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle, color: AppTheme.primary, size: 24),
          ],
        ),
      ),
    );
  }

  void _selectMode(WidgetRef ref, BuildContext ctx, SportMode mode) {
    ref.read(selectedModeProvider.notifier).state = mode;
    Navigator.pop(ctx);
  }

  // ═══════════════════════════════════════════════
  //  ACTIVE WORKOUT — Live Stats (Redesigned)
  // ═══════════════════════════════════════════════
  Widget _buildActiveWorkout(
    BuildContext context, WidgetRef ref, ActiveWorkoutState state,
    int hr, int steps, int jumps,
    String speed, String distance,
    double pitch, bool gpsFix, double lat, double lng, int maxHR,
  ) {
    final h = state.durationSeconds ~/ 3600;
    final m = (state.durationSeconds % 3600) ~/ 60;
    final s = state.durationSeconds % 60;
    final timeStr = '${h > 0 ? '$h:' : ''}${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                const SizedBox(height: 8),

                // ── Mode badge + Timer ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Mode badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          state.mode.hasCustomIcon
                              ? Image.asset(
                                  state.mode.customIconAsset!,
                                  width: 16,
                                  height: 16,
                                  color: AppTheme.primary,
                                )
                              : Icon(state.mode.icon, color: AppTheme.primary, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            state.mode.label.toUpperCase(),
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: AppTheme.primary,
                                  fontSize: 11,
                                ),
                          ),
                        ],
                      ),
                    ),
                    // Pause indicator
                    if (state.isPaused)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'PAUSED',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: AppTheme.warning,
                                fontSize: 10,
                              ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // ── HR Hero Ring (Hidden for Posture Mode) ──
                if (state.mode != SportMode.postureCorrection) ...[
                  HrRingWidget(
                    heartRate: hr,
                    maxHR: maxHR,
                    size: state.mode == SportMode.hrMonitor ? 200 : 160,
                  ),
                  const SizedBox(height: 8),

                  // ── HR Zone Bar ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: HrZoneBar(heartRate: hr, maxHR: maxHR),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── Posture Visualizer (Only for Posture Mode) ──
                if (state.mode == SportMode.postureCorrection)
                  _buildLivePostureVisualizer(context, ref),

                // ── Metric Cards Row (Hidden for Health/Tools modes) ──
                if (!state.mode.isHealthTool)
                  _buildMetricCards(context, state, timeStr, hr, steps, jumps,
                      speed, distance, pitch),
                const SizedBox(height: 12),

                // ── Posture Banner ──
                if (state.mode == SportMode.running ||
                    state.mode == SportMode.jumpRope)
                  _buildPostureBanner(context, pitch),

                if (state.mode == SportMode.plank)
                  _buildPlankBanner(context, jumps),

                // ── Map (outdoor) — constrained to 30% ──
                if (state.mode.isOutdoor)
                  SizedBox(
                    height: 180,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: OsmLiveMap(
                        routePoints: state.routePoints,
                        currentLat: lat,
                        currentLng: lng,
                        hasFix: gpsFix,
                      ),
                    ),
                  ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        if (hr > 0 && maxHR > 0 && hr > maxHR)
          _buildHrWarningBanner(context, ref),

        // ── Bottom Controls: Pause + Slide to Finish ──
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(
            children: [
              // Pause/Resume button
              SizedBox(
                width: 56,
                height: 56,
                child: IconButton.filled(
                  onPressed: () {
                    if (state.isPaused) {
                      ref.read(activeWorkoutProvider.notifier).resumeWorkout();
                    } else {
                      ref.read(activeWorkoutProvider.notifier).pauseWorkout();
                    }
                  },
                  style: IconButton.styleFrom(
                    backgroundColor: AppTheme.surfaceLight,
                    shape: const CircleBorder(),
                  ),
                  icon: Icon(
                    state.isPaused ? Icons.play_arrow : Icons.pause,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Slide to Finish
              Expanded(
                child: SlideToAction(
                  onSlideComplete: () {
                    final profile = ref.read(userProfileProvider);
                    ref.read(bleServiceProvider).sendCommand(SportMode.idle, profile.maxHR);
                    final session = ref.read(activeWorkoutProvider.notifier).finishWorkout();
                    if (session != null) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => WorkoutSummaryScreen(
                            session: session,
                            onSave: () {
                              ref.read(activeWorkoutProvider.notifier).saveAndReset(session);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      );
                    } else {
                      // If it's a health tool (no session saved) or too short, just go back to idle
                      ref.read(activeWorkoutProvider.notifier).reset();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCards(BuildContext context, ActiveWorkoutState state,
      String timeStr, int hr, int steps, int jumps,
      String speed, String distance, double pitch) {

    // Always show time and calories
    final List<Widget> cards = [
      Expanded(
        child: GlassmorphicCard(
          label: 'TIME',
          value: timeStr,
          icon: Icons.timer_outlined,
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: GlassmorphicCard(
          label: 'CALORIES',
          value: state.caloriesBurned.toStringAsFixed(0),
          unit: 'kcal',
          icon: Icons.local_fire_department,
          accentColor: AppTheme.accent,
        ),
      ),
    ];

    // Mode-specific third card
    Widget? thirdCard;
    if (state.mode == SportMode.running) {
      thirdCard = GlassmorphicCard(
        label: 'STEPS',
        value: steps > 0 ? '$steps' : '--',
        icon: Icons.directions_walk,
      );
    } else if (state.mode == SportMode.cycling) {
      thirdCard = GlassmorphicCard(
        label: 'SPEED',
        value: speed,
        unit: 'km/h',
        icon: Icons.speed,
      );
    } else if (state.mode == SportMode.jumpRope ||
               state.mode == SportMode.pushup ||
               state.mode == SportMode.squat) {
      thirdCard = GlassmorphicCard(
        label: 'REPS',
        value: jumps > 0 ? '$jumps' : '--',
        icon: Icons.fitness_center,
        accentColor: AppTheme.primary,
      );
    } else if (state.mode == SportMode.plank) {
      thirdCard = GlassmorphicCard(
        label: 'HOLD',
        value: timeStr,
        icon: Icons.self_improvement,
      );
    }

    if (thirdCard != null) {
      cards.add(const SizedBox(width: 8));
      cards.add(Expanded(child: thirdCard));
    }

    // Second row for outdoor modes
    Widget? secondRow;
    if (state.mode == SportMode.running || state.mode == SportMode.cycling) {
      secondRow = Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          children: [
            Expanded(
              child: GlassmorphicCard(
                label: 'DISTANCE',
                value: distance,
                unit: 'km',
                icon: Icons.straighten,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: GlassmorphicCard(
                label: 'PACE',
                value: speed,
                unit: 'km/h',
                icon: Icons.speed,
              ),
            ),
            if (state.mode == SportMode.running) ...[
              const SizedBox(width: 8),
              Expanded(
                child: GlassmorphicCard(
                  label: 'STEPS',
                  value: steps > 0 ? '$steps' : '--',
                  icon: Icons.directions_walk,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        Row(children: cards),
        ?secondRow,
      ],
    );
  }

  Widget _buildPostureBanner(BuildContext context, double pitch) {
    final isGood = pitch.abs() <= 15.0;
    final color = isGood ? AppTheme.success : AppTheme.danger;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isGood ? Icons.check_circle_outline : Icons.warning_amber,
              color: color,
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isGood
                  ? 'POSTURE: GOOD (${pitch.abs().toStringAsFixed(1)}°)'
                  : 'POSTURE: HUNCHING (${pitch.abs().toStringAsFixed(1)}°)',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlankBanner(BuildContext context, int jumps) {
    final isGood = jumps == 0;
    final color = isGood ? AppTheme.success : AppTheme.danger;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Center(
          child: Text(
            isGood ? 'GOOD POSTURE ✓' : 'WARNING: FIX FORM',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ),
      ),
    );
  }

  Widget _buildHrWarningBanner(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.danger.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HIGH HEART RATE',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: AppTheme.danger,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  Text(
                    'Slow down! Tap to mute alarm for 5m.',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.danger,
                        ),
                  ),
                ],
              ),
            ),
            IconButton.filled(
              onPressed: () {
                ref.read(activeWorkoutProvider.notifier).muteHrWarning();
              },
              style: IconButton.styleFrom(
                backgroundColor: AppTheme.danger,
              ),
              icon: const Icon(Icons.volume_off, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════
  //  LIVE POSTURE VISUALIZER (For Health/Tools Mode)
  // ═══════════════════════════════════════════════
  Widget _buildLivePostureVisualizer(BuildContext context, WidgetRef ref) {
    final sensorData = ref.watch(sensorDataProvider).valueOrNull;
    final pitch = sensorData?.pitch ?? 0.0;
    final roll = sensorData?.roll ?? 0.0;
    
    final isPitchGood = pitch.abs() <= 15.0;
    final isRollGood = roll.abs() <= 15.0;
    final isPostureGood = isPitchGood && isRollGood;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      child: Column(
        children: [
          SizedBox(
            height: 240,
            child: Center(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Target area (safe zone)
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.success.withValues(alpha: 0.1),
                      border: Border.all(
                        color: AppTheme.success.withValues(alpha: 0.3),
                        width: 2,
                        style: BorderStyle.solid,
                      ),
                    ),
                  ),
                  
                  // Outer boundary ring
                  Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppTheme.surfaceLight,
                        width: 1,
                      ),
                    ),
                  ),
                  
                  // Axes
                  Container(width: 220, height: 1, color: AppTheme.surfaceLight.withValues(alpha: 0.5)),
                  Container(width: 1, height: 220, color: AppTheme.surfaceLight.withValues(alpha: 0.5)),
                  
                  // Marker
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 100),
                    curve: Curves.easeOut,
                    top: 110 - 10 - (pitch.clamp(-27.5, 27.5) / 15.0 * 60.0),
                    left: 110 - 10 + (roll.clamp(-27.5, 27.5) / 15.0 * 60.0),
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isPostureGood ? AppTheme.success : AppTheme.danger,
                        boxShadow: [
                          BoxShadow(
                            color: (isPostureGood ? AppTheme.success : AppTheme.danger).withValues(alpha: 0.5),
                            blurRadius: 10,
                            spreadRadius: 2,
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          Text(
            isPostureGood ? 'GOOD POSTURE' : 'ADJUST YOUR POSTURE',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: isPostureGood ? AppTheme.success : AppTheme.danger,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep the dot inside the green circle (±15°)',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.textMuted,
                ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: GlassmorphicCard(
                  label: 'PITCH',
                  value: '${pitch.toStringAsFixed(1)}°',
                  icon: Icons.height,
                  accentColor: isPitchGood ? AppTheme.success : AppTheme.danger,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassmorphicCard(
                  label: 'ROLL',
                  value: '${roll.toStringAsFixed(1)}°',
                  icon: Icons.swap_horiz,
                  accentColor: isRollGood ? AppTheme.success : AppTheme.danger,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════
//  Animated START Button with breathing effect
// ═══════════════════════════════════════════════
class _AnimatedStartButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _AnimatedStartButton({required this.onPressed});

  @override
  State<_AnimatedStartButton> createState() => _AnimatedStartButtonState();
}

class _AnimatedStartButtonState extends State<_AnimatedStartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scaleAnim,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: Container(
            width: double.infinity,
            height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.4 * (_scaleAnim.value - 1.0) * 20),
                  blurRadius: 15,
                  spreadRadius: 4,
                )
              ],
            ),
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                elevation: 0, // Elevation is handled by the container shadow
              ),
              onPressed: widget.onPressed,
              child: Text(
                'START',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      letterSpacing: 4.0,
                    ),
              ),
            ),
          ),
        );
      },
    );
  }
}
