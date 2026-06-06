import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Slide-to-action widget for finishing workouts safely.
class SlideToAction extends StatefulWidget {
  final VoidCallback onSlideComplete;
  final String label;
  final Color? backgroundColor;

  const SlideToAction({
    super.key,
    required this.onSlideComplete,
    this.label = 'SLIDE TO FINISH',
    this.backgroundColor,
  });

  @override
  State<SlideToAction> createState() => _SlideToActionState();
}

class _SlideToActionState extends State<SlideToAction>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0;
  bool _completed = false;
  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.backgroundColor ?? AppTheme.danger;

    return SizedBox(
      height: 64,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxDrag = constraints.maxWidth - 72;
          final progress = maxDrag > 0 ? (_dragPosition / maxDrag).clamp(0.0, 1.0) : 0.0;

          return Container(
            decoration: BoxDecoration(
              color: bgColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: bgColor.withValues(alpha: 0.3)),
            ),
            child: Stack(
              children: [
                // Progress fill
                AnimatedContainer(
                  duration: const Duration(milliseconds: 50),
                  width: _dragPosition + 64,
                  decoration: BoxDecoration(
                    color: bgColor.withValues(alpha: 0.3 + progress * 0.4),
                    borderRadius: BorderRadius.circular(32),
                  ),
                ),
                // Label
                Padding(
                  padding: const EdgeInsets.only(left: 56.0),
                  child: Center(
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return Opacity(
                          opacity: (1.0 - progress).clamp(0.3, 1.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.label,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(alpha: 0.7),
                                      letterSpacing: 2.0,
                                    ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: Colors.white.withValues(alpha: 0.5),
                                size: 14,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                // Draggable thumb
                Positioned(
                  left: _dragPosition,
                  top: 4,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (details) {
                      if (_completed) return;
                      setState(() {
                        _dragPosition =
                            (_dragPosition + details.delta.dx).clamp(0, maxDrag);
                      });
                    },
                    onHorizontalDragEnd: (details) {
                      if (_completed) return;
                      if (_dragPosition / maxDrag > 0.85) {
                        setState(() => _completed = true);
                        widget.onSlideComplete();
                      } else {
                        setState(() => _dragPosition = 0);
                      }
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: bgColor,
                        boxShadow: [
                          BoxShadow(
                            color: bgColor.withValues(alpha: 0.4),
                            blurRadius: 12,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Icon(
                        _completed ? Icons.check : Icons.stop,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
