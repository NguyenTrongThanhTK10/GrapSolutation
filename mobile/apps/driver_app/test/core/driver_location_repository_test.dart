import 'package:flutter_test/flutter_test.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/data/repositories.dart';

import 'api_client_test.dart' show Adapter, client, jsonResponse;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final result in [
    {'accepted': 0, 'latestSequence': 1},
    {'accepted': 1, 'latestSequence': 5},
    {'accepted': 1, 'latestSequence': 3},
  ]) {
    test(
      'GPS confirmation checks accepted samples and latest sequence: $result',
      () async {
        final api = client(Adapter((_, _) async => jsonResponse(result)));
        final position = PositionEvidence(
          latitude: 10.77,
          longitude: 106.69,
          accuracy: 12,
          recordedAt: DateTime.now(),
          sequence: 3,
        );
        final request = ApiDriverRepository(api).location(position);
        if (result['accepted'] == 1 && result['latestSequence'] == 3) {
          await request;
        } else {
          await expectLater(
            request,
            throwsA(
              isA<Failure>().having((e) => e.code, 'code', 'GPS_NOT_CONFIRMED'),
            ),
          );
        }
      },
    );
  }
}
