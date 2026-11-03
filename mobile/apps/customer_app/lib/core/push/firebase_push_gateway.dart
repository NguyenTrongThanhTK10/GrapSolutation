// The API stores FCM registration tokens; keep this API until the backend migrates to FIDs.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'push_models.dart';

@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Notification payloads are rendered by the OS. Never execute ride/payment commands here.
}

Future<PushGateway> initializeFirebasePush() async {
  if (kIsWeb ||
      (defaultTargetPlatform != TargetPlatform.android &&
          defaultTargetPlatform != TargetPlatform.iOS) ||
      !const bool.fromEnvironment('ENABLE_FIREBASE_PUSH', defaultValue: true)) {
    return const DisabledPushGateway();
  }
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessage);
    return FirebasePushGateway();
  } catch (_) {
    // Other app features remain available. The settings screen reports push as unavailable.
    return const DisabledPushGateway();
  }
}

class FirebasePushGateway implements PushGateway {
  final FirebaseMessaging messaging;

  FirebasePushGateway({FirebaseMessaging? messaging})
    : messaging = messaging ?? FirebaseMessaging.instance;
  @override
  bool get available => true;
  @override
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  @override
  Stream<String> get tokenChanges => messaging.onTokenRefresh;
  @override
  Stream<PushEvent> get messages => Stream<PushEvent>.multi((controller) {
    final foreground = FirebaseMessaging.onMessage.listen((m) {
      final value = PushMessage.parse(m.data);
      if (value != null) controller.add(PushEvent(value));
    });
    final opened = FirebaseMessaging.onMessageOpenedApp.listen((m) {
      final value = PushMessage.parse(m.data);
      if (value != null) controller.add(PushEvent(value, opened: true));
    });
    controller.onCancel = () async {
      await foreground.cancel();
      await opened.cancel();
    };
  });
  @override
  Future<PushMessage?> initialMessage() async {
    final message = await messaging.getInitialMessage();
    return message == null ? null : PushMessage.parse(message.data);
  }

  @override
  Future<String> permission({bool request = false}) async {
    final settings = request
        ? await messaging.requestPermission(
            alert: true,
            badge: true,
            sound: true,
          )
        : await messaging.getNotificationSettings();
    return switch (settings.authorizationStatus) {
      AuthorizationStatus.authorized ||
      AuthorizationStatus.provisional => 'authorized',
      AuthorizationStatus.denied => 'denied',
      _ => 'notDetermined',
    };
  }

  @override
  Future<String?> token() async {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // APNs registration can finish after the permission dialog closes.
      // Let token refresh/resume retry if APNs is still unavailable (e.g. offline).
      for (var attempt = 0; attempt < 10; attempt++) {
        if (await messaging.getAPNSToken() != null) {
          return messaging.getToken();
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      return null;
    }
    return messaging.getToken();
  }

  @override
  Future<void> deleteToken() async {
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await messaging.getAPNSToken() == null) {
      return;
    }
    await messaging.deleteToken();
  }

  @override
  Future<void> autoInit(bool enabled) => messaging.setAutoInitEnabled(enabled);
  @override
  Future<void> openSettings() =>
      const MethodChannel('grap/push').invokeMethod<void>('openSettings');
}
