import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import '../theme/app_theme.dart';

/// Tracks the tiles in the current viewport, including after a pan or zoom.
class GrapTileLayer extends StatefulWidget {
  final List<Widget> children;
  const GrapTileLayer({super.key, this.children = const []});

  @override
  State<GrapTileLayer> createState() => _GrapTileLayerState();
}

class _GrapTileLayerState extends State<GrapTileLayer> {
  NetworkTileProvider provider = _newProvider();
  Set<TileCoordinates> visible = {};
  final loaded = <TileCoordinates, bool>{};
  Timer? timer;
  int attempt = 0;
  bool timedOut = false, updateScheduled = false;

  static NetworkTileProvider _newProvider() => NetworkTileProvider(
    silenceExceptions: true,
    attemptDecodeOfHttpErrorResponses: false,
  );

  bool get complete =>
      visible.isNotEmpty && visible.every((tile) => loaded[tile] == true);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final camera = MapCamera.of(context);
    final zoom = camera.zoom.round().clamp(0, 19);
    final bounds = camera.pixelBoundsAtZoom(zoom.toDouble());
    final count = 1 << zoom;
    final next = <TileCoordinates>{
      for (
        var x = (bounds.left / 256).floor();
        x < (bounds.right / 256).ceil();
        x++
      )
        for (
          var y = (bounds.top / 256).floor().clamp(0, count - 1);
          y < (bounds.bottom / 256).ceil().clamp(0, count);
          y++
        )
          TileCoordinates(x % count, y, zoom),
    };
    if (setEquals(visible, next)) return;
    visible = next;
    loaded.removeWhere((tile, _) => !visible.contains(tile));
    timedOut = false;
    _watch();
  }

  void _watch() {
    timer?.cancel();
    timer = null;
    if (complete || visible.isEmpty) return;
    timer = Timer(const Duration(seconds: 8), () {
      timer = null;
      if (mounted && !complete) setState(() => timedOut = true);
    });
  }

  void _observe(TileImage tile, int generation) {
    if (generation != attempt || !visible.contains(tile.coordinates)) return;
    final image = tile.imageInfo?.image;
    // Silent network failures produce a transparent 1x1 placeholder.
    loaded[tile.coordinates] =
        !tile.loadError && image != null && image.width > 1 && image.height > 1;
    if (!complete) return;
    timer?.cancel();
    timer = null;
    if (!timedOut || updateScheduled) return;
    updateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      updateScheduled = false;
      if (mounted && complete && timedOut) {
        setState(() => timedOut = false);
      }
    });
  }

  void _retry() {
    setState(() {
      attempt++;
      // Replacing the keyed TileLayer closes the previous provider's client.
      provider = _newProvider();
      loaded.clear();
      timedOut = false;
    });
    _watch();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generation = attempt;
    return Stack(
      fit: StackFit.expand,
      children: [
        TileLayer(
          key: ValueKey(attempt),
          tileProvider: provider,
          tileBuilder: (context, child, tile) {
            _observe(tile, generation);
            return child;
          },
          urlTemplate: const String.fromEnvironment(
            'MAP_TILE_URL',
            defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          ),
          userAgentPackageName: 'vn.grapsolution.mobile',
          maxNativeZoom: 19,
        ),
        ...widget.children,
        if (timedOut)
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
                  const Icon(Icons.map_outlined, color: grapMuted, size: 24),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      loaded.values.any((value) => value)
                          ? 'Một phần bản đồ chưa tải được. Hãy thử lại.'
                          : 'Chưa tải được bản đồ. Kiểm tra kết nối và thử lại.',
                      style: const TextStyle(fontSize: 13, color: grapMuted),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Thử lại bản đồ',
                    onPressed: _retry,
                    icon: const Icon(Icons.refresh_rounded, color: grapGreen),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
