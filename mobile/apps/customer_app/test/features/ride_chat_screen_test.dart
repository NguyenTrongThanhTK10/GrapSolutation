import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/domain/ride_chat.dart';
import 'package:grap_customer/core/providers/ride_chat_providers.dart';
import 'package:grap_customer/features/chat/presentation/ride_chat_screen.dart';

class Session extends SessionController {
  @override
  Future<GrapUser?> build() async =>
      const GrapUser(id: 'a', name: 'Khách', role: 'Customer');
  void signOut() => state = const AsyncData(null);
}

RideMessage message(
  int sequence, {
  String sender = 'peer',
  String assignment = 'assignment',
}) => RideMessage(
  id: 'message-$assignment-$sequence',
  assignmentId: assignment,
  senderId: sender,
  body: 'Tin nhắn $sequence',
  sequence: sequence,
  createdAt: DateTime.utc(2026, 11, 16, 3, sequence),
);

class ChatFake implements RideChatRepository {
  final events = StreamController<void>.broadcast();
  final messages = <RideMessage>[message(1)];
  final keys = <String>[];
  bool canSend = true, failSend = false;
  Failure? failure;
  String assignment = 'assignment';
  int loads = 0;
  Completer<RideChatPage>? delayed;

  @override
  Future<RideChatPage> load(
    String rideId, {
    int? beforeSequence,
    int? afterSequence,
  }) async {
    loads++;
    if (delayed != null) return delayed!.future;
    if (failure != null) throw failure!;
    return RideChatPage(
      assignmentId: assignment,
      rideCode: 'GR123',
      peerName: 'Nguyễn Văn Hùng',
      canSend: canSend,
      items: messages
          .where(
            (m) =>
                m.assignmentId == assignment &&
                (afterSequence == null || m.sequence > afterSequence) &&
                (beforeSequence == null || m.sequence < beforeSequence),
          )
          .toList(),
    );
  }

  @override
  Future<RideMessage> send(
    String rideId,
    String assignmentId,
    String body, {
    required String idempotencyKey,
  }) async {
    keys.add(idempotencyKey);
    if (failSend) {
      failSend = false;
      throw const Failure('NETWORK_ERROR', 'Mất kết nối.');
    }
    final sent = RideMessage(
      id: 'sent',
      assignmentId: assignmentId,
      senderId: 'a',
      body: body,
      sequence: messages.length + 1,
      createdAt: DateTime.now(),
    );
    messages.add(sent);
    return sent;
  }

  @override
  Stream<void> updates() => events.stream;
}

