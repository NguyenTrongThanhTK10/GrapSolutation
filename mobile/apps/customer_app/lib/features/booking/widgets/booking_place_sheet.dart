import 'package:flutter/material.dart';
import 'package:grap_customer/core/domain/models.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';
import 'package:grap_customer/features/journey/presentation/journey_screens.dart';
import 'package:grap_customer/features/places/presentation/place_picker_screen.dart';

class BookingPlaceSheet extends StatelessWidget {
  final String title;
  final Place? selected;
  final List<Place> places;

  const BookingPlaceSheet({
    super.key,
    required this.title,
    required this.places,
    this.selected,
  });

  Future<void> _open(BuildContext context, Widget screen) async {
    final place = await Navigator.of(context)
        .push<Place>(MaterialPageRoute(builder: (_) => screen));
    if (context.mounted && place != null) Navigator.pop(context, place);
  }

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .65,
    minChildSize: .4,
    maxChildSize: .9,
    builder: (context, scrollController) => SafeArea(
      top: false,
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: grapInk,
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.map_outlined, color: grapGreen),
            title: const Text('Chọn trên bản đồ'),
            subtitle: const Text('Đặt ghim hoặc dùng vị trí hiện tại'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(
              context,
              PlacePickerScreen(initial: selected, title: title),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.bookmark_outline, color: grapGreen),
            title: const Text('Địa chỉ đã lưu'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _open(context, const SavedPlacesScreen(select: true)),
          ),
          if (places.isNotEmpty) ...[
            const Divider(),
            const Text(
              'Địa điểm gợi ý',
              style: TextStyle(fontSize: 14, color: grapMuted),
            ),
            const SizedBox(height: 8),
            for (final place in places)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined),
                title: Text(place.address),
                trailing: selected?.id == place.id
                    ? const Icon(Icons.check_circle, color: grapGreen)
                    : null,
                onTap: () => Navigator.pop(context, place),
              ),
          ],
        ],
      ),
    ),
  );
}
