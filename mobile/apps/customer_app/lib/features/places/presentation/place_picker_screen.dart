import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';

class PlacePickerScreen extends ConsumerStatefulWidget {
  final Place? initial;
  final String title;
  final bool locateOnOpen;
  const PlacePickerScreen({
    super.key,
    this.initial,
    required this.title,
    this.locateOnOpen = false,
  });
  @override
  ConsumerState<PlacePickerScreen> createState() => _PlacePickerState();
}

class _PlacePickerState extends ConsumerState<PlacePickerScreen> {
  late Place point =
      widget.initial ??
      const Place(
        id: 'manual',
        address: '',
        latitude: 10.7721,
        longitude: 106.6983,
      );
  late final address = TextEditingController(
    text: widget.initial?.address ?? '',
  );
  int locationRevision = 0;
  double? accuracy;
  @override
  void initState() {
    super.initState();
    if (widget.locateOnOpen) Future.microtask(locate);
  }

  Future<void> locate() async {
    final revision = ++locationRevision;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final p = await ref.read(locationProvider).current();
      if (!mounted || revision != locationRevision) return;
      setState(() {
        point = Place(
          id: 'manual',
          address: 'Vị trí hiện tại',
          latitude: p.latitude,
          longitude: p.longitude,
        );
        address.text = 'Vị trí hiện tại';
        accuracy = p.accuracy;
      });
    } catch (e) {
      if (mounted && revision == locationRevision) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted && revision == locationRevision) setState(() => busy = false);
    }
  }

  bool busy = false;
  String? error;
  @override
  void dispose() {
    locationRevision++;
    address.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
      ),
    ),
    bottomNavigationBar: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: GrapActionSurface(
          child: FilledButton(
            onPressed: address.text.trim().length < 3 || busy
                ? null
                : () => Navigator.pop(
                    context,
                    Place(
                      id: '${point.latitude},${point.longitude}',
                      address: address.text.trim(),
                      latitude: point.latitude,
                      longitude: point.longitude,
                    ),
                  ),
            child: const Text('Xác nhận vị trí'),
          ),
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        TextField(
          controller: address,
          maxLength: 500,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Địa chỉ / mô tả điểm đã chọn',
            hintText: 'Tên tòa nhà, cổng vào, hướng dẫn đón…',
          ),
        ),
        const SizedBox(height: 12),
        GrapMap(
          pickup: point,
          height: MediaQuery.sizeOf(context).height < 500 ? 180 : 260,
          onPick: (p) => setState(() {
            locationRevision++;
            busy = false;
            accuracy = null;
            point = p;
            address.clear();
            error = null;
          }),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: busy ? null : locate,
          icon: const Icon(Icons.my_location, size: 18),
          label: Text(
            busy ? 'Đang xác định vị trí…' : 'Sử dụng vị trí thiết bị',
          ),
        ),
        if (accuracy != null)
          GrapNotice(
            accuracy! > 100
                ? 'GPS chưa chính xác. Hãy kiểm tra và chỉnh ghim trước khi xác nhận.'
                : 'Đã tìm được vị trí. Kiểm tra ghim và bổ sung hướng dẫn đón nếu cần.',
          ),
        if (error != null) GrapNotice(error!, error: true),
        const Text(
          'Chạm bản đồ để chỉnh ghim. Bạn có thể chọn thủ công khi không cấp quyền GPS.',
          style: TextStyle(fontSize: 13, color: grapMuted, height: 1.5),
        ),
      ],
    ),
  );
}
