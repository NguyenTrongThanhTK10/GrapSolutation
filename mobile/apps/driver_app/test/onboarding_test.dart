import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/app/grap_app.dart';
import 'package:grap_driver/features/onboarding/onboarding_controller.dart';
import 'package:grap_driver/features/onboarding/onboarding_screen.dart';

class SignedIn extends SessionController {
  @override
  Future<GrapUser?> build() async =>
      const GrapUser(id: 'driver', name: 'Tài xế', role: 'Driver');
}

class OnboardingFake implements OnboardingRepository {
  DriverApplication current = const DriverApplication(
    id: 'driver',
    status: 'DRAFT',
    service: 'BIKE',
    vehicle: 'Honda Vision',
    plate: '59-X1 12345',
    color: 'Trắng',
    version: 1,
  );
  final items = <DriverDocument>[];
  static const types = [
    'IDENTITY',
    'DRIVING_LICENSE',
    'VEHICLE_REGISTRATION',
    'INSURANCE',
  ];
  int? submittedVersion;
  @override
  Future<DriverApplication> application() async => current;
  @override
  Future<DocumentBundle> documents() async => DocumentBundle(types, items);
  @override
  Future<bool> uploadEnabled() async => true;
  @override
  Future<DriverApplication> save(
    DriverApplication original,
    String service,
    String vehicle,
    String plate,
    String color,
  ) async {
    current = DriverApplication(
      id: 'driver',
      status: 'DRAFT',
      service: service,
      vehicle: vehicle,
      plate: plate,
      color: color,
      version: original.version + 1,
    );
    return current;
  }

  @override
  Future<void> uploadDocument(
    String type,
    List<int> bytes,
    String contentType,
    DateTime expiresAt,
  ) async {
    items.add(
      DriverDocument(
        id: type,
        type: type,
        status: 'PENDING_REVIEW',
        version: 1,
        expiresAt: expiresAt,
      ),
    );
    current = DriverApplication(
      id: current.id,
      status: current.status,
      service: current.service,
      vehicle: current.vehicle,
      plate: current.plate,
      color: current.color,
      version: current.version + 1,
    );
  }

  @override
  Future<void> submit(int expectedVersion) async {
    submittedVersion = expectedVersion;
    current = DriverApplication(
      id: current.id,
      status: 'PENDING_REVIEW',
      service: current.service,
      vehicle: current.vehicle,
      plate: current.plate,
      color: current.color,
      version: current.version + 1,
    );
  }
}

void main() {
  testWidgets(
    'native onboarding saves vehicle and requires all documents before submission',
    (tester) async {
      final repository = OnboardingFake();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sessionProvider.overrideWith(SignedIn.new),
            onboardingRepositoryProvider.overrideWithValue(repository),
          ],
          child: const GrapMaterialApp(title: 'Test', home: OnboardingScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Lưu thông tin xe'));
      await tester.tap(find.text('Lưu thông tin xe'));
      await tester.pumpAndSettle();
      expect(repository.current.version, 2);
      final submit = find.widgetWithText(FilledButton, 'Gửi hồ sơ xét duyệt');
      await tester.ensureVisible(submit);
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(OnboardingScreen)),
      );
      for (final type in OnboardingFake.types) {
        await container
            .read(onboardingControllerProvider.notifier)
            .upload(
              type,
              [137, 80, 78, 71],
              'image/png',
              DateTime.now().add(const Duration(days: 365)),
            );
      }
      await tester.pumpAndSettle();
      await tester.ensureVisible(submit);
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(repository.submittedVersion, 6);
      expect(
        container.read(onboardingControllerProvider).value!.application.status,
        'PENDING_REVIEW',
      );
      await tester.drag(find.byType(ListView), const Offset(0, 2200));
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ đang chờ duyệt'), findsOneWidget);
      expect(find.text('Lưu thông tin xe'), findsNothing);
    },
  );
}
