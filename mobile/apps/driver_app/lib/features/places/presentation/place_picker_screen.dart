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
  @override
  void dispose() {
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
          pickup: point,
          height: 320,
          onPick: (p) => setState(() => point = p),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: busy
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    final p = await ref.read(locationProvider).current();
                    if (mounted) {
                      setState(
                        () => point = Place(
                          id: 'manual',
                          address: address.text,
                          latitude: p.latitude,
                          longitude: p.longitude,
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) setState(() => error = e.toString());
                  } finally {
                    if (mounted) setState(() => busy = false);
                  }
                },
          icon: const Icon(Icons.my_location, size: 18),
          label: const Text('Sử dụng vị trí thiết bị'),
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
