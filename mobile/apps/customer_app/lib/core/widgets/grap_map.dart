import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../domain/models.dart';
import '../domain/booking_discovery.dart';
import '../theme/app_theme.dart';
import 'grap_tile_layer.dart';

class GrapMap extends StatefulWidget {
  final Place? pickup, dropoff, driver;
  final List<Place> routePoints, recordedPoints;
  final List<NearbyDriver> nearbyDrivers;
  final double height, borderRadius;
  final bool showControls, showAttribution;
  final int cameraRevision;
  final ValueChanged<Place>? onPick;
  const GrapMap({
    super.key,
    this.pickup,
    this.dropoff,
    this.driver,
    this.routePoints = const [],
    this.recordedPoints = const [],
    this.nearbyDrivers = const [],
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

bool _samePoints(List<Place> a, List<Place> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!_samePoint(a[i], b[i])) return false;
  }
  return true;
}

class _GrapMapState extends State<GrapMap> {
  final controller = MapController();
  bool ready = false, userMoved = false, frameScheduled = false;
  bool nearbyFramed = false;

  List<LatLng> get points => {
    ..._coordinates([
      ?widget.pickup,
      ?widget.dropoff,
      ?widget.driver,
      ...widget.routePoints,
      ...widget.recordedPoints,
      ...widget.nearbyDrivers.map((driver) => driver.location),
    ]),
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
    final firstNearby = !nearbyFramed && widget.nearbyDrivers.isNotEmpty;
    nearbyFramed = nearbyFramed || widget.nearbyDrivers.isNotEmpty;
    if (endpointsChanged || explicit) userMoved = false;
    if (!userMoved &&
        (endpointsChanged ||
            explicit ||
            firstNearby ||
            !_samePoint(oldWidget.driver, widget.driver) ||
            !_samePoints(oldWidget.routePoints, widget.routePoints) ||
            !_samePoints(oldWidget.recordedPoints, widget.recordedPoints))) {
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
    final route = _coordinates(widget.routePoints);
    final recorded = _coordinates(widget.recordedPoints);
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
              nearbyFramed = widget.nearbyDrivers.isNotEmpty;
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
                if (route.length > 1 ||
                    recorded.length > 1 ||
                    (pickup != null && dropoff != null))
                  PolylineLayer(
                    polylines: [
                      if (route.length > 1)
                        Polyline(
                          points: route,
                          color: grapGreen,
                          strokeWidth: 5,
                          borderColor: Colors.white,
                          borderStrokeWidth: 2,
                        ),
                      if (recorded.length > 1)
                        Polyline(
                          points: recorded,
                          color: const Color(0xff2563eb),
                          strokeWidth: 5,
                          borderColor: Colors.white,
                          borderStrokeWidth: 2,
                        ),
                      if (route.length < 2 &&
                          recorded.length < 2 &&
                          pickup != null &&
                          dropoff != null)
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
                    for (final nearby in widget.nearbyDrivers)
                      if (_usable(nearby.location))
                        Marker(
                          key: ValueKey('nearby-${nearby.location.id}'),
                          point: LatLng(
                            nearby.location.latitude,
                            nearby.location.longitude,
                          ),
                          width: 42,
                          height: 42,
                          child: Tooltip(
                            message:
                                '${serviceLabel(nearby.service)} đang nhận chuyến',
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: grapGreen, width: 2),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x25326440),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: Icon(
                                nearby.service == 'BIKE'
                                    ? Icons.two_wheeler_rounded
                                    : nearby.service == 'CAR_7'
                                    ? Icons.airport_shuttle_rounded
                                    : Icons.local_taxi_rounded,
                                color: grapGreen,
                                size: 25,
                              ),
                            ),
                          ),
                        ),
                    for (final entry in [
                      (pickup, Icons.circle, grapGreen),
                      (dropoff, Icons.location_on, const Color(0xffc09267)),
                      (driver, Icons.local_taxi, grapGreen),
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
