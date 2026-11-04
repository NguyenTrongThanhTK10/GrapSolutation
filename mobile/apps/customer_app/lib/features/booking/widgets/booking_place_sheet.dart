import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';
import 'package:grap_customer/features/journey/presentation/journey_screens.dart';
import 'package:grap_customer/features/places/presentation/place_picker_screen.dart';

import 'place_search.dart';

class BookingPlaceSheet extends ConsumerStatefulWidget {
  final String title;
  final Place? selected;
  final List<Place> places, recent;
  final bool demo;
  const BookingPlaceSheet({
    super.key,
    required this.title,
    required this.places,
    this.selected,
    this.recent = const [],
    this.demo = false,
  });
  @override
  ConsumerState<BookingPlaceSheet> createState() => _PlaceSearchState();
}

class _PlaceSearchState extends ConsumerState<BookingPlaceSheet> {
  final search = TextEditingController();
  Timer? debounce;
  int revision = 0;
  bool searching = false, saving = true;
  String? error, savedError;
  List<Place> remote = [];
  List<SavedAddress> saved = [];
  String? actor;
  bool waitingForSession = false;

  @override
  void initState() {
    super.initState();
    final session = ref.read(sessionProvider);
    actor = session.value?.id;
    waitingForSession = actor == null && session.isLoading;
    if (actor != null) unawaited(loadSaved());
  }

  bool get validActor =>
      actor != null && actor == ref.read(sessionProvider).value?.id;
  Future<void> loadSaved() async {
    try {
      final result = await ref.read(journeyRepositoryProvider).addresses();
      if (mounted && validActor) {
        setState(() {
          saved = result;
          savedError = null;
        });
      }
    } catch (_) {
      if (mounted && validActor) {
        setState(() => savedError = 'Chưa tải được địa chỉ đã lưu.');
      }
    } finally {
      if (mounted && validActor) setState(() => saving = false);
    }
  }

  void changed(String value) {
    debounce?.cancel();
    final current = ++revision;
    setState(() {
      remote = [];
      error = null;
      searching = placeSearchKey(value).length >= 2;
    });
    if (searching) {
      debounce = Timer(
        const Duration(milliseconds: 300),
        () => lookup(value.trim(), current),
      );
    }
  }

  Future<void> lookup(String value, int current) async {
    try {
      final result = await ref.read(rideRepositoryProvider).places(value);
      if (mounted && validActor && revision == current) {
        setState(() => remote = result);
      }
    } catch (_) {
      if (mounted && validActor && revision == current) {
        setState(
          () => error =
              'Chưa tìm được địa điểm. Thử lại hoặc chọn ghim trên bản đồ.',
        );
      }
    } finally {
      if (mounted && validActor && revision == current) {
        setState(() => searching = false);
      }
    }
  }

  Future<void> open(Widget screen) async {
    final result = await Navigator.of(context)
        .push<Place>(MaterialPageRoute(builder: (_) => screen));
    if (mounted && validActor && result != null) Navigator.pop(context, result);
  }

