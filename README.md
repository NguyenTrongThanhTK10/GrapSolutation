# Grap Solution

Nền tảng gọi xe gồm backend ASP.NET Core, cổng quản trị **Vue 3 + TypeScript + PrimeVue 4**, app khách hàng và app tài xế **Flutter + Riverpod 3**.

[Xem giao diện desktop](docs/screenshots/dashboard-desktop.png) · [Xem giao diện điện thoại](docs/screenshots/dashboard-mobile.png) · [Kết quả kiểm thử](docs/VALIDATION.md)

Đây là bản phát triển có nghiệp vụ và dữ liệu lưu bền vững, dựa trên [đặc tả](GRAP_SOLUTION_DAC_TA_HE_THONG.md). Có thể chạy vòng đời tiền mặt xuyên suốt trên local. **Chưa phải bản đã nghiệm thu toàn bộ P0 hoặc sẵn sàng vận hành thật**; các tích hợp và khoảng trống còn lại được ghi trong [ma trận triển khai](docs/IMPLEMENTATION_STATUS.md).

## Chạy nhanh

Yêu cầu: .NET SDK 10, Node.js ≥ 20.19, npm; Flutter 3.47/Dart 3.13 nếu chạy mobile. Thư mục `backend` pin SDK theo `global.json`; frontend có `.nvmrc` và lockfile.

Terminal 1:

```sh
cd backend
dotnet restore
dotnet run --project src/GrapSolution.Api -- --environment Development --urls http://127.0.0.1:5080
```

Terminal 2:

```sh
cd admin_portal
nvm use # nếu máy sử dụng nvm
npm ci
npm run dev
```

Mở **http://127.0.0.1:5173**. Chọn tài khoản mẫu rồi nhấn **Vào không gian làm việc**. API tự tạo SQLite và dữ liệu mẫu khi chạy Development lần đầu. Dữ liệu không bị reset khi khởi động lại.

- API: http://127.0.0.1:5080
- OpenAPI: http://127.0.0.1:5080/openapi/v1.json
- Health: `/health/live`, `/health/ready`
- SQLite mặc định: `backend/src/GrapSolution.Api/grap.db`
- Khóa local và file private: `backend/src/GrapSolution.Api/.local/` — đã được gitignore.

Chỉ bind loopback khi sử dụng đăng nhập phát triển. Các route `/auth/development*` không được đăng ký ngoài Development. Không dùng seed và cơ chế đăng nhập mẫu trên môi trường có dữ liệu thật.

## Trải nghiệm trọn một chuyến

1. Mở hai trình duyệt/cửa sổ riêng tư độc lập để có hai phiên khác nhau.
2. Cửa sổ khách: chọn **Trần Ngọc Hà · Khách hàng** (`customer-0`).
3. Cửa sổ tài xế: chọn **Nguyễn Văn Hùng · Tài xế** (`driver-user-0`, GrapBike).
4. Tài xế bật nhận chuyến, chọn vị trí thử nghiệm **Chợ Bến Thành**, nhấn cập nhật vị trí/heartbeat.
5. Khách chọn Bến Thành → Landmark 81 → GrapBike → xem giá → xác nhận đặt xe.
6. Tài xế nhận offer trước hạn 15 giây → xác nhận đã đến điểm đón.
7. Khách đọc PIN từ màn hình; tài xế nhập PIN → bắt đầu chuyến.
8. Tài xế đổi vị trí thử nghiệm sang **Landmark 81**, cập nhật GPS → hoàn tất.
9. Tài xế ghi nhận tiền mặt đã thực thu. Có thể thu thiếu; chuyến vẫn hoàn tất, khoản thu còn lại giữ `PENDING`.
10. Mở tài chính bằng vai trò kế toán để xem payment, sổ cái cân bằng và số dư/công nợ. Khách có thể đánh giá chuyến.

Vị trí thử nghiệm và báo giá fixture luôn được ghi rõ ở UI. Bản đồ nền lấy từ OpenStreetMap; đường nối điểm đón/đến chỉ là minh họa. Không dùng khoảng cách đường chim bay để tạo báo giá chốt.

Một tài xế chỉ có một thiết bị nhận offer hoạt động. Đăng xuất phiên cũ trước khi đăng nhập lại trên thiết bị khác. Header tài khoản hỗ trợ chuyển vai trò trong Development và thu hồi phiên cũ.

## Các vai trò mẫu

| Vai trò | ID | Chức năng chính |
| --- | --- | --- |
| Quản trị vận hành | `staff-OperationsAdmin` | Dashboard, giá/vùng, khách hàng, vận hành, cấu hình, audit |
| Điều phối | `staff-Dispatcher` | Theo dõi, hủy trước chuyến, điều phối lại |
| Xét duyệt | `staff-DriverReviewer` | Xem giấy tờ private, duyệt giấy tờ/hồ sơ |
| Hỗ trợ | `staff-SupportAgent` | Ticket, phản hồi, chuyển trạng thái, tiếp nhận SOS |
| Kế toán | `staff-FinanceOperator` | Payment, ledger, công nợ, lập đề nghị nộp tiền |
| Phê duyệt tài chính | `staff-FinanceApprover` | Duyệt đề nghị do người khác lập |
| Bảo mật | `staff-SecurityAdmin` | Audit, hạn chế tài khoản, xem xét yêu cầu xóa và phản hồi ticket quyền riêng tư |

Không mặc định cấp quyền tài chính cho quản trị vận hành. API kiểm tra vai trò, chủ sở hữu tài nguyên và scope vùng; UI không thay thế kiểm tra này.

