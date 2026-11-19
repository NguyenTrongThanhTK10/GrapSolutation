import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/models.dart';
import '../theme/app_theme.dart';
import 'grap_tile_layer.dart';

class GrapMap extends StatefulWidget {
  final Place? pickup, dropoff, driver;
  final double height, borderRadius;
  final bool showControls, showAttribution;
  final int cameraRevision;
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
    this.cameraRevision = 0,
    this.onPick,
  });
  @override
  State<GrapMap> createState() => _GrapMapState();
}

bool _usable(Place? place) =>
    place != null &&
    place.latitude.isFinite &&
    place.longitude.isFinite &&
    place.latitude >= -90 &&
    place.latitude <= 90 &&
    place.longitude >= -180 &&
    place.longitude <= 180;

bool _samePoint(Place? a, Place? b) =>
    a?.latitude == b?.latitude && a?.longitude == b?.longitude;

List<LatLng> _coordinates(Iterable<Place> places) => [
  for (final place in places)
    if (_usable(place)) LatLng(place.latitude, place.longitude),
];

class _GrapMapState extends State<GrapMap> {
  final controller = MapController();
  bool ready = false, userMoved = false, frameScheduled = false;

  List<LatLng> get points => {
    ..._coordinates([?widget.pickup, ?widget.dropoff, ?widget.driver]),
  }.toList();

  void _scheduleFit() {
    if (frameScheduled) return;
    frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      frameScheduled = false;
      if (mounted && !userMoved) _fitRoute();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  void fitRoute() {
    userMoved = false;
    _fitRoute();
  }

  void _fitRoute() {
    if (!ready) return;
    final size = controller.camera.nonRotatedSize;
    if (size.width <= 96 || size.height <= 96) return;
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
      controller.move(
        coordinates.single,
        widget.onPick == null ? 15 : controller.camera.zoom,
      );
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant GrapMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    final endpointsChanged =
        !_samePoint(oldWidget.pickup, widget.pickup) ||
        !_samePoint(oldWidget.dropoff, widget.dropoff);
    final explicit = oldWidget.cameraRevision != widget.cameraRevision;
    if (endpointsChanged || explicit) userMoved = false;
    if (!userMoved &&
        (endpointsChanged ||
            explicit ||
            !_samePoint(oldWidget.driver, widget.driver))) {
      _scheduleFit();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pickup = _usable(widget.pickup) ? widget.pickup : null,
        dropoff = _usable(widget.dropoff) ? widget.dropoff : null,
        driver = _usable(widget.driver) ? widget.driver : null;
    final height = widget.height;
    final onPick = widget.onPick;
    final center =
        pickup ??
        driver ??
        dropoff ??
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
              _scheduleFit();
            },
            initialCenter: LatLng(center.latitude, center.longitude),
            initialZoom: 15,
            minZoom: 3,
            maxZoom: 19,
            onPositionChanged: (_, hasGesture) {
              if (hasGesture) userMoved = true;
            },
            onMapEvent: (event) {
              if (event.source == MapEventSource.nonRotatedSizeChange) {
                _scheduleFit();
              }
            },
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
            ),
          ),
          children: [
            GrapTileLayer(
              children: [
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
                      (
                        driver,
                        Icons.navigation_rounded,
                        const Color(0xff2563eb),
                      ),
                    ])
                      if (entry.$1 != null)
                        Marker(
                          point: LatLng(
                            entry.$1!.latitude,
                            entry.$1!.longitude,
                          ),
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
                            child: Icon(
                              entry.$2,
                              color: Colors.white,
                              size: 17,
                            ),
                          ),
                        ),
                  ],
                ),
              ],
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
