import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/widgets/app_widgets.dart';
import 'package:grap_driver/app/grap_app.dart';
import 'package:grap_driver/features/account/presentation/account_screens.dart';

class SignedIn extends SessionController {
  @override
  Future<GrapUser?> build() async =>
      const GrapUser(id: 'customer', name: 'Ngọc Hà', role: 'Customer');
}

class AccountFake implements AccountRepository {
  String? savedName, readId;
  final records = <SupportTicket>[];
  final messages = <SupportMessage>[];
  final p = const Profile(
    user: GrapUser(id: 'customer', name: 'Ngọc Hà', role: 'Customer'),
    phone: '+84 ••• 000',
    version: 1,
  );
  @override
  Future<Profile> profile() async => p;
  @override
  Future<Profile> updateProfile(
    Profile current,
    String name,
    String? email,
  ) async {
    savedName = name;
    return Profile(
      user: GrapUser(id: 'customer', name: name, role: 'Customer'),
      phone: p.phone,
      email: email,
      version: 2,
    );
  }

  @override
  Future<List<SupportTicket>> tickets() async => records;
  @override
  Future<void> createTicket(
    String subject,
    String category,
    String message, {
    String? rideId,
  }) async {
    records.add(
      SupportTicket(
        id: 'ticket',
        subject: subject,
        status: 'OPEN',
        category: category,
        priority: 'NORMAL',
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<TicketDetail> ticket(String id) async => TicketDetail(
    SupportTicket(
      id: id,
      subject: 'Cần hỗ trợ hành trình',
      status: 'OPEN',
      category: 'RIDE',
      priority: 'NORMAL',
      createdAt: DateTime.now(),
    ),
    messages,
  );
  @override
  Future<void> reply(String ticketId, String message) async {
    messages.add(
      SupportMessage(
        id: 'message',
        authorId: 'customer',
        body: message,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<List<AppNotification>> notifications() async => [
    AppNotification(
      id: 'notice',
      title: 'Chuyến đã hoàn tất',
      body: 'Đã ghi nhận chuyến',
      createdAt: DateTime.now(),
      read: readId != null,
    ),
  ];
  @override
  Future<void> markRead(String id) async {
    readId = id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError();
}

Widget app(Widget home, AccountFake repository) => ProviderScope(
  overrides: [
    sessionProvider.overrideWith(SignedIn.new),
    accountRepositoryProvider.overrideWithValue(repository),
  ],
  child: GrapMaterialApp(title: 'Test', home: home),
);
void main() {
  testWidgets('profile rejects malformed email and saves valid edits', (
    tester,
  ) async {
    final repository = AccountFake();
    await tester.pumpWidget(
      app(ProfileEditor(profile: repository.p), repository),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Hà Nguyễn');
    await tester.enterText(find.byType(TextFormField).at(1), 'invalid-email');
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pump();
    expect(find.text('Email chưa hợp lệ'), findsOneWidget);
    expect(repository.savedName, isNull);
    await tester.enterText(find.byType(TextFormField).at(1), 'ha@example.com');
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(repository.savedName, 'Hà Nguyễn');
  });
  testWidgets('support ticket form submits and returns to refreshed inbox', (
    tester,
  ) async {
    final repository = AccountFake();
    await tester.pumpWidget(app(const SupportInboxScreen(), repository));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tạo yêu cầu'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Hỗ trợ thanh toán');
    await tester.enterText(
      find.byType(TextField).at(1),
      'Tôi đã thanh toán tiền mặt, cần kiểm tra biên nhận.',
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.widgetWithText(FilledButton, 'Gửi yêu cầu'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi yêu cầu'));
    await tester.pumpAndSettle();
    expect(repository.records, hasLength(1));
    expect(find.text('Hỗ trợ thanh toán'), findsOneWidget);
  });
  testWidgets('ticket screen sends reply and reloads conversation', (
    tester,
  ) async {
    final repository = AccountFake();
    await tester.pumpWidget(
      app(const TicketScreen(ticketId: 'ticket'), repository),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'Thông tin bổ sung cho yêu cầu',
    );
    await tester.ensureVisible(find.text('Gửi phản hồi'));
    await tester.tap(find.text('Gửi phản hồi'));
    await tester.pumpAndSettle();
    expect(repository.messages, hasLength(1));
    expect(find.text('Thông tin bổ sung cho yêu cầu'), findsOneWidget);
  });
  testWidgets('notification is marked read by its server id', (tester) async {
    final repository = AccountFake();
    await tester.pumpWidget(app(const NotificationsScreen(), repository));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.notifications_active_outlined), findsOneWidget);
    await tester.tap(find.text('Chuyến đã hoàn tất'));
    await tester.pumpAndSettle();
    expect(repository.readId, 'notice');
    expect(find.byIcon(Icons.notifications_active_outlined), findsNothing);
  });
  testWidgets('expiry countdown disables acceptance at the server deadline', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: ExpiryBuilder(
            deadline: DateTime.now().toUtc().subtract(
              const Duration(seconds: 1),
            ),
            builder: (seconds) => FilledButton(
              onPressed: seconds == 0 ? null : () {},
              child: Text('$seconds'),
            ),
          ),
        ),
        AccountFake(),
      ),
    );
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
