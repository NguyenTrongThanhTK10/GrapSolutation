import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:grap_customer/core/data/ride_route_repository.dart';

void main() {
  final geometry = {
    'type': 'LineString',
    'coordinates': [
      [106.69, 10.77],
      [106.71, 10.78],
      [106.72, 10.79],
    ],
  };
  test('GeoJSON object and persisted JSON preserve every bend and coordinate order', () {
    for (final input in [geometry, jsonEncode(geometry)]) {
      final points = routeGeometryFromJson(input);
      expect(points, hasLength(3));
      expect(points[1].latitude, 10.78);
      expect(points[1].longitude, 106.71);
    }
  });
  test(
    'absent or invalid geometry is unavailable, without inventing a route',
    () {
      for (final input in [
        null,
        'broken',
        {},
        {
          'type': 'Point',
          'coordinates': [106, 10],
        },
        {
          'type': 'LineString',
          'coordinates': [
            [106, 10],
          ],
        },
        {
          'type': 'LineString',
          'coordinates': [
            [106, 10],
            [106, 91],
          ],
        },
        {
          'type': 'LineString',
          'coordinates': [
            [106, 10],
            ['bad', 10],
          ],
        },
      ]) {
        expect(routeGeometryFromJson(input), isEmpty);
      }
    },
  );
}
