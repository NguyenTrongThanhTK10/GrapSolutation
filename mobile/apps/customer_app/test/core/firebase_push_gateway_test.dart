import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_customer/core/push/firebase_push_gateway.dart';
import 'package:grap_customer/core/push/push_models.dart';

class FakeMessaging extends Fake implements FirebaseMessaging {
  final apnsResponses = <String?>[null];
  int apnsCalls = 0, tokenCalls = 0, deleteCalls = 0;

  @override
  Future<String?> getAPNSToken() async {
    apnsCalls++;
    return apnsResponses.length > 1
        ? apnsResponses.removeAt(0)
        : apnsResponses.single;
  }

  @override
  Future<String?> getToken({
    String? vapidKey,
    String? serviceWorkerScriptPath,
  }) async {
    tokenCalls++;
    return 'fcm-token';
  }

  @override
  Future<void> deleteToken() async {
    deleteCalls++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeMessaging messaging;
  late FirebasePushGateway gateway;

  setUp(() {
    messaging = FakeMessaging();
    gateway = FirebasePushGateway(messaging: messaging);
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test('registers the correct backend platform for iOS and Android', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(gateway.platform, 'ios');
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(gateway.platform, 'android');
  });

  test('unsupported desktop platforms leave push disabled', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    expect(await initializeFirebasePush(), isA<DisabledPushGateway>());
  });

  test('Android fetches FCM token without waiting for APNs', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(await gateway.token(), 'fcm-token');
    expect(messaging.apnsCalls, 0);
    expect(messaging.tokenCalls, 1);
    await gateway.deleteToken();
    expect(messaging.deleteCalls, 1);
  });

  testWidgets('iOS waits for APNs before requesting the FCM token', (
    tester,
  ) async {
    messaging.apnsResponses.add('apns-token');
    final token = gateway.token();
    await tester.pump();
    expect(messaging.tokenCalls, 0);
    await tester.pump(const Duration(milliseconds: 500));
    expect(await token, 'fcm-token');
    expect(messaging.apnsCalls, 2);
    expect(messaging.tokenCalls, 1);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('iOS without APNs returns after a bounded wait for later retry', (
    tester,
  ) async {
    final token = gateway.token();
    await tester.pump();
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    expect(await token, isNull);
    expect(messaging.apnsCalls, 10);
    expect(messaging.tokenCalls, 0);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  test('iOS logout before APNs registration skips token deletion', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await gateway.deleteToken();
    expect(messaging.deleteCalls, 0);
  });

  test('iOS logout deletes the FCM token once APNs is available', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    messaging.apnsResponses[0] = 'apns-token';
    await gateway.deleteToken();
    expect(messaging.deleteCalls, 1);
  });
}
