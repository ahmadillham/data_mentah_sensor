import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Concentric pulsing ring animation for BLE scanning state.
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final bool isAnimating;
  final Color? color;
  final double size;

  const PulseAnimation({
    super.key,
    required this.child,
    this.isAnimating = true,
    this.color,
    this.size = 200,
  });

  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with TickerProviderStateMixin {
  late AnimationController _ring1;
  late AnimationController _ring2;
  late AnimationController _ring3;

  @override
  void initState() {
    super.initState();
    _ring1 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _ring2 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _ring3 = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    if (widget.isAnimating) _startAnimations();
  }

  void _startAnimations() {
    _ring1.repeat();
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _ring2.repeat();
    });
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) _ring3.repeat();
    });
  }

  void _stopAnimations() {
    _ring1.stop();
    _ring2.stop();
    _ring3.stop();
  }

  @override
  void didUpdateWidget(covariant PulseAnimation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isAnimating && !oldWidget.isAnimating) {
      _startAnimations();
    } else if (!widget.isAnimating && oldWidget.isAnimating) {
      _stopAnimations();
    }
  }

  @override
  void dispose() {
    _ring1.dispose();
    _ring2.dispose();
    _ring3.dispose();
    super.dispose();
  }

  Widget _buildRing(AnimationController controller) {
    final color = widget.color ?? AppTheme.primary;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        final scale = 1.0 + controller.value * 0.8;
        final opacity = (1.0 - controller.value).clamp(0.0, 0.4);
        return Transform.scale(
          scale: scale,
          child: Container(
            width: widget.size * 0.6,
            height: widget.size * 0.6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: color.withValues(alpha: opacity),
                width: 2,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isAnimating) ...[
            _buildRing(_ring3),
            _buildRing(_ring2),
            _buildRing(_ring1),
          ],
          widget.child,
        ],
      ),
    );
  }
}
