import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/ble_constants.dart';
import '../../data/models/models.dart';
import 'package:fl_chart/fl_chart.dart';

class HistoryDetailScreen extends StatefulWidget {
  final WorkoutSession session;

  const HistoryDetailScreen({super.key, required this.session});

  @override
  State<HistoryDetailScreen> createState() => _HistoryDetailScreenState();
}

class _HistoryDetailScreenState extends State<HistoryDetailScreen> {
  final MapController _mapController = MapController();

  String _getTimeOfDay(int hour) {
    if (hour < 12) return 'Morning';
    if (hour < 17) return 'Afternoon';
    return 'Evening';
  }

  @override
  Widget build(BuildContext context) {
    final List<LatLng> polylinePoints = widget.session.routePoints
        .map((p) => LatLng(p[0], p[1]))
        .toList();

    final bounds = polylinePoints.isNotEmpty ? LatLngBounds.fromPoints(polylinePoints) : null;
    final isBoundsValid = bounds != null && bounds.southWest != bounds.northEast;

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.session.mode.label.toUpperCase()} ACTIVITY'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── User Header ──
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 24,
                    backgroundColor: AppTheme.surfaceLight,
                    child: Icon(Icons.person, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_getTimeOfDay(widget.session.startTime.hour)} ${widget.session.mode.label}',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        DateFormat('EEEE, MMM d, yyyy @ h:mm a').format(widget.session.startTime),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── Primary Summary Stats ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  if (widget.session.mode == SportMode.running || widget.session.mode == SportMode.cycling) ...[
                    Expanded(
                      child: _DetailStat(
                        label: 'Distance',
                        value: '${widget.session.distance.toStringAsFixed(2)} km',
                      ),
                    ),
                    Expanded(
                      child: _DetailStat(
                        label: 'Avg Pace',
                        value: widget.session.distance > 0 
                            ? '${(widget.session.durationSeconds / 60 / widget.session.distance).toStringAsFixed(2)} /km'
                            : '--',
                      ),
                    ),
                  ] else if (widget.session.mode == SportMode.plank) ...[
                     Expanded(
                      child: _DetailStat(
                        label: 'Posture',
                        value: widget.session.jumps == 0 ? 'Good' : 'Warning',
                      ),
                    ),
                  ] else ...[
                     Expanded(
                      child: _DetailStat(
                        label: 'Total Reps',
                        value: '${widget.session.jumps}',
                      ),
                    ),
                  ],
                  Expanded(
                    child: _DetailStat(
                      label: 'Time',
                      value: widget.session.formattedDuration,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Static Map Route (Only GPS modes) ──
            if (widget.session.mode == SportMode.running || widget.session.mode == SportMode.cycling)
              if (widget.session.routePoints.isNotEmpty)
              SizedBox(
                height: 300,
                width: double.infinity,
                child: FlutterMap(
                  mapController: _mapController,
                  options: MapOptions(
                    initialCameraFit: isBoundsValid
                        ? CameraFit.bounds(
                            bounds: bounds,
                            padding: const EdgeInsets.all(50.0),
                          )
                        : null,
                    initialCenter: (!isBoundsValid && polylinePoints.isNotEmpty)
                        ? polylinePoints.first
                        : const LatLng(0, 0),
                    initialZoom: 16.0,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none, // Static map
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.sporttracker.app',
                      tileBuilder: (context, tileWidget, tile) {
                        return ColorFiltered(
                          colorFilter: const ColorFilter.matrix([
                            -1, 0, 0, 0, 255, //
                            0, -1, 0, 0, 255, //
                            0, 0, -1, 0, 255, //
                            0, 0, 0, 1, 0, //
                          ]),
                          child: tileWidget,
                        );
                      },
                    ),
                    PolylineLayer(
                      polylines: [
                        Polyline(
                          points: polylinePoints,
                          color: AppTheme.primary,
                          strokeWidth: 5.0,
                        ),
                      ],
                    ),
                  ],
                ),
              )
            else
              Container(
                height: 200,
                color: AppTheme.surface,
                child: const Center(
                  child: Text('No GPS data recorded for this activity.'),
                ),
              ),

            // ── Detailed Stats Grid ──
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.surfaceLight),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _DetailStat(label: 'Calories', value: '${widget.session.calories.toStringAsFixed(0)} kcal')),
                        Expanded(child: _DetailStat(label: 'Avg Heart Rate', value: '${widget.session.avgHeartRate} bpm')),
                      ],
                    ),
                    const Divider(height: 32, color: AppTheme.surfaceLight),
                    Row(
                      children: [
                        Expanded(child: _DetailStat(label: 'Max Heart Rate', value: '${widget.session.maxHeartRate} bpm')),
                        if (widget.session.mode == SportMode.running)
                          Expanded(child: _DetailStat(label: 'Steps', value: '${widget.session.steps}')),
                        if (widget.session.mode == SportMode.jumpRope || widget.session.mode == SportMode.pushup || widget.session.mode == SportMode.squat)
                          Expanded(child: _DetailStat(label: 'Reps', value: '${widget.session.jumps}')),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            // ── Heart Rate Chart ──
            if (widget.session.hrHistory.isNotEmpty)
              _buildHrChart(),
              
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHrChart() {
    final hrData = widget.session.hrHistory;
    
    final spots = <FlSpot>[];
    for (int i = 0; i < hrData.length; i++) {
      spots.add(FlSpot(i.toDouble(), hrData[i].toDouble()));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.surfaceLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Heart Rate', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 24),
            SizedBox(
              height: 200,
              width: double.infinity,
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: FlTitlesData(
                    show: true,
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: AppTheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppTheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                  minY: 40,
                  maxY: 220,
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => AppTheme.surfaceLight,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          return LineTooltipItem(
                            '${spot.y.toInt()} bpm\n',
                            const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                            children: [
                              TextSpan(
                                text: '${(spot.x / 60).floor()}:${(spot.x % 60).toInt().toString().padLeft(2, '0')}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailStat extends StatelessWidget {
  final String label;
  final String value;

  const _DetailStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleLarge),
      ],
    );
  }
}
