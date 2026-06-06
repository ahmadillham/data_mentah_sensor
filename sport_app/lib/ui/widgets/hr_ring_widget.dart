import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Circular animated ring showing heart rate as hero metric.
/// Color changes based on HR zone (% of maxHR).
class HrRingWidget extends StatefulWidget {
  final int heartRate;
  final int maxHR;
  final double size;

  const HrRingWidget({
    super.key,
    required this.heartRate,
    required this.maxHR,
    this.size = 180,
  });

  @override
  State<HrRingWidget> createState() => _HrRingWidgetState();
}

class _HrRingWidgetState extends State<HrRingWidget>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _arcController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _arcController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
  }

  @override
  void didUpdateWidget(covariant HrRingWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heartRate != widget.heartRate) {
      final target = widget.maxHR > 0
          ? (widget.heartRate / widget.maxHR).clamp(0.0, 1.0)
          : 0.0;
      _arcController.animateTo(target,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _arcController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final zoneColor = AppTheme.hrZoneColor(widget.heartRate, widget.maxHR);
    final hasHR = widget.heartRate > 0;

    return ScaleTransition(
      scale: hasHR ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background ring
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CircularProgressIndicator(
                value: 1.0,
                strokeWidth: 8,
                color: AppTheme.surfaceLight,
                strokeCap: StrokeCap.round,
              ),
            ),
            // Animated arc
            AnimatedBuilder(
              animation: _arcController,
              builder: (context, child) {
                return SizedBox(
                  width: widget.size,
                  height: widget.size,
                  child: CustomPaint(
                    painter: _ArcPainter(
                      progress: _arcController.value,
                      color: zoneColor,
                      strokeWidth: 8,
                    ),
                  ),
                );
              },
            ),
            // Inner glow
            if (hasHR)
              Container(
                width: widget.size * 0.75,
                height: widget.size * 0.75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      zoneColor.withValues(alpha: 0.15),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            // HR value
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  hasHR ? '${widget.heartRate}' : '--',
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: hasHR ? zoneColor : AppTheme.textMuted,
                        fontSize: widget.size * 0.35,
                      ),
                ),
                Text(
                  'bpm',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: hasHR ? zoneColor : AppTheme.textMuted,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  final double progress;
  final Color color;
  final double strokeWidth;

  _ArcPainter({
    required this.progress,
    required this.color,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );

    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Draw arc from top (-90°) clockwise
    canvas.drawArc(
      rect,
      -pi / 2,
      2 * pi * progress,
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.progress != progress || old.color != color;
}
