import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Horizontal HR zone bar with 5 colored segments and position indicator.
class HrZoneBar extends StatelessWidget {
  final int heartRate;
  final int maxHR;

  const HrZoneBar({
    super.key,
    required this.heartRate,
    required this.maxHR,
  });

  @override
  Widget build(BuildContext context) {
    final hasHR = heartRate > 0 && maxHR > 0;
    final pct = hasHR ? (heartRate / maxHR).clamp(0.0, 1.0) : 0.0;
    final zoneName = AppTheme.hrZoneName(heartRate, maxHR);
    final zoneColor = AppTheme.hrZoneColor(heartRate, maxHR);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Zone label
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'HR ZONE',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppTheme.textMuted,
                    fontSize: 10,
                  ),
            ),
            Text(
              hasHR ? zoneName : '--',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: hasHR ? zoneColor : AppTheme.textMuted,
                    fontSize: 10,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        // Zone bar
        SizedBox(
          height: 8,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final totalWidth = constraints.maxWidth;
              return Stack(
                children: [
                  // Colored segments
                  Row(
                    children: [
                      _Segment(color: AppTheme.hrZone1, flex: 6), // 0-60%
                      const SizedBox(width: 2),
                      _Segment(color: AppTheme.hrZone2, flex: 1), // 60-70%
                      const SizedBox(width: 2),
                      _Segment(color: AppTheme.hrZone3, flex: 1), // 70-80%
                      const SizedBox(width: 2),
                      _Segment(color: AppTheme.hrZone4, flex: 1), // 80-90%
                      const SizedBox(width: 2),
                      _Segment(color: AppTheme.hrZone5, flex: 1), // 90-100%
                    ],
                  ),
                  // Position indicator
                  if (hasHR)
                    Positioned(
                      left: (pct * totalWidth - 6).clamp(0, totalWidth - 12),
                      top: -2,
                      child: Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          border: Border.all(color: zoneColor, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: zoneColor.withValues(alpha: 0.5),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Segment extends StatelessWidget {
  final Color color;
  final int flex;

  const _Segment({required this.color, required this.flex});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
