import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/theme/app_theme.dart';
import 'pulse_animation.dart';

class OsmLiveMap extends StatefulWidget {
  final List<List<double>> routePoints;
  final double currentLat;
  final double currentLng;
  final bool hasFix;

  const OsmLiveMap({
    super.key,
    required this.routePoints,
    required this.currentLat,
    required this.currentLng,
    required this.hasFix,
  });

  @override
  State<OsmLiveMap> createState() => _OsmLiveMapState();
}

class _OsmLiveMapState extends State<OsmLiveMap> {
  final MapController _mapController = MapController();
  
  @override
  void didUpdateWidget(covariant OsmLiveMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Animate or pan camera if we have a new valid fix
    if (widget.hasFix && 
        widget.currentLat != 0.0 && 
        (oldWidget.currentLat != widget.currentLat || oldWidget.currentLng != widget.currentLng)) {
      _mapController.move(LatLng(widget.currentLat, widget.currentLng), 17.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<LatLng> polylinePoints = widget.routePoints
        .map((p) => LatLng(p[0], p[1]))
        .toList();
        
    final initialTarget = (widget.hasFix && widget.currentLat != 0.0) 
        ? LatLng(widget.currentLat, widget.currentLng) 
        : (polylinePoints.isNotEmpty ? polylinePoints.last : const LatLng(0, 0));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.surfaceLight),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialTarget,
              initialZoom: 16.0,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.sporttracker.app',
                // Darken the map for dark theme
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
                    color: AppTheme.primary, // Strava Orange
                    strokeWidth: 6.0,
                  ),
                ],
              ),
              if (widget.hasFix && widget.currentLat != 0.0)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: LatLng(widget.currentLat, widget.currentLng),
                      width: 24,
                      height: 24,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppTheme.primary.withValues(alpha: 0.5),
                              blurRadius: 10,
                              spreadRadius: 2,
                            )
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
          if (!widget.hasFix)
            Container(
              color: AppTheme.background.withValues(alpha: 0.8),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    PulseAnimation(
                      size: 100,
                      color: AppTheme.textMuted,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.surfaceLight.withValues(alpha: 0.1),
                        ),
                        child: const Icon(Icons.gps_off, color: AppTheme.textMuted, size: 32),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'WAITING FOR GPS LOCK',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