## Chạy mobile

```sh
cd mobile/apps/customer_app # hoặc driver_app
flutter pub get
flutter run --dart-define=ENABLE_DEV_LOGIN=true --dart-define=API_BASE_URL=http://10.0.2.2:5080
```

Android emulator dùng `10.0.2.2`; iOS Simulator dùng `http://127.0.0.1:5080`. Trên thiết bị thật cần API HTTPS hoặc mạng phát triển được cấu hình riêng. Không đưa development login vào bản phát hành.

Firebase đã cấu hình cho Android/iOS của cả hai app. Xem [hướng dẫn Firebase mobile](docs/runbooks/FIREBASE_MOBILE.md) để thiết lập APNs, credentials backend và kiểm tra thông báo trên thiết bị.

```sh
# iOS Simulator
flutter run --dart-define=ENABLE_DEV_LOGIN=true --dart-define=API_BASE_URL=http://127.0.0.1:5080

# Link chia sẻ mở trên máy/thiết bị truy cập được portal
flutter run --dart-define=ENABLE_DEV_LOGIN=true --dart-define=API_BASE_URL=http://10.0.2.2:5080 --dart-define=PORTAL_BASE_URL=http://10.0.2.2:5173
```

Hai app dùng secure storage cho session và command hoàn tất/thu tiền chưa rõ kết quả, refresh single-flight, REST snapshot và SignalR + polling. Native có hồ sơ, inbox hỗ trợ, thông báo, chọn ghim thủ công, onboarding tài xế, lịch sử lọc/phân trang, biên nhận và đánh giá, địa chỉ đã lưu, liên hệ tin cậy ngoại tuyến và tiếp nhận yêu cầu xóa tài khoản. Khi chuyến không đổi, lịch sử/thu nhập tải theo khoảng 30 giây; kéo xuống làm mới hoặc chuyến đổi phiên bản tải ngay. Lỗi các phần này không làm mất chuyến hiện tại. App chặn thu thêm khi còn lệnh thu tiền chưa xác nhận hoặc chưa đọc được snapshot thanh toán mới. Hiện tracking mobile chạy khi ứng dụng foreground; background service, GPS queue offline, cơ chế replay tự động có kiểm soát và kiểm thử thiết bị khi khóa màn hình còn phải hoàn thiện trước pilot.

## Kiểm tra

```sh
cd backend
dotnet test GrapSolution.sln

cd ../admin_portal
npm run build
# Chrome + backend/web đang chạy
npm run test:e2e

cd ../mobile/apps/customer_app
flutter pub get
flutter analyze
flutter test
cd ../driver_app
flutter pub get
flutter analyze
flutter test
```

Kết quả thực tế và giới hạn kiểm thử nằm trong [VALIDATION.md](docs/VALIDATION.md). Không đồng nhất kiểm thử SQLite local với chứng minh concurrency trên PostgreSQL.

## Cấu trúc

```text
backend/
  src/GrapSolution.Domain/          # Entity, trạng thái, money, invariant
  src/GrapSolution.Application/     # Ports, use case, quyền tài nguyên
  src/GrapSolution.Infrastructure/  # EF Core, transactions, migrations, map adapters
  src/GrapSolution.Api/             # REST, JWT, SignalR, hosted workers
  tests/GrapSolution.Tests/         # Domain + integration HTTP/SQLite
admin_portal/                      # Vue 3 / PrimeVue / Leaflet / Chart.js
mobile/
  apps/customer_app/               # Project Flutter độc lập cho khách
    lib/app/                      # MaterialApp và vòng đời navigation
    lib/core/                     # Config, Dio, domain, repositories, providers, theme, widgets
    lib/features/                 # Auth, booking, account, journey, places, privacy
    test/                         # Kiểm thử core, màn hình và booking controller
  apps/driver_app/                 # Project Flutter độc lập cho tài xế
    lib/app/
    lib/core/                     # Core nằm trong app, có Dio riêng
    lib/features/                 # Auth, driving, onboarding, account, journey, places, privacy
    test/
docs/                             # Phân tích, mapping yêu cầu, kiến trúc, runbook
```

Hai app không dùng package nội bộ qua `path:` và không phụ thuộc mã nguồn của nhau. Mỗi app khai báo trực tiếp Dio trong `pubspec.yaml`. Cấu hình HTTP nằm tại `lib/core/network/dio_config.dart`, provider tạo Dio và ApiClient tại `api_providers.dart`; `api_client.dart` xử lý bearer, refresh một lần khi nhiều request cùng hết phiên, lỗi API và idempotency. `lib/core/providers/app_providers.dart` nối repository vào Riverpod, màn hình gọi controller/repository qua provider.

## PostgreSQL và triển khai

Có migration PostgreSQL, unique partial index và advisory transaction lock. Local SQLite tạo schema riêng để chạy không cần Docker. Xem [kiến trúc](docs/architecture/ARCHITECTURE.md), [API](docs/api/README.md) và [runbook](docs/runbooks/LOCAL_AND_DEPLOYMENT.md).

```sh
docker compose up --build
```

Compose cung cấp PostgreSQL và web/API Development có seed cho kiểm thử. Chưa chạy Docker Compose trên máy build này do không có Docker daemon. Chuyển sang Production cần key/secret, map/SMS adapter, đăng nhập nhân sự MFA, storage được duyệt và các kiểm thử bắt buộc trong ma trận; không chỉ đổi tên environment.
