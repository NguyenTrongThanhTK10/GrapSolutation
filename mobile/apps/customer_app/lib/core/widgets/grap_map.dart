import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/models.dart';
import '../theme/app_theme.dart';

class GrapMap extends StatefulWidget {
  final Place? pickup, dropoff, driver;
  final double height, borderRadius;
  final bool showControls, showAttribution;
  final ValueChanged<Place>? onPick;
  const GrapMap({
    super.key,
    this.pickup,
    this.dropoff,
    this.driver,
    this.height = 280,
    this.borderRadius = 16,
    this.showControls = true,
    this.showAttribution = true,
    this.onPick,
  });
  @override
  State<GrapMap> createState() => _GrapMapState();
}

class _GrapMapState extends State<GrapMap> {
  final controller = MapController();
  bool ready = false, tilesLoaded = false, tileTimeout = false;
  int tileAttempt = 0;
  Timer? tileTimer;

  @override
  void initState() {
    super.initState();
    _watchTiles();
  }

  void _watchTiles() {
    tileTimer?.cancel();
    tileTimer = Timer(const Duration(seconds: 8), () {
      if (mounted && !tilesLoaded) { setState(() => tileTimeout = true); }
    });
  }

  void _retryTiles() {
    setState(() {
      tileAttempt++;
      tilesLoaded = false;
      tileTimeout = false;
    });
    _watchTiles();
  }

  void _tileLoaded() {
    if (tilesLoaded) { return; }
    tilesLoaded = true;
    tileTimer?.cancel();
    if (tileTimeout) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { setState(() => tileTimeout = false); }
      });
    }
  }

  List<LatLng> get points => {
    for (final place in [widget.pickup, widget.dropoff, widget.driver])
      if (place != null) LatLng(place.latitude, place.longitude),
  }.toList();

  void fitRoute() {
    if (!ready) {
      return;
    }
    final size = controller.camera.nonRotatedSize;
    if (size.width <= 96 || size.height <= 96) {
      return;
    }
    final coordinates = points;
    if (coordinates.length > 1) {
      controller.fitCamera(
        CameraFit.coordinates(
          coordinates: coordinates,
          padding: const EdgeInsets.all(44),
          maxZoom: 16,
        ),
      );
    } else if (coordinates.isNotEmpty) {
      controller.move(coordinates.single, 15);
    }
  }

  @override
  void didUpdateWidget(covariant GrapMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final changed =
        [
          (oldWidget.pickup, widget.pickup),
          (oldWidget.dropoff, widget.dropoff),
          (oldWidget.driver, widget.driver),
        ].any(
          (pair) =>
              pair.$1?.latitude != pair.$2?.latitude ||
              pair.$1?.longitude != pair.$2?.longitude,
        );
    if (changed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          fitRoute();
        }
      });
    }
  }

  @override
  void dispose() {
    tileTimer?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pickup = widget.pickup,
        dropoff = widget.dropoff,
        driver = widget.driver;
    final height = widget.height;
    final onPick = widget.onPick;
    final center =
        pickup ??
        const Place(
          id: 'hcm',
          address: 'HCM',
          latitude: 10.788,
          longitude: 106.699,
        );
    return ClipRRect(
      borderRadius: BorderRadius.circular(widget.borderRadius),
      child: SizedBox(
        height: height,
        child: FlutterMap(
          mapController: controller,
          options: MapOptions(
            onTap: onPick == null
                ? null
                : (_, p) => onPick(
                    Place(
                      id: 'manual',
                      address: 'Điểm đã chọn',
                      latitude: p.latitude,
                      longitude: p.longitude,
                    ),
                  ),
            onMapReady: () {
              ready = true;
              fitRoute();
            },
            initialCenter: LatLng(center.latitude, center.longitude),
            initialZoom: 13,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            TileLayer(
              key: ValueKey(tileAttempt),
              tileBuilder: (context, tileWidget, tile) {
                if (!tile.loadError && tile.imageInfo != null) { _tileLoaded(); }
                return tileWidget;
              },
              urlTemplate: const String.fromEnvironment(
                'MAP_TILE_URL',
                defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              userAgentPackageName: 'vn.grapsolution.mobile',
            ),
            if (pickup != null && dropoff != null)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: [
                      LatLng(pickup.latitude, pickup.longitude),
                      LatLng(dropoff.latitude, dropoff.longitude),
                    ],
                    color: grapGreen.withValues(alpha: .5),
                    strokeWidth: 3,
                    pattern: StrokePattern.dashed(segments: [8, 8]),
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                for (final entry in [
                  (pickup, Icons.circle, grapGreen),
                  (dropoff, Icons.location_on, const Color(0xffc09267)),
                  (driver, Icons.local_taxi, grapGreen),
                ])
                  if (entry.$1 != null)
                    Marker(
                      point: LatLng(entry.$1!.latitude, entry.$1!.longitude),
                      width: 36,
                      height: 36,
                      child: Container(
                        decoration: BoxDecoration(
                          color: entry.$3,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x25326440),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(entry.$2, color: Colors.white, size: 17),
                      ),
                    ),
              ],
            ),
            if (tileTimeout)
              Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 290),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Color(0x12000000), blurRadius: 16),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.map_outlined,
                        color: grapMuted,
                        size: 24,
                      ),
                      const SizedBox(width: 10),
                      const Flexible(
                        child: Text(
                          'Chưa tải được bản đồ. Kiểm tra kết nối và thử lại.',
                          style: TextStyle(fontSize: 13, color: grapMuted),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Thử lại bản đồ',
                        onPressed: _retryTiles,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: grapGreen,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (widget.showControls)
              Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12, bottom: 42),
                  child: IconButton.filledTonal(
                    tooltip: 'Xem toàn bộ hành trình',
                    onPressed: fitRoute,
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: grapInk,
                    ),
                    icon: const Icon(Icons.center_focus_strong_rounded),
                  ),
                ),
              ),
            if (widget.showAttribution)
              const Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: EdgeInsets.all(4),
                  child: GrapMapAttribution(),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GrapMapAttribution extends StatelessWidget {
  const GrapMapAttribution({super.key});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => launchUrl(
      Uri.https('www.openstreetmap.org', '/copyright'),
      mode: LaunchMode.externalApplication,
    ),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .9),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        String.fromEnvironment(
          'MAP_ATTRIBUTION',
          defaultValue: '© OpenStreetMap contributors',
        ),
        style: TextStyle(fontSize: 10, height: 1.2, color: grapInk),
      ),
    ),
  );
}
