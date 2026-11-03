# Grap · App tài xế

Project Flutter 3.47.6 / Riverpod 3 **độc lập**, core và giao diện nằm trong app. Không phụ thuộc project Flutter khác hoặc package nội bộ ở thư mục cha. Dio 5.11.1 được khai báo trực tiếp trong `pubspec.yaml`.

```text
lib/
  main.dart
  app/grap_app.dart
  core/
    config/app_config.dart          # API_BASE_URL, ENABLE_DEV_LOGIN
    network/
      dio_config.dart               # Base URL, JSON headers, timeout
      api_providers.dart            # Dio và ApiClient, đóng kết nối khi dispose
      api_client.dart               # Bearer, refresh single-flight, session guard, retry journal
    domain/                         # Models và repository contracts
    application/                    # Use cases
    data/                           # DTO mappers và API repositories
    providers/app_providers.dart    # Riverpod composition
    theme/                          # Màu, typography, formatter
    widgets/                        # Card, notice, map, dialog, countdown
  features/                         # auth, driving, onboarding, account, journey, places, privacy
test/
  core/                             # Test Dio, phiên, cache, use cases
  features/                         # Test các màn hình
```

```sh
flutter pub get
flutter analyze
flutter test

# Android Emulator
flutter run --dart-define=ENABLE_DEV_LOGIN=true --dart-define=API_BASE_URL=http://10.0.2.2:5080 --dart-define=PORTAL_BASE_URL=http://10.0.2.2:5173

# iOS Simulator
flutter run --dart-define=ENABLE_DEV_LOGIN=true --dart-define=API_BASE_URL=http://127.0.0.1:5080 --dart-define=PORTAL_BASE_URL=http://127.0.0.1:5173
```

`API_BASE_URL` chỉ là host, không thêm `/api/v1`; Dio tự gắn prefix này. File private gửi bằng raw bytes với đúng Content-Type/Length. Lệnh hoàn tất/thu tiền giữ nguyên key và payload khi thử lại. Không ghi token/PIN vào log. Có thể override `dioProvider` hoặc inject transport cho ApiClient khi kiểm thử.

Hướng dẫn backend và tài khoản mẫu nằm tại [README gốc](../../../README.md). Firebase Android/iOS đã được cấu hình trong app; xem [hướng dẫn Firebase](../../../docs/runbooks/FIREBASE_MOBILE.md) để cấu hình APNs, thông tin xác thực máy chủ và thử gửi thông báo. SMS, tracking nền và nghiệm thu thiết bị vật lý vẫn cần hoàn thiện; chỉ bật development login khi chạy local.