  @override
  void dispose() {
    revision++;
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      if (waitingForSession && next.value != null) {
        waitingForSession = false;
        actor = next.value!.id;
        setState(() {});
        unawaited(loadSaved());
      } else if (actor != next.value?.id) {
        waitingForSession = false;
        search.clear();
        revision++;
        debounce?.cancel();
        setState(() {
          saved = [];
          remote = [];
          searching = false;
        });
      }
    });
    final query = search.text;
    final known = <String>{};
    final savedRows = saved
        .where(
          (s) =>
              placeMatches('${s.label} ${s.point.address}', query) &&
              known.add(placeKey(s.point)),
        )
        .toList();
    final recent = uniquePlaces(widget.recent)
        .where((p) => placeMatches(p.address, query) && known.add(placeKey(p)))
        .take(5)
        .toList();
    final suggestions = uniquePlaces([
      ...remote,
      ...widget.places.where((p) => placeMatches(p.address, query)),
    ]).where((p) => known.add(placeKey(p))).take(12).toList();
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: .85,
        minChildSize: .45,
        maxChildSize: .95,
        builder: (context, scrollController) => SafeArea(
          top: false,
          child: ListView(
            controller: scrollController,
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              Text(
                widget.title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  color: grapInk,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: search,
                autofocus: true,
                maxLength: 150,
                textInputAction: TextInputAction.search,
                onChanged: changed,
                onSubmitted: (value) {
                  debounce?.cancel();
                  if (value.trim().length >= 2) {
                    setState(() => searching = true);
                    unawaited(lookup(value.trim(), ++revision));
                  }
                },
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'Tìm tên đường, tòa nhà, địa điểm…',
                  labelText: 'Tìm địa điểm',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: search.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Xóa từ khóa',
                          onPressed: () {
                            search.clear();
                            changed('');
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
              const SizedBox(height: 12),
              if (!validActor)
                const Text('Đang xác minh tài khoản…')
              else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (query.isEmpty)
                      ActionChip(
                        avatar: const Icon(Icons.my_location, size: 18),
                        label: const Text('Vị trí hiện tại'),
                        onPressed: () => open(
                          PlacePickerScreen(
                            title: widget.title,
                            locateOnOpen: true,
                          ),
                        ),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.map_outlined, size: 18),
                      label: const Text('Chọn trên bản đồ'),
                      onPressed: () => open(
                        PlacePickerScreen(
                          initial: widget.selected,
                          title: widget.title,
                        ),
                      ),
                    ),
                    if (query.isEmpty)
                      ActionChip(
                        avatar: const Icon(Icons.bookmark_outline, size: 18),
                        label: const Text('Địa chỉ đã lưu'),
                        onPressed: () =>
                            open(const SavedPlacesScreen(select: true)),
                      ),
                  ],
                ),
                if (searching)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: LinearProgressIndicator(
                      semanticsLabel: 'Đang tìm địa điểm',
                    ),
                  ),
                if (error != null) ...[
                  GrapNotice(error!, error: true),
                  TextButton.icon(
                    onPressed: () => changed(search.text),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử tìm lại'),
                  ),
                ],
                if (savedRows.isNotEmpty) ...[
                  heading('Địa chỉ của bạn'),
                  for (final s in savedRows)
                    tile(s.point, Icons.bookmark_rounded, title: s.label),
                ],
                if (recent.isNotEmpty) ...[
                  heading('Đến gần đây'),
                  for (final p in recent) tile(p, Icons.history),
                ],
                if (suggestions.isNotEmpty) ...[
                  heading(
                    query.isEmpty ? 'Địa điểm gợi ý' : 'Kết quả tìm kiếm',
                  ),
                  for (final p in suggestions)
                    tile(p, Icons.location_on_outlined),
                ],
                if (saving)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text(
                      'Đang tải địa chỉ của bạn…',
                      style: TextStyle(color: grapMuted),
                    ),
                  ),
                if (savedError != null && query.isEmpty)
                  TextButton(
                    onPressed: () {
                      setState(() => saving = true);
                      unawaited(loadSaved());
                    },
                    child: Text('$savedError Thử lại'),
                  ),
                if (!searching &&
                    query.isNotEmpty &&
                    savedRows.isEmpty &&
                    recent.isEmpty &&
                    suggestions.isEmpty)
                  const GrapNotice(
                    'Không có địa điểm phù hợp. Hãy đổi từ khóa hoặc đặt ghim trên bản đồ.',
                  ),
                if (widget.demo)
                  const GrapNotice(
                    'Đang dùng địa điểm mẫu. Bạn vẫn có thể tìm không dấu; vị trí ngoài tuyến mẫu chưa có báo giá demo.',
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget heading(String title) => Padding(
    padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
    child: Text(
      title,
      style: const TextStyle(
        color: grapMuted,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  Widget tile(Place p, IconData icon, {String? title}) => ListTile(
    leading: Icon(icon, color: grapGreen),
    title: Text(
      title ?? p.address,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    ),
    subtitle: title == null
        ? null
        : Text(p.address, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing:
        widget.selected != null && placeKey(widget.selected!) == placeKey(p)
        ? const Icon(Icons.check_circle, color: grapGreen)
        : const Icon(Icons.north_west, size: 18),
    onTap: () => Navigator.pop(context, p),
  );
}
