import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';
import 'package:grap_customer/features/journey/presentation/journey_screens.dart';
import 'package:grap_customer/features/privacy/presentation/privacy_screens.dart';

class Session extends SessionController {
  @override
  Future<GrapUser?> build() async =>
      const GrapUser(id: 'a', name: 'Khách', role: 'Customer');
}

const point = Place(
  id: 'p',
  address: 'Quận 1',
  latitude: 10.77,
  longitude: 106.69,
);
RideSnapshot ride(String id) => RideSnapshot(
  id: id,
  code: 'GR-$id',
  status: 'COMPLETED',
  service: 'BIKE',
  version: 1,
  pickup: point,
  dropoff: point,
  fare: const Fare(payable: 20000, gross: 20000, commission: 3000),
  createdAt: DateTime.utc(2026, 11, 3),
);

class JourneyFake implements JourneyRepository {
  final calls = <String?>[];
  int consentSaves = 0;
  bool canReview = false;
  String? savedLabel;
  bool conflict = false;
  int addressReads = 0;
  @override
  Future<List<SavedAddress>> addresses() async {
    addressReads++;
    return const [SavedAddress('home', 'Nhà', point, '', 1)];
  }

  @override
  Future<void> saveAddress(
    String label,
    Place point,
    String note, {
    SavedAddress? current,
  }) async {
    if (conflict) {
      throw const Failure('VERSION_CONFLICT', 'Địa chỉ đã thay đổi');
    }
    savedLabel = label;
  }

  @override
  Future<RidePage> history({
    String? status,
    DateTime? from,
    DateTime? to,
    String? cursor,
  }) async {
    calls.add(cursor);
    return cursor == null
        ? RidePage([ride('1')], 'next')
        : RidePage([ride('2')], null);
  }

  @override
  Future<RideReceipt> receipt(String id) async =>
      RideReceipt(ride(id), [], 4, 'Ổn', canReview, DateTime.utc(2026, 11, 4));
  @override
  Future<TrustedContacts> contacts() async => const TrustedContacts([]);
  @override
  Future<void> saveContact(
    String name,
    String phone,
    bool consent, {
    TrustedPerson? current,
  }) async {
    if (consent) consentSaves++;
  }