Future<ProviderContainer> showChat(
  WidgetTester tester,
  ChatFake repository,
) async {
  final container = ProviderContainer(
    overrides: [
      sessionProvider.overrideWith(Session.new),
      rideChatRepositoryProvider.overrideWithValue(repository),
    ],
  );
  await container.read(sessionProvider.future);
  addTearDown(() async {
    container.dispose();
    await repository.events.close();
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: RideChatScreen(rideId: 'ride')),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('renders messages, quick replies and disables blank send', (
    tester,
  ) async {
    final repository = ChatFake();
    await showChat(tester, repository);
    expect(find.text('Nguyễn Văn Hùng'), findsOneWidget);
    expect(find.text('Tin nhắn 1'), findsOneWidget);
    final send = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Gửi tin nhắn',
    );
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    await tester.tap(find.text('Tôi đang ở điểm đón.'));
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(find.text('Tôi đang ở điểm đón.'), findsNWidgets(2));
    expect(repository.keys, hasLength(1));
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });

  testWidgets(
    'network retry uses the same key and realtime reload does not duplicate messages',
    (tester) async {
      final repository = ChatFake()..failSend = true;
      await showChat(tester, repository);
      await tester.enterText(find.byType(TextField), 'Chờ tôi nhé');
      await tester.pump();
      await tester.tap(find.byTooltip('Gửi tin nhắn'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Mất kết nối.'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, true);
      await tester.tap(find.byTooltip('Gửi lại'));
      await tester.pumpAndSettle();
      expect(repository.keys, hasLength(2));
      expect(repository.keys.first, repository.keys.last);
      repository.events.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Chờ tôi nhé'), findsOneWidget);
      expect(find.text('Tin nhắn 1'), findsOneWidget);
    },
  );

  testWidgets('completed ride preserves conversation and removes composer', (
    tester,
  ) async {
    await showChat(tester, ChatFake()..canSend = false);
    expect(find.text('Tin nhắn 1'), findsOneWidget);
    expect(find.textContaining('Chuyến đã kết thúc.'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('revoked assignment clears old messages and composer', (
    tester,
  ) async {
    final repository = ChatFake();
    await showChat(tester, repository);
    repository.failure = const Failure(
      'RESOURCE_NOT_FOUND',
      'Không tìm thấy dữ liệu.',
    );
    repository.events.add(null);
    await tester.pumpAndSettle();
    expect(find.text('Tin nhắn 1'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Không tìm thấy dữ liệu.'), findsOneWidget);
  });

  testWidgets(
    'replacement assignment clears drafts before opening the new thread',
    (tester) async {
      final repository = ChatFake();
      await showChat(tester, repository);
      await tester.enterText(find.byType(TextField), 'Bản nháp cho tài xế cũ');
      repository.assignment = 'replacement';
      repository.messages.add(message(1, assignment: 'replacement'));
      repository.events.add(null);
      await tester.pumpAndSettle();
      expect(find.text('Tin nhắn 1'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(repository.keys, isEmpty);
    },
  );

  testWidgets('background pauses subscription and resume reloads messages', (
    tester,
  ) async {
    final repository = ChatFake();
    await showChat(tester, repository);
    expect(repository.events.hasListener, true);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pumpAndSettle();
    expect(repository.events.hasListener, false);
    final reads = repository.loads;
    repository.messages.add(message(2));
    repository.events.add(null);
    await tester.pumpAndSettle();
    expect(repository.loads, reads);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(repository.events.hasListener, true);
    expect(find.text('Tin nhắn 2'), findsOneWidget);
  });

  testWidgets('late response after sign out cannot repopulate chat', (
    tester,
  ) async {
    final repository = ChatFake();
    final container = await showChat(tester, repository);
    repository.delayed = Completer<RideChatPage>();
    repository.events.add(null);
    await tester.pump();
    (container.read(sessionProvider.notifier) as Session).signOut();
    await tester.pumpAndSettle();
    repository.delayed!.complete(
      RideChatPage(
        assignmentId: 'assignment',
        rideCode: 'GR123',
        peerName: 'Tài xế',
        canSend: true,
        items: [message(99)],
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tin nhắn 99'), findsNothing);
    expect(find.text('Tin nhắn 1'), findsNothing);
    expect(
      find.text('Vui lòng đăng nhập lại để xem tin nhắn.'),
      findsOneWidget,
    );
  });
  testWidgets(
    'send acknowledgement does not skip concurrent incoming messages',
    (tester) async {
      final repository = ChatFake();
      await showChat(tester, repository);
      repository.messages.add(message(2));
      await tester.enterText(find.byType(TextField), 'Tin của tôi');
      await tester.pump();
      await tester.tap(find.byTooltip('Gửi tin nhắn'));
      await tester.pumpAndSettle();
      expect(find.text('Tin nhắn 2'), findsOneWidget);
      expect(find.text('Tin của tôi'), findsOneWidget);
    },
  );

  testWidgets('composer fits a narrow viewport with the keyboard open', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = const FakeViewPadding(bottom: 220);
    addTearDown(tester.view.reset);
    await showChat(tester, ChatFake());
    await tester.enterText(
      find.byType(TextField),
      List.filled(60, 'Tin dài ').join(),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byTooltip('Gửi tin nhắn'), findsOneWidget);
  });
}
