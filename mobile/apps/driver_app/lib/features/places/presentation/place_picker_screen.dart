import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/widgets/app_widgets.dart';

class PlacePickerScreen extends ConsumerStatefulWidget {
  final Place? initial;
  final String title;
  const PlacePickerScreen({super.key, this.initial, required this.title});
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
  bool busy = false;
  String? error;
  int locationRevision = 0, cameraRevision = 0;
  double? accuracy;

  Future<void> locate() async {
    final revision = ++locationRevision;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final position = await ref.read(locationProvider).current();
      if (!mounted || revision != locationRevision) return;
      setState(() {
        point = Place(
          id: 'manual',
          address: 'Vị trí hiện tại',
          latitude: position.latitude,
          longitude: position.longitude,
        );
        address.text = 'Vị trí hiện tại';
        accuracy = position.accuracy;
        cameraRevision++;
      });
    } catch (e) {
      if (mounted && revision == locationRevision) {
        setState(() => error = e.toString());
      }
    } finally {
      if (mounted && revision == locationRevision) setState(() => busy = false);
    }
  }

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
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const GrapNotice(
          'Chạm lên bản đồ để đặt ghim, nhập địa chỉ hoặc hướng dẫn điểm đón. Có thể nhập thủ công khi không cấp quyền GPS.',
        ),
        GrapMap(
          cameraRevision: cameraRevision,
          pickup: point,
          height: 320,
          onPick: (p) => setState(() {
            locationRevision++;
            point = p;
            busy = false;
            error = null;
            accuracy = null;
            address.clear();
          }),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: busy ? null : locate,
          icon: const Icon(Icons.my_location, size: 18),
          label: Text(
            busy ? 'Đang xác định vị trí…' : 'Sử dụng vị trí thiết bị',
          ),
        ),
        const SizedBox(height: 18),
        TextField(
          controller: address,
          maxLength: 500,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Địa chỉ / mô tả điểm đã chọn',
          ),
        ),
        if (accuracy != null)
          GrapNotice(
            accuracy! > 100
                ? 'GPS chưa chính xác. Hãy kiểm tra và chỉnh ghim trước khi xác nhận.'
                : 'Đã tìm được vị trí. Kiểm tra ghim và bổ sung hướng dẫn đón nếu cần.',
          ),
        if (error != null) GrapNotice(error!, error: true),
        const SizedBox(height: 18),
        FilledButton(
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
      ],
    ),
  );
}