  @override
  Future<List<DeletionStatus>> deletionRequests() async => const [
    DeletionStatus(
      'd',
      'BLOCKED_OBLIGATIONS',
      'Cần xóa tài khoản',
      'ticket',
      null,
      1,
      ['ACTIVE_RIDE'],
    ),
  ];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget app(JourneyFake repo, Widget child) => ProviderScope(
  overrides: [
    journeyRepositoryProvider.overrideWithValue(repo),
    sessionProvider.overrideWith(Session.new),
  ],
  child: MaterialApp(theme: grapTheme(), home: child),
);

class ReviewFake implements RideRepository {
  int? stars;
  String? comment;
  @override
  Future<void> rate(RideSnapshot ride, int stars, String comment) async {
    this.stars = stars;
    this.comment = comment;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a version conflict locks stale edits and offers a fresh list', (
    t,
  ) async {
    final repo = JourneyFake()..conflict = true;
    await t.pumpWidget(app(repo, const SavedPlacesScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Sửa'));
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(FilledButton, 'Lưu địa chỉ'));
    await t.pumpAndSettle();
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Lưu địa chỉ'),
          )
          .onPressed,
      isNull,
    );
    await t.ensureVisible(find.text('Đóng và tải bản mới'));
    await t.tap(find.text('Đóng và tải bản mới'));
    await t.pumpAndSettle();
    expect(repo.addressReads, greaterThan(1));
  });

  testWidgets(
    'review submits selected stars and comment to the ride repository',
    (t) async {
      final repo = JourneyFake()..canReview = true;
      final reviews = ReviewFake();
      await t.pumpWidget(
        ProviderScope(
          overrides: [
            journeyRepositoryProvider.overrideWithValue(repo),
            rideRepositoryProvider.overrideWithValue(reviews),
            sessionProvider.overrideWith(Session.new),
          ],
          child: MaterialApp(
            theme: grapTheme(),
            home: const RideReceiptScreen(rideId: '1'),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(find.text('Sửa đánh giá'), 300);
      await t.tap(find.text('Sửa đánh giá'));
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('3 sao'));
      await t.enterText(find.byType(TextField), 'Tài xế thân thiện');
      await t.tap(find.text('Gửi đánh giá'));
      await t.pumpAndSettle();
      expect(reviews.stars, 3);
      expect(reviews.comment, 'Tài xế thân thiện');
    },
  );
  testWidgets(
    'saved address can be edited while retaining the selected coordinate',
    (t) async {
      final repo = JourneyFake();
      await t.pumpWidget(app(repo, const SavedPlacesScreen()));
      await t.pumpAndSettle();
      await t.tap(find.text('Sửa'));
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField).first, 'Công ty');
      await t.tap(find.widgetWithText(FilledButton, 'Lưu địa chỉ'));
      await t.pumpAndSettle();
      expect(repo.savedLabel, 'Công ty');
    },
  );
  testWidgets('history loads the next page without replacing previous rides', (
    t,
  ) async {
    final repo = JourneyFake();
    await t.pumpWidget(
      app(
        repo,
        const Scaffold(body: SingleChildScrollView(child: GrapHistoryPanel())),
      ),
    );
    await t.pumpAndSettle();
    expect(
      t
          .widgetList<RideHistoryTile>(find.byType(RideHistoryTile))
          .map((w) => w.ride.id),
      ['1'],
    );
    await t.ensureVisible(find.text('Tải thêm hành trình'));
    await t.tap(find.text('Tải thêm hành trình'));
    await t.pumpAndSettle();
    expect(repo.calls.where((e) => e == 'next'), hasLength(1));
    expect(
      t
          .widgetList<RideHistoryTile>(find.byType(RideHistoryTile))
          .map((w) => w.ride.id),
      ['1', '2'],
    );
    expect(find.text('Tải thêm hành trình'), findsNothing);
  });
  testWidgets(
    'expired review has no submit action and receipt keeps payment separate',
    (t) async {
      await t.pumpWidget(
        app(JourneyFake(), const RideReceiptScreen(rideId: '1')),
      );
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.textContaining('Đã hết thời hạn 24 giờ'),
        300,
      );
      expect(find.textContaining('Đã hết thời hạn 24 giờ'), findsOneWidget);
      expect(find.text('Sửa đánh giá'), findsNothing);
      expect(find.text('Gửi đánh giá'), findsNothing);
    },
  );
  testWidgets('saving a trusted contact requires explicit consent', (t) async {
    final repo = JourneyFake();
    await t.pumpWidget(app(repo, const SafetyContactsScreen()));
    await t.pumpAndSettle();
    await t.tap(find.text('Thêm liên hệ'));
    await t.pumpAndSettle();
    expect(
      t
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Lưu liên hệ'),
          )
          .onPressed,
      isNull,
    );
    await t.enterText(find.byType(TextField).at(0), 'Người thân');
    await t.enterText(find.byType(TextField).at(1), '0912345678');
    await t.tap(find.byType(CheckboxListTile));
    await t.pump();
    await t.tap(find.text('Lưu liên hệ'));
    await t.pumpAndSettle();
    expect(repo.consentSaves, 1);
  });
  testWidgets(
    'deletion blockers appear and creating a duplicate request is unavailable',
    (t) async {
      await t.pumpWidget(app(JourneyFake(), const DeletionRequestScreen()));
      await t.pumpAndSettle();
      expect(find.text('Có chuyến đang diễn ra'), findsOneWidget);
      expect(find.text('Gửi yêu cầu kiểm tra xóa tài khoản'), findsNothing);
      expect(find.textContaining('dữ liệu chưa bị xóa'), findsOneWidget);
    },
  );
}
