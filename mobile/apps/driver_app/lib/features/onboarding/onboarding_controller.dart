import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_driver/core/core.dart';

class OnboardingState {
  final DriverApplication application;
  final DocumentBundle documents;
  final bool uploadEnabled, busy;
  final String? error, message;
  const OnboardingState(
    this.application,
    this.documents,
    this.uploadEnabled, {
    this.busy = false,
    this.error,
    this.message,
  });
}

final onboardingControllerProvider =
    AsyncNotifierProvider.autoDispose<OnboardingController, OnboardingState>(
      OnboardingController.new,
    );

class OnboardingController extends AsyncNotifier<OnboardingState> {
  @override
  Future<OnboardingState> build() {
    ref.watch(sessionProvider);
    return _load();
  }

  Future<OnboardingState> _load() async {
    final repository = ref.read(onboardingRepositoryProvider);
    return OnboardingState(
      await repository.application(),
      await repository.documents(),
      await repository.uploadEnabled(),
    );
  }

  Future<void> _run(
    Future<void> Function(OnboardingRepository, OnboardingState) action,
    String message,
  ) async {
    final current = state.value;
    if (current == null || current.busy) return;
    state = AsyncData(
      OnboardingState(
        current.application,
        current.documents,
        current.uploadEnabled,
        busy: true,
      ),
    );
    final repository = ref.read(onboardingRepositoryProvider);
    try {
      await action(repository, current);
      if (!ref.mounted) return;
      final result = await _load();
      if (ref.mounted) {
        state = AsyncData(
          OnboardingState(
            result.application,
            result.documents,
            result.uploadEnabled,
            message: message,
          ),
        );
      }
    } catch (e) {
      if (ref.mounted) {
        state = AsyncData(
          OnboardingState(
            current.application,
            current.documents,
            current.uploadEnabled,
            error: e.toString(),
          ),
        );
      }
    }
  }

  Future<void> save(
    String service,
    String vehicle,
    String plate,
    String color,
  ) => _run((repository, current) async {
    await repository.save(current.application, service, vehicle, plate, color);
  }, 'Đã lưu thông tin phương tiện.');
  Future<void> upload(
    String type,
    List<int> bytes,
    String contentType,
    DateTime expiry,
  ) => _run((repository, current) async {
    if (!current.application.editable) {
      throw const Failure(
        'APPLICATION_LOCKED',
        'Không thể bổ sung khi hồ sơ đang chờ duyệt hoặc đã được duyệt.',
      );
    }
    if (!current.uploadEnabled) {
      throw const Failure(
        'UPLOAD_DISABLED',
        'Upload giấy tờ chưa được bật ở môi trường này.',
      );
    }
    await repository.uploadDocument(type, bytes, contentType, expiry);
  }, 'Giấy tờ đã được nộp private, đang chờ kiểm tra.');
  Future<void> submit() => _run((repository, current) async {
    if (!current.documents.ready) {
      throw const Failure(
        'DOCUMENTS_REQUIRED',
        'Cần đủ giấy tờ còn hạn và không bị từ chối.',
      );
    }
    await repository.submit(current.application.version);
  }, 'Đã gửi hồ sơ xét duyệt. Bạn sẽ nhận chuyến sau khi được chấp thuận.');
}
