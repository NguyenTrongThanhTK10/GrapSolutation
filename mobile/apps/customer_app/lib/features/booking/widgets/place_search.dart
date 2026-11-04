import 'package:grap_customer/core/domain/models.dart';

String placeSearchKey(String text) {
  var result = text.toLowerCase();
  for (final entry in const {
    'a': 'àáạảãâầấậẩẫăằắặẳẵ',
    'e': 'èéẹẻẽêềếệểễ',
    'i': 'ìíịỉĩ',
    'o': 'òóọỏõôồốộổỗơờớợởỡ',
    'u': 'ùúụủũưừứựửữ',
    'y': 'ỳýỵỷỹ',
    'd': 'đ',
  }.entries) {
    result = result.replaceAll(RegExp('[${entry.value}]'), entry.key);
  }
  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
}

bool placeMatches(String text, String query) =>
    placeSearchKey(query)
        .split(' ')
        .where((word) => word.isNotEmpty)
        .every(placeSearchKey(text).contains);
String placeKey(Place place) =>
    '${place.latitude.toStringAsFixed(6)},${place.longitude.toStringAsFixed(6)}';
List<Place> uniquePlaces(Iterable<Place> places) {
  final known = <String>{};
  return places.where((p) => known.add(placeKey(p))).toList();
}
