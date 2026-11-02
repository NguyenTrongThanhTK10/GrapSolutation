# GRAP SOLUTION — ĐẶC TẢ HỆ THỐNG GỌI XE

**Thành phần:** Backend C# ASP.NET Core, ứng dụng khách hàng Flutter + Riverpod, ứng dụng tài xế Flutter + Riverpod, chức năng quản trị vận hành.

| Thuộc tính | Giá trị |
| --- | --- |
| Phiên bản tài liệu | 1.0 — Bản đặc tả thiết kế đề xuất |
| Ngày biên soạn | 02/11/2026 |
| Ngôn ngữ giao diện ban đầu | Tiếng Việt; chuẩn bị khả năng đa ngôn ngữ |
| Tiền tệ ban đầu | VND |
| Múi giờ nghiệp vụ ban đầu | Asia/Ho_Chi_Minh |
| Kiến trúc mobile | Clean Architecture, tổ chức theo tính năng, Riverpod quản lý state và dependency injection |
| Kiến trúc backend | Modular Monolith, Clean Architecture, REST API + SignalR + background workers |
| Mức hoàn thiện | Làm cơ sở phân tích, thiết kế, chia backlog và nghiệm thu; chưa phải mã nguồn đã triển khai |

## Mục lục

1. [Mục tiêu, giả định và phạm vi](#1-mục-tiêu-giả-định-và-phạm-vi)
2. [Tác nhân và phân quyền](#2-tác-nhân-và-phân-quyền)
3. [Thuật ngữ và nguyên tắc chung](#3-thuật-ngữ-và-nguyên-tắc-chung)
4. [Kiến trúc tổng thể](#4-kiến-trúc-tổng-thể)
5. [Kiến trúc Flutter và Riverpod](#5-kiến-trúc-flutter-và-riverpod)
6. [Kiến trúc backend C#](#6-kiến-trúc-backend-c)
7. [Đặc tả app khách hàng](#7-đặc-tả-app-khách-hàng)
8. [Đặc tả app tài xế](#8-đặc-tả-app-tài-xế)
9. [Đặc tả quản trị và vận hành](#9-đặc-tả-quản-trị-và-vận-hành)
10. [Vòng đời chuyến và tính nhất quán](#10-vòng-đời-chuyến-và-tính-nhất-quán)
11. [Ghép tài xế và chống nhận trùng](#11-ghép-tài-xế-và-chống-nhận-trùng)
12. [Giá cước, khuyến mại và phí](#12-giá-cước-khuyến-mại-và-phí)
13. [Thanh toán và đối soát](#13-thanh-toán-và-đối-soát)
14. [Định vị, bản đồ và điều hướng](#14-định-vị-bản-đồ-và-điều-hướng)
15. [Realtime, thông báo và mất kết nối](#15-realtime-thông-báo-và-mất-kết-nối)
16. [Mô hình dữ liệu](#16-mô-hình-dữ-liệu)
17. [Quy chuẩn API](#17-quy-chuẩn-api)
18. [Danh mục API](#18-danh-mục-api)
19. [Hợp đồng API mẫu](#19-hợp-đồng-api-mẫu)
20. [Hợp đồng sự kiện và SignalR](#20-hợp-đồng-sự-kiện-và-signalr)
21. [Bảo mật và bảo vệ dữ liệu](#21-bảo-mật-và-bảo-vệ-dữ-liệu)
22. [Yêu cầu phi chức năng](#22-yêu-cầu-phi-chức-năng)
23. [Triển khai, vận hành và khôi phục](#23-triển-khai-vận-hành-và-khôi-phục)
24. [Kiểm thử và tiêu chí nghiệm thu](#24-kiểm-thử-và-tiêu-chí-nghiệm-thu)
25. [Backlog và lộ trình](#25-backlog-và-lộ-trình)
26. [Quy tắc phát triển và bàn giao](#26-quy-tắc-phát-triển-và-bàn-giao)
27. [Quyết định cần chốt](#27-quyết-định-cần-chốt)
28. [Tài liệu kỹ thuật tham khảo](#28-tài-liệu-kỹ-thuật-tham-khảo)

## 1. Mục tiêu, giả định và phạm vi

### 1.1. Mục tiêu sản phẩm

Xây dựng nền tảng gọi xe theo mô hình tương tự Grab: khách chọn điểm đón và điểm đến, xem giá, yêu cầu xe; tài xế đủ điều kiện nhận chuyến, đón và chở khách; hệ thống ghi nhận trạng thái, thanh toán, thu nhập và hỗ trợ sau chuyến.

Mục tiêu của tài liệu là trả lời rõ: ai được thao tác, điều kiện nào được thực hiện, dữ liệu nào phải lưu, app hiển thị gì khi thành công/thất bại, backend xử lý đồng thời thế nào và QA kiểm chứng bằng cách nào.

### 1.2. Yêu cầu đã xác nhận và giả định thiết kế

| Nhóm | Nội dung | Tính chất |
| --- | --- | --- |
| Mobile | Hai app riêng, dùng Flutter và Riverpod | Người dùng yêu cầu |
| API | C# ASP.NET Core | Người dùng yêu cầu C#; ASP.NET Core là lựa chọn triển khai đề xuất |
| Kiến trúc | Clean Architecture, tổ chức theo feature | Giả định do chưa có cây thư mục/sơ đồ dự án cụ thể |
| Dịch vụ | Gọi xe máy, ô tô 4 chỗ, ô tô 7 chỗ | Phạm vi khởi đầu đề xuất |
| Thị trường | Khởi đầu tại một vùng vận hành ở Việt Nam | Giả định để thiết kế vùng, ngôn ngữ và tiền tệ |
| Giá | Chốt giá trước chuyến; phụ phí phải được chấp thuận | Chính sách sản phẩm đề xuất |
| Thanh toán | P0 tiền mặt; P1 tích hợp một cổng thanh toán phù hợp | Thứ tự triển khai đề xuất |
| Quản trị | Có công cụ duyệt tài xế, quản lý chuyến và hỗ trợ | Nhu cầu vận hành suy ra từ mô hình |

Tên “Grap Solution” được dùng làm tên dự án nội bộ. Không mặc định sử dụng thương hiệu, API, dữ liệu hay dịch vụ của Grab.

### 1.3. Phạm vi theo giai đoạn

| Phân hệ | P0 — MVP vận hành | P1 — Hoàn thiện | P2 — Mở rộng |
| --- | --- | --- | --- |
| Khách hàng | OTP, hồ sơ, bản đồ, báo giá, đặt/hủy xe, theo dõi chuyến, tiền mặt, đánh giá, hỗ trợ, chia sẻ chuyến, SOS | Thanh toán trực tuyến, mã giảm giá, địa chỉ yêu thích | Đặt lịch, đặt hộ, doanh nghiệp, nhiều điểm dừng |
| Tài xế | Đăng ký, hồ sơ xe, duyệt, online/offline, nhận chuyến, điều hướng ngoài app, đón khách bằng mã PIN, hoàn tất, thu nhập | Rút tiền tự phục vụ, thưởng, đối soát nâng cao | Đội xe, ca làm việc, tối ưu cung cầu |
| Backend | Định danh, vùng dịch vụ, giá, ghép xe, chuyến, GPS, realtime, tiền mặt, sổ cái, thông báo, quản trị | Cổng thanh toán, hoàn tiền, khuyến mại | Tách dịch vụ theo tải, phân tích dự báo |
| Quản trị | Duyệt tài xế, cấu hình giá, xem chuyến, hỗ trợ, nhật ký, công nợ | Duyệt chi trả, chiến dịch, báo cáo nâng cao | Nhiều đơn vị kinh doanh, đối tác vận tải |

Ngoài phạm vi ban đầu: giao đồ ăn, giao hàng, mua hộ, vay/ứng tiền, ví điện tử khách hàng, chuyến ghép nhiều khách, định tuyến giao nhiều đơn và điều hướng từng ngã rẽ do hệ thống tự xây dựng. Các phần này phải có đặc tả riêng khi triển khai.

### 1.4. Quy ước mức yêu cầu

- **Bắt buộc:** cần đáp ứng để nghiệm thu giai đoạn đã gắn P0/P1/P2.
- **Đề xuất:** lựa chọn thiết kế có thể thay đổi qua quyết định kiến trúc được ghi lại.
- **Cần chốt:** thông số hoặc chính sách phải được chủ sản phẩm xác nhận trước khi phát hành.
- Các con số timeout, khoảng cách và giới hạn trong tài liệu là cấu hình khởi tạo phục vụ phát triển/kiểm thử, không phải số liệu hoạt động của một hệ thống thực tế.

## 2. Tác nhân và phân quyền

| Tác nhân/vai trò | Quyền chính | Giới hạn |
| --- | --- | --- |
| Khách chưa đăng nhập | Xem giới thiệu, chính sách, bắt đầu OTP | Không đặt chuyến hoặc xem dữ liệu cá nhân |
| Customer | Quản lý hồ sơ, báo giá, tạo chuyến, hủy, đánh giá, gửi hỗ trợ | Chỉ dữ liệu của mình; chỉ xem tài xế khi có quan hệ chuyến hợp lệ |
| DriverApplicant | Nộp hồ sơ, bổ sung giấy tờ, xem kết quả duyệt | Không online nhận khách |
| Driver | Online, nhận offer, thực hiện chuyến, xem thu nhập | Chỉ chuyến được giao; không tự sửa giá hoặc số dư |
| DriverReviewer | Duyệt hồ sơ tài xế và xe trong vùng được cấp | Không duyệt chi trả hoặc tự nâng quyền |
| Dispatcher | Theo dõi chuyến, liên hệ hỗ trợ, thực hiện lệnh điều phối hợp lệ | Không sửa trực tiếp bản ghi trạng thái, giá hoặc sổ cái |
| SupportAgent | Xem dữ liệu tối thiểu cho ticket, xử lý phản ánh, đề nghị hoàn tiền | Truy cập PII đầy đủ cần lý do và audit |
| FinanceOperator | Đối soát, lập đề nghị chi/hoàn, theo dõi công nợ | Không tự duyệt đề nghị do mình tạo |
| FinanceApprover | Duyệt chi/hoàn theo hạn mức | Kiểm tra phân tách người lập và người duyệt |
| OperationsAdmin | Quản lý vùng, giá, danh mục, giới hạn vận hành | Phải có phạm vi vùng và nhật ký thay đổi |
| SecurityAdmin | Quản lý vai trò, thu hồi phiên, điều tra truy cập | Không mặc định có quyền chi tiền |
| SystemWorker | Ghép chuyến, hết hạn offer, đồng bộ cổng thanh toán | Tài khoản dịch vụ, quyền tối thiểu, thao tác có trace |

Backend xác minh cả vai trò lẫn quyền với tài nguyên. Đăng nhập với vai trò Driver không đồng nghĩa được xem mọi `rideId`. Bộ lọc theo `userId`, `driverId`, vùng vận hành và trạng thái phải chạy phía server.

## 3. Thuật ngữ và nguyên tắc chung

| Thuật ngữ | Ý nghĩa |
| --- | --- |
| Quote | Báo giá có hạn dùng, gắn khách, tuyến đường, loại xe và phiên bản chính sách |
| Ride | Aggregate nghiệp vụ xuyên suốt từ tìm tài xế đến kết thúc; tương đương một yêu cầu/chuyến trong MVP |
| Offer | Lời mời một tài xế nhận một Ride trong thời gian ngắn |
| Assignment | Quan hệ giao chuyến đã được chấp nhận giữa Ride và tài xế; có lịch sử thay tài xế |
| Presence | Tình trạng kết nối, heartbeat và vị trí; khác với trạng thái nghiệp vụ của tài xế |
| FareSnapshot | Bộ giá và thành phần cước được chốt cho một chuyến |
| Payment | Khoản phải thu cho Ride; có thể có nhiều lần thử thanh toán |
| Ledger | Sổ cái ghi các bút toán tài chính bất biến |
| Settlement | Xác định khoản phải trả/phải thu với tài xế |
| Payout | Lệnh chi tiền thực tế cho tài xế |
| Idempotency | Gửi lại cùng một lệnh không tạo thêm hiệu ứng nghiệp vụ |
| Outbox/Inbox | Bảng đảm bảo phát và nhận sự kiện an toàn khi xử lý lại |

Nguyên tắc bắt buộc:

1. Backend là nguồn dữ liệu quyết định cho giá, trạng thái chuyến và tài chính.
2. Mỗi khách chỉ có tối đa một Ride chưa kết thúc trong P0; mỗi tài xế chỉ có một Assignment đang hoạt động.
3. App có thể hiển thị thao tác đang gửi; chỉ báo nhận/khởi hành/hoàn tất thành công sau khi server xác nhận.
4. Ride, Payment và Settlement có vòng đời độc lập. Chuyến `COMPLETED` chưa chắc đã thu đủ tiền.
5. Push, WebSocket và vị trí có thể đến trễ hoặc mất; ứng dụng phải khôi phục từ REST snapshot.
6. Thay đổi giá/chính sách chỉ áp dụng phiên bản mới; chuyến cũ giữ snapshot để truy vết.
7. Không tự động hủy chuyến đang chở khách chỉ vì mất GPS, mất heartbeat hoặc app bị đóng.

## 4. Kiến trúc tổng thể

### 4.1. Thành phần triển khai

| Thành phần | Công nghệ/định hướng | Trách nhiệm |
| --- | --- | --- |
| Customer App | Flutter + Riverpod | Đặt xe, theo dõi, thanh toán, hỗ trợ |
| Driver App | Flutter + Riverpod | Hồ sơ, online, nhận và thực hiện chuyến, thu nhập |
| Admin Portal | Web; công nghệ UI cần chốt riêng | Vận hành, hỗ trợ, tài chính và cấu hình |
| Public API | C# ASP.NET Core | REST, auth, validation, quyền tài nguyên |
| Realtime Gateway | ASP.NET Core SignalR | Phân phối trạng thái chuyến, offer, vị trí và tin nhắn |
| Workers | C# Worker Service | Dispatch, outbox, timeout, thông báo, đối soát |
| Database | PostgreSQL + PostGIS đề xuất | Nghiệp vụ bền vững, truy vấn địa lý và sổ cái |
| Cache/Presence | Redis đề xuất | Vị trí mới nhất, geospatial index, cache, rate limit |
| Object Storage | Storage private tương thích hạ tầng chọn | Giấy tờ, ảnh, bằng chứng ticket |
| Nhà cung cấp ngoài | SMS/OTP, bản đồ, push, thanh toán | Tích hợp qua interface và adapter |
| Quan sát hệ thống | Structured logs, metrics, distributed tracing | Theo dõi lỗi, tải và các hành vi bất thường |

PostgreSQL là lựa chọn thiết kế cho tài liệu này. Nếu đổi sang SQL Server, cần điều chỉnh spatial query, index, khóa và migration, đồng thời giữ nguyên các bất biến nghiệp vụ.

### 4.2. Ranh giới module backend

| Module | Dữ liệu sở hữu | Cung cấp cho module khác |
| --- | --- | --- |
| Identity | Users, sessions, OTP, roles | User identity, trạng thái tài khoản |
| Customers | Hồ sơ khách, địa chỉ, liên hệ tin cậy | Customer eligibility |
| Drivers | Hồ sơ, giấy tờ, xe, trạng thái xét duyệt | Driver eligibility, phương tiện hiện hành |
| Catalog | Loại dịch vụ, vùng phục vụ | Service availability |
| Pricing | Fare policies, quotes, adjustments | Báo giá, fare snapshot |
| Dispatch | Offers, reservations, dispatch attempts | Tài xế được phân công |
| Rides | Rides, assignments, stops, lifecycle events | Trạng thái và kết quả chuyến |
| Tracking | Location samples, latest locations | Vị trí hợp lệ và độ mới |
| Payments | Payments, attempts, refunds, provider events | Kết quả thu/hoàn tiền |
| Finance | Ledger, settlements, payouts, debt | Thu nhập, công nợ và kết quả đối soát |
| Promotions | Campaigns, reservations, redemptions | Giảm giá được cấp và nguồn tài trợ |
| Communications | Push, chat, delivery attempts | Lịch sử thông báo/giao tiếp |
| SafetySupport | SOS, share links, ratings, tickets | Xử lý an toàn và hỗ trợ |
| Administration | Config publication, audits, reporting views | Cấu hình có phiên bản, dữ liệu báo cáo |

MVP dùng một hệ thống triển khai theo module để giảm độ phức tạp vận hành. Module gọi nhau qua application interface hoặc domain event; không dùng chung tùy tiện các repository nội bộ. Giao dịch ACID giữa Ride, Assignment, Driver reservation được cho phép trong cùng database để bảo vệ việc giao chuyến.

### 4.3. Luồng đồng bộ và bất đồng bộ

- REST xử lý các lệnh cần phản hồi chắc chắn: báo giá, đặt xe, nhận chuyến, đến điểm đón, bắt đầu, hoàn tất, hủy.
- SignalR phát sự kiện sau commit; không thay thế giao dịch cơ sở dữ liệu.
- Worker xử lý công việc kéo dài hoặc cần retry: tìm ứng viên, gửi push, phát outbox, kiểm tra provider, đối soát.
- Database transaction ghi thay đổi nghiệp vụ và outbox cùng lúc. Worker có thể phát lặp; consumer dùng Inbox/dedupe để không tạo hiệu ứng lặp.
- Redis phục vụ hiệu năng. Mất Redis không được làm mất Ride, Assignment, Payment hoặc Ledger.

## 5. Kiến trúc Flutter và Riverpod

### 5.1. Quy tắc phân lớp

| Lớp | Nội dung | Được phụ thuộc | Không được chứa |
| --- | --- | --- | --- |
| Domain | Entity, value object, repository interface, Failure, policy thuần Dart | Dart core và shared domain types | Widget, Dio, JSON DTO, Riverpod, database plugin |
| Application | Use case, phối hợp repository, input/output use case | Domain | Widget, BuildContext, HTTP trực tiếp |
| Data | DTO, mapper, API/local datasource, repository implementation | Domain và hạ tầng | UI, navigation, business rule giá quyết định |
| Presentation | Screen, widget, controller/notifier, view state | Application, Domain, Riverpod | Truy cập HTTP/database trực tiếp |
| Composition Root | Khởi tạo Dio, repository implementation và các provider | Các lớp cần wiring | Quy tắc nghiệp vụ |

Luồng thao tác: `Widget → Riverpod Controller → Use case → Repository interface → Repository implementation → Datasource`. Dữ liệu trả về được map từ DTO thành entity và view state. Dependency compile-time luôn hướng về interface; việc wiring implementation đặt tại composition root.

### 5.2. Tổ chức source đề xuất

```text
grap_solution/
  backend/
    GrapSolution.sln
    src/
    tests/
  mobile/
    apps/
      customer_app/
      driver_app/
    packages/
      grap_core/
      grap_design_system/
      grap_contracts/
  admin_portal/
  docs/
    architecture/
    api/
    runbooks/
```

Mỗi app có cấu trúc thống nhất:

```text
lib/
  bootstrap.dart
  app/
    app.dart
    router/
    di/
    session/
    theme/
  core/
    errors/
    network/
    realtime/
    location/
    storage/
    config/
    telemetry/
  features/
    booking/
      domain/
        entities/
        value_objects/
        repositories/
      application/
        use_cases/
      data/
        dtos/
        mappers/
        datasources/
        repositories/
      presentation/
        controllers/
        states/
        screens/
        widgets/
  l10n/
```

`booking` là ví dụ; từng tính năng dùng cùng cấu trúc. Customer App gồm `auth`, `profile`, `places`, `booking`, `active_ride`, `ride_history`, `payments`, `promotions`, `ratings`, `support`, `safety`, `notifications`. Driver App gồm `auth`, `onboarding`, `documents`, `vehicle`, `availability`, `offers`, `active_ride`, `earnings`, `settlements`, `support`, `safety`, `notifications`.

### 5.3. Quy ước Riverpod bắt buộc

| Loại provider | Mục đích | Ví dụ |
| --- | --- | --- |
| Provider | Khởi tạo dependency, cấu hình bất biến | `rideRepositoryProvider`, `createRideUseCaseProvider` |
| FutureProvider | Query chỉ đọc, tải dữ liệu đơn giản | Lịch sử chuyến theo filter |
| StreamProvider | Quan sát stream/realtime đã qua repository | Stream Ride snapshot hợp nhất |
| Notifier/AsyncNotifier | State màn hình và command có nghiệp vụ | `BookingController`, `DriverOfferController` |
| Family | State/query theo khóa rõ ràng | `rideDetailProvider(rideId)` |

1. `ProviderScope` nằm ở root của mỗi app. Widget dùng `ref.watch` để render và `ref.read` khi thực hiện hành động.
2. Điều hướng, snackbar và dialog phát sinh từ kết quả command hoặc `ref.listen`; không tạo side effect trong `build`.
3. State bất biến. Không giữ `BuildContext` trong notifier, repository hoặc use case.
4. Mỗi chuyến có một repository stream hợp nhất REST + realtime; không để nhiều màn hình tự sửa các bản sao trạng thái chuyến.
5. Provider theo màn hình được tự giải phóng khi phù hợp. Phiên đăng nhập, active ride và kết nối dùng vòng đời app được quản lý tường minh, không bị dispose khi đổi tab.
6. `ref.onDispose` hủy subscription/timer/token request. Provider không tự tạo thêm socket mỗi lần rebuild.
7. Đăng xuất phải ngắt socket, hủy stream và xóa cache gắn tài khoản trước khi tài khoản khác đăng nhập.
8. Query có debounce/hủy request cũ. Chỉ áp dụng kết quả tìm địa chỉ hoặc báo giá của request còn hiệu lực.
9. Retry tự động chỉ dùng cho thao tác đọc hoặc lệnh có idempotency đã thiết kế; không để rebuild gửi lại lệnh đặt/nhận/thu tiền.
10. Dùng `select` hoặc tách provider để GPS cập nhật marker không rebuild toàn bộ màn hình.
11. Chọn một phong cách Riverpod code generation hoặc khai báo thủ công cho toàn dự án; không trộn tùy tiện. Phiên bản package được khóa khi khởi tạo code và kiểm tra trên CI.
12. Riverpod quản lý state trong tiến trình Flutter; việc theo dõi vị trí khi app chạy nền phụ thuộc dịch vụ/vòng đời hệ điều hành, không dựa vào một provider chạy vô hạn.

### 5.4. Các state chính trên mobile

| Feature | State cần quản lý |
| --- | --- |
| Auth | `initial`, `sendingOtp`, `awaitingOtp`, `verifying`, `authenticated`, `locked`, `failure` |
| Booking | Điểm đón/đến, loại xe, báo giá, hạn dùng, loading, lỗi, command đang chờ |
| ActiveRide | Ride snapshot, version, tình trạng kết nối, vị trí mới nhất, command pending, thông tin an toàn |
| DriverAvailability | Mong muốn online, trạng thái server, quyền GPS, health của tracking, reservation hiện hành |
| DriverOffer | `offerId`, hạn server, countdown hiển thị, đang nhận/từ chối, kết quả nhận |
| Earnings | Khoảng ngày, dữ liệu tổng hợp, phân trang, thời điểm đối soát gần nhất |

Mỗi màn hình có trạng thái loading/empty/error/data và hành động thử lại phù hợp. Khi dữ liệu cũ còn dùng được, hiển thị dữ liệu cũ kèm trạng thái đang cập nhật thay vì xóa trắng màn hình.

### 5.5. Giao tiếp mạng và lưu cục bộ

- Dùng một HTTP client abstraction, đề xuất Dio; có timeout, correlation ID, che thông tin nhạy cảm trong log và chuẩn hóa lỗi.
- Refresh token thực hiện single-flight: nhiều request hết hạn cùng lúc chỉ tạo một refresh; request chờ kết quả rồi gửi lại tối đa một lần.
- Refresh token lưu bằng cơ chế secure storage của nền tảng. Không nhúng API secret, signing key hoặc khóa cổng thanh toán trong app.
- Cache địa chỉ, cấu hình và lịch sử gần đây theo tài khoản; có TTL và xóa khi logout. Không lưu giấy tờ tài xế trong cache public.
- DTO thuộc Data; entity thuộc Domain. Không truyền response JSON thẳng vào widget.
- Local queue chỉ lưu GPS và command được phép khôi phục rõ ràng. Khi hết token, không gửi tiếp dữ liệu dưới danh tính tài khoản mới.
- Shared package chứa thành phần dùng chung thực sự; không chia sẻ trực tiếp màn hình hoặc controller mang nghiệp vụ khác nhau giữa hai app.

## 6. Kiến trúc backend C#

### 6.1. Cấu trúc solution

```text
src/
  GrapSolution.Domain/
    Common/
    Identity/
    Drivers/
    Rides/
    Pricing/
    Payments/
    Finance/
  GrapSolution.Application/
    Abstractions/
    Features/
      Rides/Commands/
      Rides/Queries/
      Dispatch/
      Drivers/
      Payments/
    Validation/
    Authorization/
  GrapSolution.Infrastructure/
    Persistence/
      Configurations/
      Migrations/
    Repositories/
    Integrations/
    Messaging/
    Storage/
    Observability/
  GrapSolution.Api/
    Controllers/
    Hubs/
    Middleware/
    Authorization/
    DependencyInjection/
  GrapSolution.Worker/
    Jobs/
    Consumers/
  GrapSolution.Contracts/
    V1/
tests/
  GrapSolution.Domain.Tests/
  GrapSolution.Application.Tests/
  GrapSolution.IntegrationTests/
  GrapSolution.ContractTests/
```

### 6.2. Trách nhiệm và dependency

- `Domain` chứa entity, aggregate, value object, invariant và domain event; không tham chiếu ASP.NET Core hoặc Entity Framework Core.
- `Application` chứa command/query handler, use case, authorization theo tài nguyên và port hạ tầng; phụ thuộc Domain.
- `Infrastructure` triển khai persistence, EF Core, provider bản đồ, OTP, push và thanh toán; phụ thuộc Application/Domain.
- `Api` và `Worker` là entry point và composition root. Controller xác thực input, gọi use case, map response; không chứa logic ghép xe hoặc tính tiền.
- `Contracts` chứa request/response public và event schema; không trả entity EF trực tiếp ra ngoài.
- Dùng EF Core cho persistence và migration; truy vấn nóng có thể dùng SQL được kiểm soát, có parameter và đo hiệu năng.
- Command và query được tách về trách nhiệm. Thư viện mediator là tùy chọn, không phải yêu cầu bắt buộc của kiến trúc.
- Các interface chính: `IMapProvider`, `IOtpProvider`, `IPushSender`, `IPaymentGateway`, `IFileStorage`, `IClock`, `ICurrentUser`, `IUnitOfWork`, `IEventPublisher`.

### 6.3. Transaction và xử lý lỗi

1. Handler thay đổi trạng thái phải kiểm tra quyền, version và invariant trong transaction phù hợp.
2. Chuyển trạng thái Ride, cập nhật Assignment/Driver reservation, ghi event và outbox được commit nhất quán.
3. Không giữ database transaction trong lúc gọi SMS, bản đồ, ngân hàng hoặc push. Gọi ngoài transaction hoặc dùng workflow/outbox.
4. Lỗi nghiệp vụ dùng mã ổn định; lỗi kỹ thuật có `traceId`, không lộ stack trace, SQL hay secret.
5. Concurrency conflict trả `409` và thông tin version cần thiết; client tải lại snapshot.
6. Tác vụ job phải có khóa logic, lease có thời hạn và khả năng khôi phục sau crash. Correctness cuối cùng dựa vào DB constraint và transaction.
7. Khi cùng một workflow phải khóa nhiều bản ghi, áp dụng một thứ tự khóa thống nhất cho mọi code path, rồi retry có giới hạn khi deadlock.

## 7. Đặc tả app khách hàng

### 7.1. Danh sách màn hình

| ID | Màn hình | Nội dung/hành động chính |
| --- | --- | --- |
| C-S01 | Khởi động | Cấu hình tối thiểu, phiên đăng nhập, khôi phục chuyến đang hoạt động |
| C-S02 | Đăng nhập/OTP | Số điện thoại, mã OTP, gửi lại, hỗ trợ |
| C-S03 | Trang chủ | Bản đồ, điểm đón, điểm đến, dịch vụ đang phục vụ |
| C-S04 | Tìm địa chỉ | Gợi ý, vị trí trên bản đồ, địa chỉ gần đây, ghi chú |
| C-S05 | Chọn xe/báo giá | Giá, ETA ước tính, phương thức trả, chi tiết phí |
| C-S06 | Tìm tài xế | Trạng thái tìm, thời gian dự kiến, hủy |
| C-S07 | Tài xế đến đón | Hồ sơ xe/tài xế, vị trí, liên hệ, mã PIN, hủy |
| C-S08 | Đang di chuyển | Tuyến, ETA, chia sẻ, SOS, liên hệ hỗ trợ |
| C-S09 | Kết quả/thanh toán | Cước cuối, khoản cần trả, kết quả thu tiền, đánh giá |
| C-S10 | Lịch sử/chi tiết | Bộ lọc, biên nhận, báo vấn đề, đặt lại tuyến |
| C-S11 | Hồ sơ/cài đặt | Thông tin, quyền, chính sách, xóa tài khoản |
| C-S12 | Hỗ trợ/an toàn | Ticket, bằng chứng, trạng thái xử lý, liên hệ tin cậy |

### 7.2. C-FR-01 — Đăng nhập và quản lý phiên [P0]

- Đầu vào: số điện thoại chuẩn hóa, quốc gia, OTP và định danh phiên thiết bị.
- OTP gắn một challenge; mặc định hết hạn sau 180 giây, gửi lại sau 60 giây, tối đa 5 lần nhập sai/challenge. Rate limit theo số điện thoại, thiết bị và nguồn truy cập.
- Đăng nhập lần đầu tạo hồ sơ tối thiểu sau khi xác minh số điện thoại và chấp thuận điều khoản cần thiết. Các chấp thuận lưu version và thời điểm.
- Thông báo không tiết lộ số điện thoại nào đã có tài khoản nếu không cần thiết. Không trả OTP trong API response hoặc log.
- Khi bị khóa, app hiển thị lý do được phép công bố và đường dẫn hỗ trợ. Logout thu hồi refresh session, socket và push token binding.
- Nghiệm thu: OTP sai/hết hạn không tạo phiên; retry xác minh sau timeout không tạo nhiều tài khoản; refresh token đã thu hồi không dùng lại được.

### 7.3. C-FR-02 — Hồ sơ và địa chỉ [P0/P1]

- P0: sửa họ tên, avatar, email tùy chọn; số điện thoại phải đổi qua luồng xác minh riêng, không sửa bằng profile update thông thường.
- P1: lưu Nhà/Cơ quan/địa chỉ yêu thích với tọa độ, địa chỉ hiển thị và ghi chú; không dựa duy nhất vào chuỗi địa chỉ.
- Khách không cấp GPS vẫn có thể nhập điểm đón thủ công. App giải thích các tính năng bị giới hạn.
- Địa chỉ ngoài vùng dịch vụ trả lý do rõ ràng; không cho đặt xe rồi mới báo không hỗ trợ.

### 7.4. C-FR-03 — Tìm điểm đón và điểm đến [P0]

- Cho phép nhập text, chọn gợi ý hoặc kéo ghim trên bản đồ. Có hướng dẫn điểm đón thuận tiện và ghi chú cho tài xế.
- Debounce tìm kiếm khởi tạo 350 ms; hủy request cũ, giới hạn phạm vi theo vùng.
- Tọa độ đầu vào kiểm tra khoảng hợp lệ, tọa độ khác nhau và tuyến có thể phục vụ. Khoảng cách tuyến đường lấy từ provider phía backend.
- Nếu địa chỉ hiển thị thay đổi khi reverse geocoding chậm, giữ tọa độ người dùng đã xác nhận; không âm thầm chuyển ghim.
- Khi provider lỗi: cho thử lại, giữ lựa chọn hiện tại; không lấy khoảng cách đường chim bay làm giá chốt.

### 7.5. C-FR-04 — Xem và xác nhận báo giá [P0]

- App gửi tọa độ, dịch vụ và phương thức thanh toán để server tạo quote; không gửi giá do app tự tính.
- Hiển thị giá phải trả, thành phần phí, các khoản chưa bao gồm, khoảng cách/thời gian ước tính và thời điểm báo giá hết hạn.
- Quote mặc định có hiệu lực 120 giây. Khi hết hạn hoặc sửa điểm đón/đến, loại xe, promo hoặc phương thức thanh toán, phải lấy quote mới.
- Nếu giá mới khác giá đã xem, khách xác nhận lại trước khi tạo chuyến. Không tự đặt bằng giá mới.
- Nghiệm thu: quote của khách A không dùng cho khách B; quote hết hạn không tạo Ride; policy mới không sửa giá của Ride đã tạo.

### 7.6. C-FR-05 — Đặt xe và tìm tài xế [P0]

- Điều kiện: đăng nhập hợp lệ, quote còn hiệu lực, không có Ride khác đang hoạt động, phương thức thanh toán đủ điều kiện.
- Nút đặt xe tạo một `Idempotency-Key`; timeout/retry giữ nguyên khóa và payload.
- Sau khi server tạo Ride, mở màn hình `SEARCHING`. App quan sát sự kiện và có polling dự phòng theo mục 15.
- Khi hết thời gian tìm: hiển thị `NO_DRIVER` hoặc `EXPIRED` theo nguyên nhân; cho phép yêu cầu quote mới, đổi loại xe hoặc thử lại bằng yêu cầu mới.
- Tài xế hiển thị trên bản đồ trang chủ chỉ là gợi ý cung xe, không phải cam kết tài xế đó chắc chắn nhận.
- Nghiệm thu: bấm nhanh nhiều lần hoặc gửi lại cùng request chỉ tạo một Ride; hai request khác khóa vẫn bị giới hạn một Ride đang hoạt động.

### 7.7. C-FR-06 — Theo dõi đón khách và chuyến đi [P0]

- Sau ghép xe, hiển thị tên/ảnh tài xế, loại xe, màu xe, biển số, đánh giá, ETA và vị trí gần nhất có thời gian cập nhật.
- Cung cấp mã PIN xác nhận đón khách trên app khách; chỉ khách và server xác thực được mã, không phát mã trong offer hoặc app tài xế.
- Hiển thị rõ khi tài xế đổi sau điều phối lại; xóa vị trí và thông tin liên hệ của tài xế cũ khỏi màn hình hiện hành.
- Marker có nội suy hiển thị nhưng không nội suy thành dữ liệu tính cước. Khi vị trí cũ, hiển thị đang mất cập nhật.
- Khởi động lại app phải mở lại Ride đang hoạt động đúng trạng thái, không quay về tạo chuyến mới.

### 7.8. C-FR-07 — Hủy chuyến [P0; phí hủy P1]

- Trước khi bắt đầu, khách có thể xem điều kiện hủy và xác nhận lý do. P0 mặc định phí hủy bằng 0.
- P1: backend tạo cancel preview có version, phí dự kiến, thời hạn và policy. Xác nhận hủy phải gắn preview còn hiệu lực; thay đổi phí cần xác nhận lại.
- Race hủy/nhận chuyến được quyết định bằng transaction; server trả trạng thái cuối cùng. App không kết luận hủy thành công chỉ từ việc đóng màn hình.
- Khi `IN_PROGRESS`, không cung cấp hủy thông thường; dùng yêu cầu kết thúc sớm/hỗ trợ an toàn và lưu nguyên nhân riêng.
- Không xóa lịch sử chuyến khi hủy; giữ lý do, người thao tác và mốc thời gian.

### 7.9. C-FR-08 — Thanh toán, đánh giá và lịch sử [P0/P1]

- P0 hiển thị số tiền mặt phải trả và trạng thái xác nhận đã thu/chưa thu. App khách chỉ phản hồi việc đã trả; tài xế/server thực hiện ghi nhận theo luồng đối soát.
- P1 hiển thị trạng thái cổng thanh toán, yêu cầu thao tác bổ sung hoặc thử lại; không hiển thị trả thành công chỉ từ redirect về app.
- Sau Ride kết thúc, khách được đánh giá 1–5 sao, chọn nhãn và ghi chú. Mỗi người chỉ có một đánh giá/đối tượng/chuyến, có thể sửa trong cửa sổ cấu hình.
- Lịch sử hỗ trợ phân trang, lọc ngày/trạng thái; chi tiết có timeline, fare snapshot, thông tin thanh toán và hỗ trợ.
- Biên nhận trong app là chứng từ nội bộ. Nếu cần hóa đơn điện tử, tích hợp hệ thống hóa đơn riêng và có nghiệp vụ phát hành/điều chỉnh.

### 7.10. C-FR-09 — Liên hệ, an toàn và hỗ trợ [P0/P1]

- P0: liên hệ qua kênh được triển khai cho chuyến hiện tại; nếu dùng gọi điện trực tiếp phải thông báo việc chia sẻ số. Masking qua nhà cung cấp là P1.
- P0: chia sẻ chuyến qua token ngẫu nhiên có hạn dùng, thu hồi được; trang chia sẻ chỉ lộ thông tin cần thiết và ngừng hiển thị vị trí sau khi kết thúc/hết hạn.
- SOS mở lựa chọn liên hệ khẩn cấp phù hợp vùng và gửi cảnh báo nội bộ nếu có mạng; app không cam kết lực lượng hỗ trợ đã tiếp nhận khi chưa có xác nhận.
- Khi offline, hiển thị cảnh báo chưa gửi được SOS nội bộ và vẫn cho gọi qua hệ điều hành nếu khả dụng.
- Ticket gồm loại vấn đề, Ride liên quan, nội dung, ảnh đính kèm tùy chọn, trạng thái và lịch sử phản hồi.
- P1: chat trong chuyến, có quyền truy cập theo Assignment và chính sách lưu trữ; không triển khai chat cộng đồng.

## 8. Đặc tả app tài xế

### 8.1. Danh sách màn hình

| ID | Màn hình | Nội dung/hành động |
| --- | --- | --- |
| D-S01 | Đăng nhập | OTP, phiên thiết bị |
| D-S02 | Hồ sơ đăng ký | Thông tin cá nhân, vùng, loại dịch vụ |
| D-S03 | Giấy tờ và xe | Tải giấy tờ, hạn dùng, tình trạng duyệt |
| D-S04 | Chờ duyệt | Hồ sơ thiếu, lý do từ chối, nộp lại |
| D-S05 | Trang chủ online | Bản đồ, khả năng nhận chuyến, GPS/kết nối |
| D-S06 | Offer nhận chuyến | Thời hạn, điểm đón, dịch vụ, thu nhập dự kiến |
| D-S07 | Đi đón khách | Điều hướng, liên hệ, đến điểm đón |
| D-S08 | Xác nhận khách | Nhập mã PIN, bắt đầu chuyến |
| D-S09 | Thực hiện/hoàn tất | Điều hướng, kết thúc, phụ phí được duyệt, tiền cần thu |
| D-S10 | Thu nhập | Chuyến, phí, giảm trừ, số dư, công nợ |
| D-S11 | Đối soát/chi trả | Kỳ đối soát, chi tiết khoản chi, trạng thái |
| D-S12 | Hỗ trợ/cài đặt | Ticket, SOS, quyền, thiết bị, logout |

### 8.2. D-FR-01 — Đăng ký và xét duyệt [P0]

- Tài xế xác minh số điện thoại, nhập họ tên, thông tin liên hệ và vùng đăng ký.
- Hồ sơ giấy tờ cấu hình theo loại xe/vùng: giấy tờ định danh, giấy phép lái xe phù hợp, đăng ký xe, ảnh xe, bảo hiểm hoặc tài liệu vận hành được yêu cầu. Không coi danh sách mẫu này là kết luận pháp lý đầy đủ.
- Mỗi giấy tờ có loại, file private, số/mã được bảo vệ, ngày cấp/hết hạn nếu có, trạng thái duyệt và lịch sử phiên bản.
- Chỉ online khi hồ sơ và xe được duyệt, không bị khóa, giấy tờ còn hạn và tài khoản đáp ứng điều kiện vận hành.
- Nộp lại giấy tờ không ghi đè bản đã duyệt; tạo phiên bản mới để kiểm tra. Giấy tờ bắt buộc hết hạn chặn nhận chuyến mới, không tự kết thúc chuyến đang chở.
- Nghiệm thu: chỉnh trường `approvalStatus` từ app không có hiệu lực; tài xế bị từ chối biết phần nào cần bổ sung.

### 8.3. D-FR-02 — Bật/tắt nhận chuyến [P0]

- Trước khi online, kiểm tra GPS, quyền cần cho use case, mạng, thiết bị đang hoạt động và trạng thái tài xế từ server.
- P0 mỗi tài xế chỉ có một phiên thiết bị nhận offer. Thiết bị khác muốn tiếp quản phải qua xác minh và cơ chế thu hồi phiên cũ.
- Online là ý định hoạt động; chỉ được dispatch khi presence còn mới, vị trí đủ tin cậy và không có reservation/assignment xung đột.
- Tắt online khi chưa có chuyến: ngừng offer mới, giải phóng offer chưa chấp nhận theo transaction.
- Tắt online khi đang có chuyến: đánh dấu `goOfflineAfterCurrentRide`; vẫn theo dõi và thực hiện chuyến hiện tại.
- Nếu tracking nền bị ngừng, app hiển thị rõ tình trạng; server loại khỏi ứng viên mới khi quá hạn vị trí. Không tự giải phóng Assignment đang có.

### 8.4. D-FR-03 — Nhận hoặc từ chối offer [P0]

- Offer hiển thị dịch vụ, điểm đón, khoảng cách/ETA đến điểm đón, tiền mặt cần thu hoặc phương thức trả, thu nhập dự kiến và countdown dựa trên thời gian server.
- Mức thông tin điểm đến trước nhận cần chốt theo chính sách; quyền riêng tư và mức hiển thị phải thống nhất ở API, không chỉ ẩn UI.
- Nhận offer gọi REST có idempotency, `offerId`, `expectedVersion`. Chỉ mở chuyến sau phản hồi nhận thành công.
- Từ chối lưu lý do tùy chọn; hết hạn tự đóng. Offer push đến muộn không được tạo lại quyền nhận.
- Nếu offer bị người khác thắng hoặc Ride đã hủy, hiển thị kết quả bình thường và tải lại availability.
- Nghiệm thu: hai tài xế đồng thời nhận một Ride chỉ một người có Assignment active; một tài xế không thể nhận hai Ride.

### 8.5. D-FR-04 — Đi đón và xác nhận đến nơi [P0]

- Hiển thị điểm đón đã chốt, ghi chú, thông tin khách tối thiểu và liên hệ còn hiệu lực.
- Điều hướng P0 mở app bản đồ ngoài bằng deep link có tọa độ; quay lại app vẫn giữ active ride. Lỗi mở app ngoài có phương án xem bản đồ trong ứng dụng.
- Đánh dấu đến nơi yêu cầu đúng Assignment và gần điểm đón; khởi tạo ngưỡng 200 m với vị trí mới, có accuracy phù hợp.
- Khi GPS không đủ tin cậy, cho yêu cầu ngoại lệ có lý do/bằng chứng; việc chấp nhận do server hoặc vận hành quyết định, không dùng ngưỡng cứng để chặn vô hạn.
- Sau khi server xác nhận `DRIVER_ARRIVED`, khách được thông báo; thời gian chờ tính từ timestamp server.

### 8.6. D-FR-05 — Bắt đầu chuyến bằng mã PIN [P0]

- Chỉ tài xế đang được giao chuyến và Ride ở `DRIVER_ARRIVED` được nhập PIN.
- Backend kiểm tra mã, số lần sai, trạng thái hiện tại và quyền. Mã không nằm trong request chi tiết chuyến của tài xế.
- PIN mặc định 4 chữ số, thời hạn theo Ride; rate limit 5 lần sai rồi khóa luồng thông thường và yêu cầu hỗ trợ xác minh.
- Không log PIN dạng rõ. Lưu HMAC với secret ngoài DB; giới hạn brute force và không chỉ dùng hash thông thường với không gian mã nhỏ.
- Mất mạng không được tự coi là bắt đầu hợp lệ. Hiển thị đang chờ kết nối; cần xác nhận server trước khi chuyển UI sang `IN_PROGRESS`.

### 8.7. D-FR-06 — Thực hiện và hoàn tất [P0]

- Khi `IN_PROGRESS`, app thu vị trí phù hợp, hiển thị điểm đến và truy cập an toàn. Đổi điểm đến trong chuyến chưa hỗ trợ P0; yêu cầu hỗ trợ khi cần.
- Tài xế bấm kết thúc tại điểm trả; backend xác minh quyền và trạng thái, ghi vị trí/thời gian cùng chất lượng GPS.
- Nếu kết thúc xa điểm trả, server yêu cầu lý do/kết thúc sớm thay vì tự tính theo một điểm đến khác. Các trường hợp nghi vấn đưa vào review.
- Phụ phí chỉ tính nếu có loại phí được phép, bằng chứng khi cần và khách đã chấp thuận hoặc có quyết định vận hành được audit.
- Hoàn tất Ride không phụ thuộc thu tiền thành công; sau hoàn tất có màn hình xác nhận tiền mặt đã thu hoặc chưa thu/thu thiếu.
- Mất mạng sau bấm hoàn tất: lưu một command chờ xác nhận, giữ nguyên idempotency key; app hiển thị “Chưa xác nhận hoàn tất”, không nhận chuyến mới trước khi server chốt.
- Không cho app gửi `finalFare` tùy ý để backend ghi nhận. Backend lấy snapshot và các adjustment đã duyệt.

### 8.8. D-FR-07 — Hủy, khách không xuất hiện và sự cố [P0/P1]

- Trước bắt đầu: tài xế yêu cầu rời Assignment với lý do. P0 hệ thống thử điều phối lại trong ngân sách tìm còn lại nếu khách chưa hủy.
- Khi tài xế rời, đóng Assignment cũ, vô hiệu quyền liên hệ/realtime, tăng version và chuyển Ride về `SEARCHING` nếu còn điều kiện; không tạo thêm Ride của khách.
- Khách không xuất hiện: phải đã `DRIVER_ARRIVED`, chờ đủ cấu hình và có lần liên hệ theo chính sách. P0 ghi nhận không thu phí; phí no-show thuộc P1 cần công bố trước.
- Sự cố trong chuyến: không dùng hủy thông thường. Mở luồng kết thúc sớm/SOS/ticket; chỉ kết thúc theo quyền hợp lệ, lý do và timestamp lưu đầy đủ.

### 8.9. D-FR-08 — Thu nhập, công nợ và chi trả [P0/P1]

- P0: xem tổng chuyến hoàn tất, giá gộp, hoa hồng, phí điều chỉnh, giảm giá theo nguồn tài trợ, tiền mặt đã thu, khoản được nhận và khoản phải nộp.
- Số dư hiển thị tách `pending`, `available`, `held`, `debt`; không cộng một khoản tiền mặt đã cầm vào số được rút thêm.
- P0 vận hành có thể lập và xác nhận chi trả thủ công có bằng chứng và hai cấp khi cần; dữ liệu vẫn phải vào sổ cái.
- P1 tài xế gửi yêu cầu rút theo số dư khả dụng, hạn mức và tài khoản nhận đã xác minh. Đổi tài khoản nhận cần xác thực tăng cường và audit.
- Số liệu ngày/tháng dựa múi giờ nghiệp vụ. Hiển thị thời điểm cập nhật và trạng thái đối soát.
- Khóa nhận chuyến tiền mặt khi công nợ vượt ngưỡng là policy cấu hình; không chặn tùy tiện việc hoàn tất chuyến đang chạy.

## 9. Đặc tả quản trị và vận hành

### 9.1. Chức năng quản trị

| Mã | Chức năng | Yêu cầu |
| --- | --- | --- |
| A-FR-01 | Dashboard | Số Ride theo trạng thái, cung xe, tỉ lệ ghép thành công, lỗi thanh toán; có thời điểm cập nhật |
| A-FR-02 | Duyệt tài xế/xe | Xem file private có hạn, duyệt/từ chối từng tài liệu, lý do bắt buộc, lưu người duyệt |
| A-FR-03 | Vận hành chuyến | Tìm theo mã, khách/tài xế có quyền, timeline, GPS, assignment; thao tác qua command hợp lệ |
| A-FR-04 | Giá và vùng | Quản lý polygon, loại xe, giờ phục vụ, version giá, thời điểm hiệu lực, xem trước tác động |
| A-FR-05 | Tài khoản | Khóa/mở, lý do, thời hạn, thu hồi phiên; khóa nhận chuyến mới không tự hủy chuyến đang chạy |
| A-FR-06 | Tiền mặt/đối soát | Xem khoản phải thu/phải trả, xác nhận nộp tiền có bằng chứng, chênh lệch và dispute |
| A-FR-07 | Hoàn/chi tiền | Đề nghị, phê duyệt khác người lập, gửi provider và kiểm tra kết quả; không sửa số dư bằng tay |
| A-FR-08 | Hỗ trợ/an toàn | Ticket, SOS, mức ưu tiên, người phụ trách, lịch sử xử lý, SLA và escalation |
| A-FR-09 | Khuyến mại [P1] | Ngân sách, đối tượng, thời hạn, giới hạn lượt, nguồn tài trợ, bật/tắt có phiên bản |
| A-FR-10 | Báo cáo/xuất dữ liệu | CSV có scope, giới hạn dung lượng, background export và link private hết hạn |
| A-FR-11 | Phân quyền/audit | Role + scope + hạn mức; tìm audit theo người, tài nguyên, khoảng thời gian |

### 9.2. Ràng buộc thao tác vận hành

- Không có nút sửa trực tiếp `ride.status`, `payment.status`, `driver.balance` hoặc xóa ledger entry.
- Điều phối viên thay tài xế chỉ trước `IN_PROGRESS`, tài xế mới vẫn phải xác nhận. Không ép Assignment lên tài xế không đủ điều kiện.
- Giá mới theo quy trình draft → review → publish → effective; không sửa bản giá đã được quote/Ride tham chiếu.
- Điều chỉnh tiền sau chuyến tạo Adjustment/Refund/Credit có tham chiếu; giữ nguyên fare snapshot và biên nhận trước đó trong lịch sử.
- Các thao tác nhạy cảm có `reasonCode`, ghi chú, actor, dữ liệu trước/sau được che PII và trace ID.
- Quyền xem giấy tờ, số điện thoại đầy đủ, tuyến GPS và tải dữ liệu phải tách riêng; báo cáo không mặc định xuất mọi thông tin cá nhân.

## 10. Vòng đời chuyến và tính nhất quán

### 10.1. Trạng thái Ride

| Trạng thái | Ý nghĩa | Hành động tiếp theo hợp lệ |
| --- | --- | --- |
| SEARCHING | Yêu cầu đã được tạo, đang ghép tài xế | Ghép, khách hủy, không có xe, hết hạn |
| ASSIGNED | Một tài xế nhận thành công | Đến điểm đón, khách hủy, thay tài xế trước khởi hành |
| DRIVER_ARRIVED | Tài xế đã đến và server xác nhận | PIN bắt đầu, khách hủy, no-show, thay tài xế |
| IN_PROGRESS | Khách đã được xác nhận, đang thực hiện | Hoàn tất bình thường hoặc kết thúc sớm có lý do |
| COMPLETED | Dịch vụ kết thúc | Thanh toán, đối soát, đánh giá, hỗ trợ |
| CANCELED | Yêu cầu kết thúc trước khởi hành | Thanh toán phí nếu áp dụng, hỗ trợ |
| NO_DRIVER | Dispatch kết luận không tìm được ứng viên phù hợp trong chính sách | Khách tạo yêu cầu mới |
| EXPIRED | Hết hạn yêu cầu hoặc điều kiện chuẩn bị không hoàn thành | Khách tạo yêu cầu mới |

`COMPLETED`, `CANCELED`, `NO_DRIVER`, `EXPIRED` là terminal state. Không mở lại terminal Ride để nhận chuyến mới. Hỗ trợ sau chuyến và điều chỉnh tài chính không đổi terminal state.

### 10.2. Ma trận chuyển trạng thái

| Từ | Sang | Actor/lệnh | Điều kiện bắt buộc |
| --- | --- | --- | --- |
| Chưa có | SEARCHING | Customer/CreateRide | Quote hợp lệ, một active Ride, điều kiện thanh toán đạt |
| SEARCHING | ASSIGNED | Driver/AcceptOffer | Offer đúng người, chưa hết hạn, Ride chưa gán, driver còn đủ điều kiện |
| ASSIGNED | DRIVER_ARRIVED | Assigned Driver/Arrive | Assignment active, location/ngoại lệ hợp lệ |
| DRIVER_ARRIVED | IN_PROGRESS | Assigned Driver/Start | PIN hợp lệ, version đúng, không bị hủy |
| IN_PROGRESS | COMPLETED | Assigned Driver/Complete | Lý do/vị trí kết thúc hợp lệ, fare được chốt |
| IN_PROGRESS | COMPLETED | Operations/EndEarly | Quyền đặc biệt, bằng chứng/lý do, quy tắc tính cước kết thúc sớm |
| SEARCHING | CANCELED | Customer/Cancel | Yêu cầu chưa kết thúc |
| ASSIGNED, DRIVER_ARRIVED | CANCELED | Customer/Cancel hoặc no-show hợp lệ | Preview phí nếu có, version đúng, chưa bắt đầu |
| ASSIGNED, DRIVER_ARRIVED | SEARCHING | Driver release/Operations reassign | Đóng Assignment cũ, còn ngân sách dispatch, khách vẫn có nhu cầu |
| ASSIGNED, DRIVER_ARRIVED | CANCELED | Operations khi không thể phục vụ | Không còn điều kiện tiếp tục, lý do rõ ràng và thông báo khách |
| SEARCHING | NO_DRIVER | Dispatch worker | Hết vòng tìm được cấu hình; không còn offer có thể chấp nhận |
| SEARCHING | EXPIRED | Timeout worker | Đến deadline tuyệt đối của yêu cầu |

Khi worker đánh dấu `NO_DRIVER` hoặc `EXPIRED`, phải khóa/check version để không ghi đè kết quả tài xế nhận cùng lúc. Một Ride có thể có nhiều Assignment trong lịch sử nhưng chỉ một Assignment active.

### 10.3. Trạng thái tài xế phải tách theo chiều

| Chiều | Giá trị mẫu | Nguồn dữ liệu |
| --- | --- | --- |
| Hồ sơ | DRAFT, PENDING_REVIEW, APPROVED, REJECTED, SUSPENDED | DB |
| Ý định hoạt động | OFFLINE, ONLINE | DB/session |
| Reservation | NONE, OFFER_RESERVED, ON_RIDE | DB; cache là bản sao |
| Presence | HEALTHY, STALE, DISCONNECTED | Heartbeat và location TTL |

Tài xế chỉ là ứng viên khi được duyệt + muốn online + không bận/không giữ offer khác + presence/location đạt chuẩn. Mất presence chỉ làm mất điều kiện nhận chuyến mới, không xóa `ON_RIDE`.

### 10.4. Bất biến và khôi phục

- Mỗi chuyển trạng thái tăng `version`, ghi `RideEvent` có sequence, người thực hiện, thời gian server và reason.
- `CustomerId` của Ride không thay đổi; `AssignedDriverId` hiện hành phải khớp Assignment active.
- PIN xác thực chỉ áp dụng cho Assignment hiện tại; khi thay tài xế, xoay mã hoặc xác nhận lại theo policy để tránh mã cũ bị dùng.
- Crash sau commit nhưng trước trả response được xử lý bằng idempotency. Crash trước commit không được phát event thành công.
- Tác vụ sửa chữa đọc DB, phát hiện Ride/Assignment/Driver reservation bất nhất và chuyển review; không tự giao tài xế đang có Ride khác.

### 10.5. Giao dịch kết thúc và giải phóng tài xế

- Complete hợp lệ phải chốt `COMPLETED`, `endedAt`, fare cuối và nghĩa vụ Payment; đóng Assignment bằng `endedAt`, giải phóng `ON_RIDE`, tăng version và ghi outbox trong transaction được thiết kế rõ.
- Nếu bước lập ledger entitlement được xử lý sau qua outbox, đánh dấu tài chính `pending` và dùng operation key để đảm bảo đúng một lần posting; không hiển thị số đó là available trước khi đủ điều kiện.
- Tài xế trở lại pool khi đã giải phóng Assignment, vẫn đủ eligibility và muốn online. Nếu đã chọn offline sau chuyến thì giữ offline.
- Hủy terminal/no-show trước khởi hành cũng phải đóng Assignment/offer và reservation liên quan; thao tác release cũ không được ảnh hưởng Assignment mới.
- Sau khi Assignment đóng, tài xế vẫn được xem biên nhận/thu nhập và ghi nhận khoản thu tiền mặt được phép của chính chuyến đã thực hiện, nhưng không còn quyền theo dõi vị trí trực tiếp của khách hoặc nhóm realtime active.
- Khoản chưa thu hoặc dispute được giữ theo Payment/Finance riêng; không giữ tài xế ở trạng thái bận vô hạn chỉ vì Payment pending. Policy công nợ có thể chặn chuyến mới theo điều kiện đã công bố.

## 11. Ghép tài xế và chống nhận trùng

### 11.1. Điều kiện lọc ứng viên

1. Driver được duyệt, không bị tạm khóa và phương tiện đủ điều kiện loại dịch vụ.
2. Online trong vùng phục vụ; giấy tờ bắt buộc còn hạn.
3. Không có Assignment active hoặc reservation còn hiệu lực cho offer khác.
4. Heartbeat/location còn mới, accuracy đạt ngưỡng; không có cờ GPS giả lập/rủi ro đang bị chặn theo policy.
5. Không bị khách chặn hoặc nằm trong quan hệ không được ghép theo chính sách an toàn.
6. Tài khoản đáp ứng điều kiện phương thức thanh toán/công nợ.

### 11.2. Thuật toán P0

- Lấy ứng viên bằng geo index; dùng khoảng cách địa lý để thu hẹp, sau đó xếp hạng bằng ETA đường đi khi provider hỗ trợ.
- Thứ tự ưu tiên đề xuất: ETA đến điểm đón → thời gian chờ nhận chuyến → tiêu chí chất lượng hợp lệ. Dùng tiêu chí ổn định để xử lý bằng điểm.
- P0 gửi offer tuần tự: một offer đang mở cho một Ride; một tài xế chỉ giữ một offer. Cách này đơn giản hóa đồng thời và giảm offer thất bại giả.
- Khi offer bị từ chối/hết hạn, thử tài xế tiếp theo trong cùng vòng; sau đó mở rộng bán kính.
- Không gửi lại cùng tài xế trong một attempt nếu họ đã từ chối, trừ khi policy cho phép và đã hết cooldown.
- P1 có thể gửi theo nhóm nhỏ; vẫn phải duy trì invariants bằng DB và vô hiệu mọi offer thua khi một Assignment được commit.

### 11.3. Cấu hình khởi tạo

| Cấu hình | Mặc định đề xuất | Ghi chú |
| --- | --- | --- |
| Bán kính vòng tìm | 1 km → 3 km → 5 km | Tùy vùng và loại xe |
| Offer TTL | 15 giây | Deadline quyết định bằng thời gian server |
| Tổng deadline dispatch | 120 giây từ lúc tạo Ride | Không kéo dài vô hạn sau thay tài xế |
| Heartbeat tài xế online | 10 giây | Tách heartbeat khỏi dữ liệu GPS |
| Driver presence stale | Sau 30 giây không heartbeat | Ngừng xét ứng viên mới |
| Location hợp lệ cho dispatch | Tuổi ≤ 30 giây, accuracy ≤ 100 m | Nếu không đạt, loại tạm thời hoặc yêu cầu cập nhật |
| Vị trí gần nhất trên bản đồ | Cảnh báo cũ sau 30 giây | Không giả vị trí đang sống |
| Retry dispatch job | Exponential backoff có jitter, giới hạn bởi Ride deadline | Tách lỗi kỹ thuật và hết ứng viên |

### 11.4. Giao dịch AcceptOffer

Pseudo-workflow bắt buộc, không phải mã C# hoàn chỉnh:

```text
1. Xác thực Driver, device session và Idempotency-Key.
2. Bắt đầu transaction; khóa tài nguyên theo thứ tự thống nhất.
3. Đọc Ride, Offer, Driver reservation và Assignment active.
4. Kiểm tra owner của Offer, thời hạn server, Ride SEARCHING, version.
5. Kiểm tra Driver vẫn đủ điều kiện và không có Assignment active.
6. Mark Offer ACCEPTED; tạo Assignment active; đặt Driver ON_RIDE.
7. Đặt Ride ASSIGNED, driver hiện hành, tăng version.
8. Hủy/đóng các Offer khác của Ride và reservation liên quan nếu có.
9. Ghi RideEvent, Outbox và kết quả idempotency cùng transaction.
10. Commit; trả snapshot. Publisher gửi sự kiện sau commit.
```

Khóa Redis có thể giảm cạnh tranh nhưng không là lớp bảo vệ duy nhất. Cần conditional update/row lock và unique constraint trong DB. Khi constraint xung đột, trả mã nghiệp vụ `DRIVER_ALREADY_ASSIGNED` hoặc `RIDE_ALREADY_ASSIGNED`; không trả lỗi 500 chung chung.

### 11.5. Timeout, lease và xử lý race

- Lease offer hết hạn chỉ giải phóng reservation chưa chấp nhận; không dùng TTL để giải phóng tài xế đã `ON_RIDE`.
- Worker dùng DB time hoặc thời gian đã đồng bộ; app countdown chỉ phục vụ hiển thị.
- Accept đến server trước deadline nhưng chỉ khóa được sau deadline: kiểm tra thời điểm xử lý trong transaction, offer có thể bị từ chối; quy tắc này phải nhất quán.
- Cancel thắng trước: Accept trả `RIDE_CANCELED`. Accept thắng trước: Cancel áp dụng trên trạng thái mới và policy phí đã được chấp thuận.
- Thay tài xế và offer hết hạn phải đóng đúng `assignmentId`/`offerId`; event cũ không được đóng Assignment mới.

## 12. Giá cước, khuyến mại và phí

### 12.1. Chính sách giá có phiên bản

`FarePolicy` gắn vùng, loại dịch vụ, thời điểm hiệu lực, tiền tệ, quy tắc làm tròn, mức tối thiểu, mức phụ thu và chính sách hủy. Khi publish tạo version bất biến. Quote lưu version cùng đầu vào tuyến và kết quả tính.

Các thành phần:

- `baseFare`: giá mở cửa.
- `distanceFare`: phần giá quãng đường, có thể theo bậc; giá tuyến đường được tính ở backend.
- `durationFare`: phần giá thời gian ước tính nếu mô hình áp dụng.
- `serviceFee`: phí nền tảng công bố cho khách.
- `surgeMultiplier`: hệ số cung cầu đã công bố; P0 mặc định 1.
- `approvedExtras`: cầu đường, đỗ xe hoặc khoản bổ sung được phép.
- `discount`: giảm giá hợp lệ, có nguồn tài trợ.
- `taxComponent`: thành phần thuế nếu policy được xác định; không tự gán thuế suất trong code.

### 12.2. Công thức báo giá đề xuất

```text
transportFare = roundPolicy(max(minimumFare,
  (baseFare + distanceFare + durationFare) * surgeMultiplier))
grossFare = transportFare + serviceFee + approvedExtras + taxComponent
customerPayable = max(0, grossFare - eligibleDiscount)
```

- Mọi thành phần là số tiền nguyên theo đơn vị nhỏ nhất của currency. Với VND trong thiết kế này, lưu số nguyên đồng; không dùng `double` để lưu hoặc tính tiền.
- Hệ số/tỉ lệ dùng `decimal`, quy định rõ thứ tự tính và làm tròn tại policy. Response luôn trả breakdown, không chỉ một tổng.
- P0 giá trước chuyến được chốt từ quote; tắc đường và GPS dao động không tự tăng giá.
- Khoản phát sinh không được tài xế tự cộng trực tiếp. Khi khách từ chối, không đưa vào giá cuối; tranh chấp được hỗ trợ xử lý.
- Kết thúc sớm P0 giữ giá đã chốt nếu không có quyết định điều chỉnh; mọi giảm/hoàn có reason và bản ghi riêng. Cần công bố chính sách này trước khi khách đặt.
- Đổi điểm đến, nhiều điểm dừng và tính cước đồng hồ theo GPS thuộc P2; không tái sử dụng công thức ước tính mà không có đặc tả đo cước.

### 12.3. Minh họa báo giá

Ví dụ mô phỏng, không phải bảng giá kinh doanh: base 12.000 đ, phần quãng đường 30.000 đ, phần thời gian 8.000 đ, hệ số 1, service fee 0, toll được duyệt 10.000 đ, không có thành phần thuế trong ví dụ. Giá gộp 60.000 đ; voucher nền tảng 5.000 đ; khách trả 55.000 đ.

Nếu P0 chưa bật phụ phí, quote không có toll và app phải ghi rõ khoản nào chưa bao gồm. Khi bật phụ phí cần có UI xin chấp thuận và API adjustment tương ứng.

### 12.4. Khuyến mại [P1]

- Điều kiện: thời gian, vùng, loại xe, khách mới/cũ, mức chi tối thiểu, phương thức trả, số lần/người, tổng ngân sách và điều kiện loại trừ.
- Khi tạo Ride, reserve lượt và ngân sách bằng transaction; khi chuyến đạt điều kiện, redeem; khi hủy/không có xe, release theo policy.
- Quote chỉ kiểm tra khả năng áp dụng, không cam kết ngân sách mãi mãi. Nếu reserve thất bại khi đặt, khách phải xác nhận quote mới; không âm thầm bỏ giảm giá.
- Một lần redeem gắn Ride/campaign duy nhất. Retry hoặc event lặp không trừ ngân sách thêm.
- Voucher do nền tảng tài trợ và voucher do tài xế/đối tác tài trợ được ghi tách, vì tác động đến thu nhập khác nhau.

### 12.5. Phí hủy/no-show [P1]

- Chỉ bật sau khi có UI thông báo và đồng ý chính sách; backend tính từ mốc server, không dựa đồng hồ app.
- Hủy khi chưa ghép xe mặc định 0; hủy sau ghép/đến nơi tính theo version policy và trường hợp miễn.
- Phí được tạo thành nghĩa vụ thanh toán riêng hoặc cùng Payment có phân loại rõ; không ghi thành doanh thu chuyến vận chuyển đã hoàn tất.
- Khi bắt đầu và hủy cạnh tranh, command thua trả trạng thái mới; không được thu đồng thời phí hủy và toàn bộ chuyến do xử lý lặp.

## 13. Thanh toán và đối soát

### 13.1. Mô hình trạng thái

| Đối tượng | Trạng thái mẫu | Nguyên tắc |
| --- | --- | --- |
| Payment | PENDING, PROCESSING, SUCCEEDED, FAILED, CANCELED, PARTIALLY_REFUNDED, REFUNDED | Thành công khi thu đủ khoản phải thu; theo dõi amount paid/remaining |
| PaymentAttempt | CREATED, REQUIRES_ACTION, PROCESSING, SUCCEEDED, FAILED, CANCELED, UNKNOWN | Mỗi lần thử có định danh provider riêng |
| Refund | REQUESTED, APPROVED, PROCESSING, SUCCEEDED, FAILED, UNKNOWN | UNKNOWN phải query/reconcile trước khi gửi lại |
| Settlement | PENDING, CALCULATED, APPROVED, DISPUTED, SETTLED | Không đồng nhất với Payment |
| Payout | REQUESTED, APPROVED, PROCESSING, PAID, FAILED, UNKNOWN | Chỉ PAID khi có bằng chứng kết quả hợp lệ |

P0 tiền mặt cũng tạo Payment, không bỏ qua mô hình tài chính. Thanh toán thiếu được phản ánh bằng `paidAmount < payableAmount` và khoản còn phải thu; không đánh dấu toàn bộ thành công.

### 13.2. Tiền mặt [P0]

1. Khi hoàn tất, server chốt nghĩa vụ phải thu và khoản tài xế được hưởng.
2. App tài xế hiển thị số tiền cần thu; tài xế xác nhận thực thu bằng command riêng có idempotency.
3. Thu đủ: ghi nhận cash collection, phân bổ nghĩa vụ và bút toán công nợ. Khách nhận thông báo/biên nhận.
4. Chưa thu/thu thiếu: lưu số thực thu, lý do và khoản còn thiếu; tạo review khi cần. Driver không được tùy ý sửa giá để khớp tiền thu.
5. Khách phản ánh đã trả nhưng tài xế chưa ghi nhận: tạo dispute, không tự ghi thêm khoản thu lần hai.
6. Tiền mặt tài xế đang giữ được bù vào nghĩa vụ với nền tảng. Số có thể rút không bao gồm phần này lần nữa.
7. Nộp công nợ bằng chuyển khoản/thủ công cần reference, bằng chứng và xác nhận độc lập; không chỉ dựa ảnh chụp từ app.

### 13.3. Thanh toán trực tuyến [P1]

- Provider được chọn theo thị trường, khả năng ký hợp đồng, phương thức hỗ trợ và yêu cầu đối soát. Không mặc định bất kỳ provider nào hoạt động cho mọi pháp nhân.
- App dùng SDK/hosted flow của provider hoặc token; server giữ secret, không lưu PAN/CVV.
- Trước dispatch, adapter xác minh phương thức và thực hiện authorize nếu provider có hỗ trợ. Nếu không có authorize, dùng cơ chế chuẩn bị phương thức/thu sau chuyến phù hợp hợp đồng và kiểm soát rủi ro.
- Capture sau chốt giá theo khả năng provider. Tài xế không thu thêm tiền mặt nếu Payment đang ở trạng thái xử lý không rõ.
- Redirect/deep link chỉ báo kết quả giao diện. Backend xác nhận bằng webhook hợp lệ hoặc API truy vấn provider.
- Webhook kiểm tra chữ ký trên raw body theo tài liệu provider, kiểm tra merchant, amount, currency, reference và chống replay nếu protocol có timestamp.
- Ghi durable Inbox trước khi trả 2xx; xử lý nghiệp vụ bất đồng bộ. Nếu không lưu bền vững được, trả lỗi để provider retry.
- Dedupe theo `(provider, eventId)` và định danh business transaction. Sự kiện đến sai thứ tự không làm `SUCCEEDED` lùi thành `FAILED`; cần reconcile trạng thái hiện hành khi mâu thuẫn.
- Hết timeout tạo attempt `UNKNOWN/PROCESSING`, không mặc định failed rồi tạo charge mới. Query provider trước khi retry tạo giao dịch.

### 13.4. Công thức thu nhập và ví dụ đối soát

```text
driverEntitlement = grossFare
  - platformCommission
  - otherDriverDeductions
  - driverFundedDiscount
  + driverBonus

driverNetSettlement = driverEntitlement - cashActuallyCollectedByDriver
```

`platformCommission` tính trên commission base có version; toll, thuế và phí nền tảng có được tính vào base hay không phải công bố rõ. Voucher nền tảng tài trợ không trừ thu nhập tài xế trừ khi có chính sách khác được chấp thuận. Công thức là mô hình vận hành đề xuất, cần kế toán duyệt hệ thống tài khoản và cách ghi nhận doanh thu.

Ví dụ giả định: giá vận chuyển 50.000 đ + toll 10.000 đ = gross 60.000 đ; commission 20% của 50.000 đ = 10.000 đ; nền tảng tài trợ voucher 5.000 đ; khách trả 55.000 đ; quyền lợi tài xế 50.000 đ.

| Phương thức | Khách thanh toán | Tài xế đã giữ tiền | Quyền lợi tài xế | Đối soát còn lại |
| --- | ---: | ---: | ---: | --- |
| Tiền mặt | 55.000 đ | 55.000 đ | 50.000 đ | Tài xế phải nộp 5.000 đ |
| Trực tuyến | 55.000 đ cho provider/nền tảng | 0 đ | 50.000 đ | Nền tảng phải trả tài xế 50.000 đ |

Phần chênh lệch kinh tế của nền tảng trong ví dụ là 5.000 đ trước phí provider và các chi phí khác. Tiền gộp chuyến không mặc định là doanh thu kế toán của nền tảng.

### 13.5. Sổ cái và idempotency tài chính

- Ledger dùng bút toán kép: tổng debit bằng tổng credit trong từng journal/currency. Các account mẫu: tiền đang giữ ở provider, phải thu khách, phải thu tài xế, phải trả tài xế, doanh thu phí, chi phí khuyến mại và tài khoản clearing.
- Journal và entry đã post không sửa/xóa. Sai sót tạo reversal/adjustment có liên kết journal gốc.
- Mỗi business operation có khóa duy nhất, ví dụ `(rideId, operationType, operationVersion)`; một event replay không sinh journal thứ hai.
- Available balance tính từ ledger đã post và các khoản hold. Cập nhật projection balance cùng transaction hoặc xử lý có version và reconciliation.
- Hoàn tiền/rút tiền phải giữ chỗ số tiền trong transaction; hai request đồng thời không được sử dụng cùng available balance.
- Tổng refund đã thành công cộng refund còn hold không vượt khoản có thể hoàn; cần tính cả các request đang xử lý.
- Payout ngoài hệ thống ở trạng thái chưa rõ không được gửi lại bằng reference mới; xác minh provider/ngân hàng trước.

### 13.6. Đối soát và tranh chấp

- Đối soát mỗi ngày theo kỳ khóa sổ và timezone nghiệp vụ; tiền từ provider chưa settle không tự coi là tiền ngân hàng đã nhận.
- So sánh Ride ↔ Payment ↔ provider transaction ↔ Ledger ↔ Settlement/Payout.
- Báo cáo chênh lệch: thiếu webhook, thu trùng, sai amount/currency, tiền đã thu nhưng thiếu ledger, payout chưa rõ, tiền mặt chưa nộp.
- Chi trả thủ công vẫn có người lập/người duyệt, reference ngân hàng và audit. Hai người không được phê duyệt cùng một yêu cầu hai lần.
- Khiếu nại có thể hold khoản phải trả liên quan theo policy; không đổi lịch sử chuyến. Mọi giải tỏa/điều chỉnh ghi reason và người phê duyệt.

## 14. Định vị, bản đồ và điều hướng

### 14.1. Hợp đồng vị trí

Mỗi sample gồm `deviceSessionId`, `sampleId`, `sequence`, `latitude`, `longitude`, `accuracyMeters`, `speedMps`, `headingDegrees`, `recordedAt`, `sentAt` và `rideId/assignmentId` nếu liên quan. Backend bổ sung `receivedAt`, kết quả validation và cờ chất lượng.

- WGS84; latitude trong [-90, 90], longitude trong [-180, 180]; tốc độ m/s, khoảng cách mét, thời gian giây.
- `recordedAt` do thiết bị gửi có thể sai; server kiểm tra lệch đồng hồ và không dùng duy nhất timestamp client cho tính tiền/quyền.
- Sequence tăng trong một device session. Sample cũ vẫn có thể lưu vào lịch sử nếu hợp lệ nhưng không ghi đè latest location mới hơn.
- Khởi tạo giới hạn batch 100 sample/request và buffer offline 30 phút; khi vượt giới hạn, giảm mẫu/xóa mẫu cũ theo policy, không để bộ nhớ tăng vô hạn.
- Dedupe sample theo tài xế + device session + sample ID. Reject payload quá lớn hoặc gắn Ride không thuộc Assignment hiện hành.

### 14.2. Tần suất đề xuất

| Tình huống | Thu/gửi mục tiêu | Hành vi |
| --- | --- | --- |
| Offline, không có Ride | Dừng tracking vận hành | Không tiếp tục gửi GPS chỉ để duy trì presence |
| Online đứng yên | Khoảng 15 giây hoặc theo chuyển động | Giảm hao pin, giữ độ mới theo ngưỡng dispatch |
| Online di chuyển, chưa nhận | 5–10 giây | Dùng cho tìm ứng viên |
| Đi đón/đang chở | 3–5 giây khi hệ điều hành cho phép | Gửi batch nhỏ, ưu tiên thông tin mới |
| Mất mạng | Buffer hữu hạn, retry có backoff | Khi nối lại tách latest và lịch sử |

Đây là mục tiêu thiết kế, không phải bảo đảm hệ điều hành sẽ cấp vị trí đúng chu kỳ. Luôn đo trên thiết bị thực, chế độ tiết kiệm pin và khi tắt màn hình.

### 14.3. Android và iOS

- App khách mặc định chỉ cần quyền vị trí khi người dùng dùng tính năng chọn điểm đón; luôn có nhập thủ công.
- App tài xế cần giải thích tracking khi online/đang chuyến. Android phải thiết kế foreground service loại location cho trường hợp phù hợp và có thông báo đang hoạt động.
- Không mặc định khai báo `ACCESS_BACKGROUND_LOCATION` chỉ vì màn hình app không hiển thị. Phải phân biệt foreground service và truy cập background thực sự; chỉ xin quyền bổ sung khi use case đã chứng minh cần, theo từng bước phù hợp nền tảng.
- iOS cấu hình capability/background mode và authorization phù hợp use case Core Location; có hướng dẫn quyền bị từ chối, tracking bị hạn chế và phục hồi khi mở lại app.
- Khi force-stop, bị OS đình chỉ hoặc người dùng thu hồi quyền, không cam kết theo dõi liên tục. Server loại tài xế stale khỏi dispatch, giữ Assignment và cảnh báo vận hành nếu chuyến chưa kết thúc.
- Bản build release phải kiểm tra khai báo quyền, thông tin quyền riêng tư, SDK thu thập vị trí và tài liệu mô tả chức năng thực tế trước khi nộp store.

### 14.4. Chất lượng và chống giả vị trí

- Kiểm tra accuracy thấp, bước nhảy bất hợp lý, vận tốc bất thường, timestamp quá cũ/tương lai, tín hiệu mock/root/jailbreak nếu có.
- Cờ rủi ro là tín hiệu hỗ trợ, không tự kết luận gian lận chỉ từ một sample. Có cửa sổ đánh giá và đường dẫn xử lý ngoại lệ.
- Map matching dùng cho hiển thị/phân tích nếu provider cho phép; giữ được dữ liệu gốc trong giới hạn lưu trữ.
- Không đưa khóa REST provider đặc quyền vào app. Mobile map SDK key hạn chế theo package/bundle/signature khi provider hỗ trợ.
- Có quota, cache theo điều kiện sử dụng của provider, timeout và cảnh báo chi phí cho autocomplete, geocoding, route và ETA.

## 15. Realtime, thông báo và mất kết nối

### 15.1. Phân loại kênh

| Kênh | Dùng cho | Không được dựa vào để |
| --- | --- | --- |
| REST | Command, query snapshot, retry an toàn | Tự động suy ra đã gửi push |
| SignalR | Trạng thái Ride, offer, vị trí và chat nếu bật | Lưu bền hoặc bảo đảm nhận đủ sự kiện |
| Push | Đánh thức/nhắc người dùng và deep link | Khẳng định offer còn hiệu lực hoặc thanh toán đã chốt |
| SMS | OTP; thông báo dự phòng đã cấu hình | Truyền PIN chuyến/PII không cần thiết |

### 15.2. Quy trình khôi phục

1. App mở hoặc có mạng trở lại: kiểm tra/refresh phiên bằng single-flight.
2. Tải active Ride, current Offer và availability có quyền; server snapshot luôn ưu tiên hơn state cache.
3. Kết nối hub, đăng ký group được server cho phép, lấy hoặc xác nhận version mới nhất.
4. Với trạng thái Ride, bỏ event có version ≤ snapshot; nếu có khoảng trống version, tải snapshot rồi tiếp tục.
5. Gửi lại command chưa rõ kết quả bằng cùng key và payload; không tạo key mới khi chưa biết kết quả cũ.
6. Gửi latest GPS trước, rồi đồng bộ batch lịch sử với sample ID/sequence để không kéo marker về quá khứ.

Sự kiện có thể lặp hoặc đến sai thứ tự. Hệ thống dùng cơ chế ít nhất một lần khi phát outbox; không đưa ra cam kết exactly-once xuyên suốt tất cả mạng/provider.

### 15.3. Polling và push

- Khi Ride active và hub chưa hoạt động: polling khởi tạo 5 giây khi foreground, tăng backoff khi lỗi; không chạy timer Flutter để hứa polling khi app bị đình chỉ.
- Push chứa event type và ID cần tải lại; hạn chế PII, không chứa PIN, thông tin giấy tờ hoặc payment secret.
- Offer push có TTL ngắn; khi mở app luôn kiểm tra Offer từ server. Countdown không được khởi tạo lại bằng TTL đầy đủ từ push trễ.
- Device token có thể đổi; upsert gắn app instance và user, loại token lỗi, unbind khi logout.
- Android/iOS có thể chặn thông báo. Nếu quyền push bị từ chối, app vẫn đọc được trạng thái khi foreground; cảnh báo tài xế về ảnh hưởng nhận offer.

### 15.4. Bảng xử lý sự cố

| Sự cố | App hiển thị | Backend/hệ thống xử lý |
| --- | --- | --- |
| Tạo Ride timeout | Đang kiểm tra kết quả | Retry cùng key, tra active Ride |
| Hub mất kết nối | Đang kết nối lại; REST còn dùng được | Snapshot/polling, reconnect có jitter |
| Push đến muộn | Tải trạng thái mới nhất | Offer cũ trả expired, không mở lại |
| Driver mất GPS trước nhận | Cần cập nhật vị trí | Loại khỏi candidate pool |
| Driver mất GPS đang chuyến | Vị trí đang gián đoạn | Giữ Assignment, cảnh báo theo ngưỡng |
| App bị đóng | Khôi phục khi mở lại | Ride vẫn tồn tại trong DB |
| Payment redirect thành công nhưng webhook chưa đến | Đang xác minh thanh toán | Query provider/reconciliation |
| Redis lỗi | Một số thông tin realtime chậm | Không giao chuyến thiếu kiểm tra; phục hồi presence từ heartbeat |
| Provider bản đồ lỗi | Không thể lấy báo giá, giữ địa chỉ | Circuit breaker/quota/fallback đã kiểm chứng; không bịa tuyến |

## 16. Mô hình dữ liệu

### 16.1. Quy ước dữ liệu

- ID nội bộ dùng UUID; mã chuyến hiển thị được sinh riêng, không dùng mã ngắn có thể đoán để cấp quyền.
- Timestamp lưu UTC bằng kiểu có timezone phù hợp; lịch báo cáo và policy có timezone nghiệp vụ riêng.
- Money lưu `bigint` theo minor unit, kèm `currency`; tỉ lệ dùng `numeric/decimal`, không dùng float.
- Soft delete phù hợp với hồ sơ/danh mục; Ride, audit và tài chính áp dụng retention/ẩn danh theo quy trình, không xóa dây chuyền tùy tiện.
- Entity có `createdAt`, `updatedAt` khi cần; aggregate có `version` là concurrency token được tăng tường minh.
- Điểm không gian dùng PostGIS `geography(Point, 4326)` hoặc biểu diễn được thống nhất; vùng có polygon hợp lệ và spatial index.

### 16.2. Bảng nghiệp vụ chính

| Bảng | Trường chính ngoài ID | Ràng buộc/ghi chú |
| --- | --- | --- |
| Users | phoneNormalized, displayName, status | Unique số điện thoại hiện hành theo policy tài khoản |
| UserRoles | userId, role, scope | Không lấy role từ request profile |
| OtpChallenges | destinationHash, codeHmac, expiresAt, attempts, consumedAt | Challenge dùng một lần; rate limit và TTL |
| AuthSessions | userId, deviceId, refreshTokenHash, tokenFamily, expiresAt, revokedAt | Refresh rotation/reuse detection |
| DeviceRegistrations | userId, appType, instanceId, pushToken, platform, enabled | Token gắn đúng app instance |
| CustomerProfiles | userId, avatarFileId, email | Quan hệ 1:1 với user vai trò khách |
| SavedPlaces | customerId, label, point, address, note | Chỉ chủ sở hữu truy cập |
| TrustedContacts | customerId, name, phoneProtected | Chấp thuận và kiểm soát hiển thị |
| DriverProfiles | userId, reviewStatus, operatingZoneId, suspendedUntil | Không đồng nhất status với online |
| DriverDocuments | driverId, type, fileId, version, expiry, reviewStatus | Lịch sử duyệt; file private |
| Vehicles | driverId, plateNormalized, type, seats, approvalStatus | Thay xe phải kiểm tra lại khả năng phục vụ |
| DriverOperationalStates | driverId, onlineIntent, activeDeviceSessionId, offlineAfterRide, version | Điểm khóa để kiểm tra khả năng nhận |
| DriverReservations | driverId, offerId, expiresAt, status | Một reservation hiện hành/tài xế |
| ServiceTypes | code, vehicleRules, active | Ví dụ BIKE, CAR_4, CAR_7 |
| ServiceZones | name, polygon, timezone, currency, active | Publish version khi thay đổi phạm vi |
| FarePolicies | zoneId, serviceTypeId, version, effectiveFrom, rules | Bản đã publish bất biến |
| Quotes | customerId, routeInput, policyVersion, breakdown, expiresAt, consumedRideId | Một quote chỉ tạo tối đa một Ride |
| Rides | code, customerId, serviceTypeId, status, currentDriverId, quoteId, version, deadlineAt | Nguồn trạng thái chính |
| RideStops | rideId, order, type, point, addressSnapshot, note | P0 đúng một pickup và một dropoff |
| RideAssignments | rideId, driverId, vehicleSnapshot, acceptedAt, endedAt, endReason | Lưu lịch sử tài xế, unique active |
| DispatchAttempts | rideId, round, radius, startedAt, deadlineAt, result | Theo dõi vòng tìm |
| DriverOffers | rideId, driverId, attemptId, expiresAt, status, version | Unique open theo chính sách tuần tự |
| RideEvents | rideId, sequence, eventType, actorId, serverAt, payload | Unique ride + sequence |
| RidePinSecrets | rideId, assignmentVersion, pinHmac, attempts, lockedUntil | Không trả cho Driver API |
| FareSnapshots | rideId, policyVersion, components, gross, discount, payable, currency | Một bản chốt; điều chỉnh có lịch sử riêng |
| FareAdjustments | rideId, type, amount, status, proposer, approver, evidence | Được chấp thuận trước khi đưa vào giá cuối |
| LocationSamples | driverId, sessionId, sampleId, sequence, point, accuracy, recordedAt, receivedAt | Phân vùng theo thời gian khi có tải |
| Payments | rideId, payableAmount, paidAmount, refundedAmount, status, currency | Một nghĩa vụ chính/Ride; khoản phát sinh phân loại rõ |
| PaymentAttempts | paymentId, provider, merchantReference, providerTransactionId, amount, status | Unique merchant reference và provider ID khi có |
| CashCollections | paymentId, driverId, amount, collectedAt, operationId | Không vượt remaining amount nếu không có luồng điều chỉnh |
| ProviderInbox | provider, eventId, payloadHash, signatureResult, status | Unique provider + eventId |
| Refunds | paymentId, amount, state, requester, approver, reference | Có hold để chống hoàn vượt |
| LedgerAccounts | ownerType, ownerId, currency, accountType | Phân loại asset/liability/revenue/expense theo thiết kế kế toán |
| LedgerJournals | operationKey, postedAt, sourceType, sourceId, reversalOf | Unique operationKey; bất biến khi post |
| LedgerEntries | journalId, accountId, debitAmount, creditAmount | Tổng debit = credit trong journal |
| Settlements | driverId, period, calculatedAmount, status, version | Một khoản chỉ thuộc một kỳ chốt hiệu lực |
| Payouts | driverId, amount, destinationSnapshot, state, providerReference | Hold số dư, kiểm tra maker/checker |
| Promotions | code, conditions, budget, sponsor, version | P1; code normalize |
| PromotionReservations | campaignId, customerId, rideId, amount, state | Reserve/redeem/release có idempotency |
| Ratings | rideId, authorId, targetId, stars, tags, comment | Unique ride + author + target |
| SupportTickets | requesterId, rideId, category, priority, status, assignee | Quyền theo ticket và vùng |
| SafetyIncidents | rideId, reporterId, type, state, acknowledgedAt | Tách đã gửi và đã tiếp nhận |
| RideShareTokens | rideId, tokenHash, expiresAt, revokedAt | Không lưu token rõ nếu không cần |
| Notifications | userId, type, entityId, readAt, dedupeKey | Delivery attempt tách riêng |
| OutboxMessages | eventId, aggregateId, payload, state, nextAttemptAt | Ghi cùng transaction nghiệp vụ |
| ConsumerInbox | consumerName, eventId, processedAt | Unique consumer + eventId |
| IdempotencyRecords | actorId, operationScope, key, payloadHash, state, responseRef, expiresAt | Không chia sẻ khóa giữa hai user |
| AuditLogs | actor, action, resource, reason, beforeAfterRedacted, traceId | Append-only, kiểm soát quyền đọc |

### 16.3. Constraint và index bắt buộc

| Mục đích | Constraint/index đề xuất |
| --- | --- |
| Một active Ride/khách | Unique partial index trên `Rides(customerId)` khi status thuộc SEARCHING, ASSIGNED, DRIVER_ARRIVED, IN_PROGRESS |
| Một active Assignment/tài xế | Unique partial index `RideAssignments(driverId)` khi `endedAt IS NULL` |
| Một active Assignment/Ride | Unique partial index `RideAssignments(rideId)` khi `endedAt IS NULL` |
| Một open offer/Ride P0 | Unique partial index theo ride khi offer status OPEN |
| Một open offer/tài xế P0 | Unique partial index theo driver khi offer status OPEN |
| Quote dùng một lần | Unique `Rides(quoteId)` và ghi `consumedRideId` cùng transaction |
| Sự kiện đúng thứ tự | Unique `RideEvents(rideId, sequence)` |
| Dedupe tài chính | Unique journal operationKey, provider reference, cash operationId |
| Dedupe GPS | Unique `(driverId, sessionId, sampleId)` |
| Lịch sử khách/tài xế | Index `(customerId, createdAt DESC, id)`; Assignment `(driverId, acceptedAt DESC, id)` |
| Dispatch và job | Index status + deadline/nextAttemptAt; spatial index cho vùng và vị trí |
| Financial integrity | CHECK amount không âm khi phù hợp; FK hợp lệ; journal cân bằng được bảo vệ tại posting transaction |

Không dùng `now()` trong predicate partial index để xác định offer còn hiệu lực. TTL là điều kiện kiểm tra trong transaction; worker/lệnh tạo offer phải chuyển offer hết hạn sang trạng thái đóng trước khi cần reuse unique slot. Unique constraint là hàng rào cuối, không thay thế validation nghiệp vụ.

### 16.4. Quan hệ và lịch sử

- User có thể có CustomerProfile và DriverProfile; quyền app/phiên được kiểm soát độc lập.
- Customer có nhiều Ride lịch sử; Ride có một quote gốc, nhiều event, nhiều Assignment lịch sử, tối đa một Assignment active.
- Payment có nhiều attempt/refund/cash collection; tất cả quy về nghĩa vụ và không được thu/hoàn quá mức.
- Snapshot hồ sơ xe, điểm đón/đến và bảng giá của Ride không thay đổi khi người dùng sửa hồ sơ sau này.
- GPS latest ở Redis là projection; lịch sử cần giữ theo policy được lưu bền vững bất đồng bộ hoặc batch, với chỉ số độ trễ quan sát được.

## 17. Quy chuẩn API

### 17.1. Định dạng và phiên bản

- Base path `/api/v1`; JSON `camelCase`, UTF-8; enum public dùng chuỗi ổn định như `SEARCHING`.
- HTTPS bắt buộc ở môi trường triển khai. Auth mobile qua `Authorization: Bearer <accessToken>`.
- Thời gian ISO 8601 UTC có hậu tố `Z`; server trả `serverTime` trong response quan trọng để app tính countdown tương đối.
- Tọa độ trường rõ `latitude`/`longitude`; không đảo thứ tự trong mảng không có schema.
- Tiền gồm amount nguyên và currency; khoảng cách mét, thời lượng giây.
- Tạo tài nguyên trả `201`, query/command thành công trả `200` hoặc `204` theo OpenAPI; không bọc mọi lỗi thành HTTP 200.
- Query list dùng `cursor`, `pageSize` mặc định 20, tối đa 100; sort ổn định bằng thời gian + ID, trả `nextCursor` và `hasMore`.
- Thay đổi phá vỡ contract cần phiên bản mới hoặc kế hoạch chuyển đổi; bổ sung field phải tương thích client cũ còn hỗ trợ.

### 17.2. Idempotency và concurrency

- Bắt buộc `Idempotency-Key` với create Ride, accept offer, start/complete/cancel, cash collection, payment/refund/payout và các command tài chính.
- Scope gồm actor + operation/route + key; lưu hash payload, state xử lý và kết quả đã commit. Cùng key khác payload trả `409 IDEMPOTENCY_CONFLICT`.
- Request cùng key đang chạy không được chạy handler lần nữa; trả `409 OPERATION_IN_PROGRESS` kèm `Retry-After` hoặc kết quả cũ khi đã hoàn thành.
- Lưu record command thông thường tối thiểu 24 giờ theo cấu hình; các ràng buộc business uniqueness và reference tài chính tồn tại theo retention nghiệp vụ để retry sau TTL vẫn không thu/ghi nhận trùng.
- Lệnh thay đổi aggregate nhận `expectedVersion`; version cũ trả `409 VERSION_CONFLICT` cùng version hiện hành và yêu cầu tải snapshot.
- Idempotency check kết quả đã commit phải được xét trước khi bác bỏ expectedVersion cũ của chính request replay.
- Retry lỗi mạng giữ nguyên payload và key; thay đổi ý định/payload phải tạo thao tác mới sau khi đã xác minh kết quả trước.

### 17.3. Lỗi chuẩn

Dùng Problem Details có mở rộng `code`, `traceId`, `errors`, `currentVersion` khi cần. Message để hiển thị phù hợp; logic client dựa `code`.

| HTTP | Code ví dụ | Xử lý client |
| --- | --- | --- |
| 400 | VALIDATION_ERROR, INVALID_COORDINATES | Hiển thị lỗi trường nhập |
| 401 | UNAUTHENTICATED, SESSION_EXPIRED | Refresh một lần hoặc đăng nhập lại |
| 403 | FORBIDDEN, DRIVER_NOT_APPROVED | Không retry tự động; giải thích quyền/điều kiện |
| 404 | RESOURCE_NOT_FOUND | Không lộ tài nguyên của người khác |
| 409 | ACTIVE_RIDE_EXISTS | Mở Ride đang hoạt động |
| 409 | QUOTE_EXPIRED, QUOTE_ALREADY_USED | Lấy quote mới hoặc mở Ride đã tạo |
| 409 | VERSION_CONFLICT | Tải snapshot, yêu cầu thao tác lại nếu cần |
| 409 | OFFER_EXPIRED, OFFER_NOT_AVAILABLE | Đóng offer, tải availability |
| 409 | DRIVER_ALREADY_ASSIGNED, RIDE_ALREADY_ASSIGNED | Khôi phục trạng thái hiện hành |
| 409 | INVALID_RIDE_STATE, RIDE_CANCELED | Hiển thị trạng thái mới nhất |
| 409 | IDEMPOTENCY_CONFLICT, OPERATION_IN_PROGRESS | Không tạo thao tác trùng |
| 422 | OUTSIDE_SERVICE_ZONE, ROUTE_UNAVAILABLE | Sửa điểm/vùng hoặc thử lại tuyến |
| 422 | PAYMENT_METHOD_UNAVAILABLE, PROMOTION_NOT_APPLICABLE | Chọn lại và xác nhận quote mới |
| 422 | PIN_INVALID, LOCATION_NOT_TRUSTED | Thông báo phù hợp và hỗ trợ ngoại lệ |
| 429 | RATE_LIMITED | Đọc `Retry-After`, chặn bấm liên tục |
| 503 | DEPENDENCY_UNAVAILABLE, SERVICE_TEMPORARILY_UNAVAILABLE | Giữ input, retry có backoff |
| 500 | INTERNAL_ERROR | Hiển thị trace hỗ trợ, không lộ thông tin nội bộ |

## 18. Danh mục API

Ký hiệu: **Public** không cần phiên người dùng nhưng vẫn rate limit; **C** khách; **D** tài xế; **A** nhân sự có quyền tương ứng; **S** provider/system đã xác thực riêng. Mỗi dòng còn phải kiểm tra ownership, scope và trạng thái.

### 18.1. Định danh và cấu hình

| Method + route | Quyền | Đầu vào/kết quả chính |
| --- | --- | --- |
| POST `/auth/otp/challenges` | Public | phone, appType → challengeId, expiresAt, resendAfter |
| POST `/auth/otp/verify` | Public | challengeId, otp, device → access/refresh session |
| POST `/auth/token/refresh` | Session credential | Refresh rotation, phát hiện reuse |
| POST `/auth/logout` | C/D | Thu hồi phiên hiện tại và unbind push |
| GET `/me` | C/D/A | Hồ sơ, role, điều kiện hoạt động phù hợp scope |
| PATCH `/me/profile` | C/D | Chỉ trường hồ sơ cho phép, expectedVersion |
| POST `/me/phone-change/challenges` | C/D | Xác minh tăng cường và số mới |
| POST `/me/phone-change/confirm` | C/D | Xác nhận challenge, unique phone, thu hồi phiên theo policy |
| POST `/me/account-deletion-requests` | C/D | Tạo yêu cầu, trả trạng thái và phần nghĩa vụ cần xử lý |
| GET `/app-config?appType=...&platform=...` | Public | Min version, feature flags công khai, thông tin vùng; không có secret |
| PUT `/me/devices/{instanceId}` | C/D | Push token, nền tảng, quyền thông báo |
| DELETE `/me/devices/{instanceId}` | C/D | Unbind instance thuộc user |

### 18.2. Khách hàng, địa chỉ và đặt xe

| Method + route | Quyền | Đầu vào/kết quả chính |
| --- | --- | --- |
| GET `/service-zones/availability` | C/D | Điểm/vùng → dịch vụ đang hỗ trợ |
| GET `/places/autocomplete` | C/D | q, bias point, session token → gợi ý có giới hạn |
| GET `/places/{placeId}` | C/D | Chi tiết điểm từ provider được cho phép |
| POST `/places/reverse-geocode` | C/D | Tọa độ → địa chỉ hiển thị |
| GET/POST `/customers/me/saved-places` | C | Danh sách/tạo địa chỉ [P1] |
| PATCH/DELETE `/customers/me/saved-places/{id}` | C | Sửa/xóa địa chỉ của mình [P1] |
| POST `/quotes` | C | Pickup/dropoff, service, method, promo → quote |
| POST `/rides` | C | quoteId, note, paymentMethodId → Ride SEARCHING |
| GET `/rides/active` | C/D | Ride đang hoạt động của phiên, hoặc `ride: null` |
| GET `/rides/{rideId}` | C/D/A | Snapshot tùy vai trò; PIN chỉ trả Customer đủ quyền |
| GET `/rides` | C/D | Lịch sử của mình, cursor/filter |
| GET `/rides/{rideId}/events` | C/D/A | Timeline được lọc dữ liệu nhạy cảm |
| POST `/rides/{rideId}/cancel-preview` | C | Tính phí theo trạng thái và version hiện hành |
| POST `/rides/{rideId}/cancel` | C/A | Reason, expectedVersion, previewId nếu cần |
| GET `/rides/{rideId}/receipt` | C/D/A | Breakdown và thông tin thanh toán phù hợp quyền |
| POST `/rides/{rideId}/ratings` | C/D | Stars, tags, comment; unique theo người đánh giá |
| POST `/rides/{rideId}/share-tokens` | C | Tạo token chia sẻ có hạn |
| DELETE `/rides/{rideId}/share-tokens/{id}` | C | Thu hồi token |
| GET `/public/ride-shares/{token}` | Public token | View tối thiểu, rate limit, no indexing, hết hạn rõ ràng |
| POST `/rides/{rideId}/safety-incidents` | C/D | SOS/report, channel, location tùy quyền |

### 18.3. Tài xế

| Method + route | Quyền | Đầu vào/kết quả chính |
| --- | --- | --- |
| GET/PUT `/drivers/me/application` | D/Applicant | Xem/cập nhật hồ sơ draft |
| POST `/drivers/me/application/submit` | D/Applicant | Kiểm tra đủ hồ sơ, chuyển chờ duyệt |
| POST `/files/upload-intents` | C/D/A | Loại file, MIME, size → upload URL private giới hạn |
| POST `/files/{fileId}/complete` | Owner | Kiểm tra file thực tế/quét an toàn, xác nhận hoàn thành |
| POST `/drivers/me/documents` | D/Applicant | Gắn file đã hợp lệ vào loại giấy tờ |
| GET/POST/PATCH `/drivers/me/vehicles[/{id}]` | D/Applicant | Quản lý xe trong phạm vi được phép |
| POST `/drivers/me/availability` | D | Online/offline, offlineAfterRide, expectedVersion |
| GET `/drivers/me/availability` | D | Ý định online, busy, health và điều kiện thiếu |
| POST `/drivers/me/heartbeat` | D active device | Cập nhật presence, trả serverTime |
| POST `/drivers/me/location-batches` | D active device | Vị trí batch; trả accepted/rejected và lý do |
| GET `/drivers/me/offers/current` | D | Offer hiện hành hoặc null |
| POST `/driver-offers/{offerId}/accept` | D owner | expectedVersion → Assignment và Ride snapshot |
| POST `/driver-offers/{offerId}/reject` | D owner | Reason tùy chọn, đóng offer |
| POST `/rides/{rideId}/arrive` | Assigned D | Location evidence, expectedVersion |
| POST `/rides/{rideId}/start` | Assigned D | PIN, expectedVersion |
| POST `/rides/{rideId}/complete` | Assigned D | Vị trí, reason, expectedVersion; không nhận finalFare |
| POST `/rides/{rideId}/release-assignment` | Assigned D | Lý do; chỉ trước IN_PROGRESS |
| POST `/rides/{rideId}/no-show` | Assigned D | Kiểm tra thời gian chờ và bằng chứng liên hệ |
| POST `/rides/{rideId}/fare-adjustments` | Assigned D | Đề nghị phụ phí được hỗ trợ |
| POST `/fare-adjustments/{id}/decision` | C/A | Chấp thuận/từ chối có version |
| GET `/drivers/me/earnings` | D | Tổng hợp theo khoảng ngày, currency, timezone |
| GET `/drivers/me/settlements` | D | Kỳ đối soát của mình |
| GET `/drivers/me/balance` | D | Pending, available, held, debt |
| POST `/drivers/me/payout-requests` | D | Amount, destination; P1 |

### 18.4. Thanh toán, hỗ trợ và thông báo

| Method + route | Quyền | Đầu vào/kết quả chính |
| --- | --- | --- |
| POST `/payment-methods/setup` | C | Provider setup flow, không nhận raw card [P1] |
| GET/DELETE `/payment-methods[/{id}]` | C | Xem/gỡ phương thức của mình [P1] |
| GET `/rides/{rideId}/payment` | C/D/A | Trạng thái, payable/paid/remaining; filter token theo vai trò |
| POST `/payments/{paymentId}/attempts` | C | Thử thanh toán qua method hợp lệ [P1] |
| POST `/payments/{paymentId}/cash-collections` | Assigned D/A | Amount thực thu, operationId, reason |
| POST `/webhooks/payments/{provider}` | S | Raw payload, signature, dedupe/inbox [P1] |
| POST `/payments/{paymentId}/refund-requests` | C/A | Đề nghị hoàn, chưa phải lệnh chi tiền [P1] |
| GET/POST `/support/tickets` | C/D | Danh sách/tạo ticket của mình |
| GET `/support/tickets/{ticketId}` | Owner/A | Nội dung và timeline có quyền |
| POST `/support/tickets/{ticketId}/messages` | Owner/A | Phản hồi, attachment hợp lệ |
| GET `/notifications` | C/D | Cursor, unread filter |
| POST `/notifications/{id}/read` | Owner | Đánh dấu đã đọc |
| GET/POST `/rides/{rideId}/messages` | C/Assigned D | Chat theo quyền trong thời gian cho phép [P1] |

### 18.5. Quản trị

| Method + route | Quyền cụ thể | Yêu cầu |
| --- | --- | --- |
| GET `/admin/drivers` | DriverReviewer | Scope vùng, filter review |
| POST `/admin/drivers/{id}/review-decisions` | DriverReviewer | Kết quả, lý do, version |
| POST `/admin/users/{id}/restrictions` | Operations/Security | Loại khóa, lý do, thời hạn |
| GET `/admin/rides[/{id}]` | Dispatcher/Support | Search có scope, field masking |
| POST `/admin/rides/{id}/reassignment-requests` | Dispatcher | Trước chuyến; tạo offer mới hợp lệ |
| POST `/admin/rides/{id}/end-early` | Operations đặc quyền | Lý do, bằng chứng, policy cước |
| POST `/admin/service-zones` | OperationsAdmin | Draft polygon và quy tắc |
| POST `/admin/fare-policies` | OperationsAdmin | Tạo draft version |
| POST `/admin/fare-policies/{id}/publish` | Người duyệt được cấp | Review, effectiveAt, expectedVersion |
| GET `/admin/reconciliation/discrepancies` | FinanceOperator | Danh sách sai lệch, không sửa status trực tiếp |
| POST `/admin/cash-remittances` | FinanceOperator | Đề nghị xác nhận tài xế nộp công nợ |
| POST `/admin/cash-remittances/{id}/approve` | FinanceApprover | Khác người lập, có reference |
| POST `/admin/refunds/{id}/approve` | FinanceApprover | Hạn mức, số còn có thể hoàn |
| POST `/admin/payouts/{id}/approve` | FinanceApprover | Khác người lập, kiểm tra hold |
| GET `/admin/support/tickets` | SupportAgent | Scope và mức dữ liệu được xem |
| POST `/admin/support/tickets/{id}/transitions` | SupportAgent | State/assignee/reason theo workflow |
| POST `/admin/reports/exports` | Reporting có quyền | Job export, mục đích và phạm vi |
| GET `/admin/audit-logs` | AuditReader | Filter, pagination, hạn chế PII |

OpenAPI khi triển khai phải khai báo route cụ thể thay cho ký hiệu rút gọn `[/{id}]`, method theo từng tài nguyên, request/response schema, authorization, status code và ví dụ. Bảng này là danh mục hợp đồng nghiệp vụ, không phải file OpenAPI đã biên dịch.

## 19. Hợp đồng API mẫu

Các ID dưới đây là dữ liệu minh họa. Không chứa token/khóa thật. Ví dụ báo giá P0 không có voucher và phụ phí.

### 19.1. Tạo báo giá

`POST /api/v1/quotes`

```json
{
  "pickup": {
    "latitude": 21.0285,
    "longitude": 105.8542,
    "address": "Điểm đón do khách xác nhận"
  },
  "dropoff": {
    "latitude": 21.045,
    "longitude": 105.82,
    "address": "Điểm đến do khách xác nhận"
  },
  "serviceTypeCode": "CAR_4",
  "paymentMethodType": "CASH",
  "promotionCode": null
}
```

Response `201 Created`:

```json
{
  "quoteId": "11111111-1111-4111-8111-111111111111",
  "currency": "VND",
  "estimatedDistanceMeters": 6000,
  "estimatedDurationSeconds": 1200,
  "estimatedPickupSeconds": 300,
  "fare": {
    "baseFare": 12000,
    "distanceFare": 30000,
    "durationFare": 8000,
    "serviceFee": 0,
    "approvedExtras": 0,
    "taxComponent": 0,
    "grossFare": 50000,
    "discount": 0,
    "customerPayable": 50000
  },
  "farePolicyVersion": "ZONE_A_CAR4_001",
  "excludedCharges": ["Phí cầu đường phát sinh nếu được chấp thuận"],
  "expiresAt": "2026-11-02T03:02:00Z",
  "serverTime": "2026-11-02T03:00:00Z"
}
```

ETA chỉ là ước tính, không giữ tài xế. Khoảng cách và thời gian trong ví dụ được mô phỏng, không phải kết quả truy vấn tuyến của các tọa độ trên.

### 19.2. Tạo Ride

`POST /api/v1/rides`, header `Idempotency-Key: demo-create-ride-001`.

```json
{
  "quoteId": "11111111-1111-4111-8111-111111111111",
  "pickupNote": "Tôi đứng tại cổng chính",
  "paymentMethodId": null
}
```

Response `201 Created`:

```json
{
  "rideId": "22222222-2222-4222-8222-222222222222",
  "rideCode": "GR2611020001",
  "status": "SEARCHING",
  "version": 1,
  "paymentMethodType": "CASH",
  "fare": { "customerPayable": 50000, "currency": "VND" },
  "dispatchDeadlineAt": "2026-11-02T03:02:20Z",
  "serverTime": "2026-11-02T03:00:20Z"
}
```

Khách hàng được xác định từ token, không nhận `customerId` tùy ý trong payload. Quote đã gắn payment method type; `paymentMethodId` chỉ dùng khi phương thức cần định danh cụ thể và phải khớp quote.

### 19.3. Nhận offer và bắt đầu chuyến

`POST /api/v1/driver-offers/{offerId}/accept`, có idempotency:

```json
{
  "expectedVersion": 1
}
```

Server trả `assignmentId`, Ride snapshot với version mới và quyền thao tác được phép. Không trả mã PIN trong snapshot tài xế.

`POST /api/v1/rides/{rideId}/start`, có idempotency:

```json
{
  "expectedVersion": 3,
  "pickupPin": "3826"
}
```

Server chỉ chuyển sang `IN_PROGRESS` khi Ride đang `DRIVER_ARRIVED`, PIN hợp lệ và người gửi là tài xế hiện hành.

### 19.4. Hoàn tất và thu tiền mặt

`POST /api/v1/rides/{rideId}/complete`, có idempotency:

```json
{
  "expectedVersion": 4,
  "completionType": "NORMAL",
  "location": {
    "latitude": 21.045,
    "longitude": 105.82,
    "accuracyMeters": 18,
    "recordedAt": "2026-11-02T03:30:00Z"
  },
  "reasonCode": null
}
```

Response trả Ride `COMPLETED`, version mới, `paymentId`, số phải thu và payment status. Sau đó tài xế gọi command riêng:

`POST /api/v1/payments/{paymentId}/cash-collections`, có idempotency:

```json
{
  "operationId": "33333333-3333-4333-8333-333333333333",
  "collectedAmount": 50000,
  "currency": "VND",
  "reasonCode": "FULL_AMOUNT_RECEIVED"
}
```

Nếu app retry hoàn tất hoặc thu tiền sau mất response, server trả kết quả đã commit; không tạo RideEvent hay journal thứ hai.

### 19.5. Response lỗi

```json
{
  "type": "urn:grap:problem:version-conflict",
  "title": "Trạng thái chuyến đã thay đổi",
  "status": 409,
  "code": "VERSION_CONFLICT",
  "detail": "Vui lòng tải lại thông tin chuyến trước khi tiếp tục.",
  "traceId": "demo-trace-0001",
  "currentVersion": 5,
  "errors": {}
}
```

### 19.6. Kết quả phân trang

```json
{
  "items": [],
  "nextCursor": null,
  "hasMore": false,
  "serverTime": "2026-11-02T04:00:00Z"
}
```

## 20. Hợp đồng sự kiện và SignalR

### 20.1. Hub và quyền nhóm

Đề xuất endpoint `/hubs/rides`, `/hubs/driver`, `/hubs/notifications`. Có thể gộp về một hub khi MVP nếu vẫn tách quyền và event contract.

| Group logic | Thành viên | Quy tắc |
| --- | --- | --- |
| `user:{userId}` | Các phiên hợp lệ của chính user | Server lấy user ID từ phiên |
| `driver:{driverId}:{deviceSessionId}` | Phiên nhận chuyến đang active | Thiết bị cũ bị thu hồi không tiếp tục nhận offer |
| `ride:{rideId}:customer` | Khách của Ride | Có PIN chỉ qua API riêng đủ quyền, không phát chung group |
| `ride:{rideId}:assignment:{assignmentId}` | Tài xế của Assignment active | Khi thay tài xế phải revoke ngay |
| `ops:{zoneId}` | Nhân sự có scope vùng | Không tự join theo input mà bỏ qua authorization |

Client chỉ yêu cầu theo dõi tài nguyên; server tự xác định group sau kiểm tra quyền. Group name không phải cơ chế bảo mật. Khi phiên bị khóa/thu hồi, hệ thống phải ngắt hoặc vô hiệu quyền connection, không chỉ đợi token hết hạn.

### 20.2. Sự kiện public

| Event | Người nhận | Dữ liệu chính |
| --- | --- | --- |
| `ride.status.changed` | Customer, assigned Driver, Ops | rideId, version, status, reason được phép |
| `ride.driver.assigned` | Customer, Driver được nhận | assignmentId, hồ sơ xe/tài xế theo quyền |
| `ride.assignment.released` | Hai bên liên quan | assignmentId cũ, trạng thái mới |
| `driver.offer.created` | Active Driver device | offerId, rideId, expiresAt, preview |
| `driver.offer.closed` | Driver nhận offer | offerId, accepted/expired/rejected/revoked |
| `ride.driver.location.updated` | Customer và Ops đủ quyền | assignmentId, location sequence, recordedAt, accuracy |
| `ride.fare.adjustment.requested` | Customer/Ops | adjustmentId, lý do và amount |
| `ride.fare.adjustment.decided` | Hai bên | adjustmentId, kết quả, fare version |
| `payment.status.changed` | Customer, Driver giới hạn, Finance | paymentId, status, paid/remaining |
| `support.ticket.updated` | Owner và nhân sự phụ trách | ticketId, trạng thái, có phản hồi mới |
| `safety.incident.acknowledged` | Người báo cáo | incidentId, timestamp được tiếp nhận |
| `notification.created` | User | notificationId, type, entityId |

### 20.3. Event envelope

```json
{
  "eventId": "44444444-4444-4444-8444-444444444444",
  "eventType": "ride.status.changed",
  "schemaVersion": 1,
  "occurredAt": "2026-11-02T03:01:00Z",
  "aggregateType": "Ride",
  "aggregateId": "22222222-2222-4222-8222-222222222222",
  "aggregateVersion": 2,
  "correlationId": "demo-create-ride-001",
  "data": {
    "status": "ASSIGNED",
    "assignmentId": "55555555-5555-4555-8555-555555555555"
  }
}
```

Các event GPS dùng `locationSequence` và `deviceSessionId` riêng; không tăng Ride aggregate version mỗi 3–5 giây. Consumer phân biệt luồng lifecycle, payment và GPS để không áp dụng quy tắc version sai.

### 20.4. Outbox, retry và dead letter

- Outbox ghi event ID ổn định cùng transaction. Dispatcher claim một batch bằng khóa/lease; với PostgreSQL có thể dùng `FOR UPDATE SKIP LOCKED` phù hợp worker queue.
- Đánh dấu published sau khi đích nhận thành công. Crash ở giữa có thể gây phát lại, nên consumer phải dedupe.
- Retry exponential backoff có jitter, ví dụ 1–2–4–8–16–30 giây rồi giãn thêm; giới hạn theo loại sự kiện. Offer hết hạn không gửi tiếp thông báo còn hiệu lực giả.
- Sự kiện lỗi quá ngưỡng chuyển dead-letter; alert kèm event ID, trace và mã lỗi được che dữ liệu nhạy cảm.
- Replay qua công cụ có quyền, có audit và dùng lại event ID; không sửa payload để phá idempotency của dữ liệu tài chính.

## 21. Bảo mật và bảo vệ dữ liệu

### 21.1. Xác thực và kiểm soát truy cập

- Access token thời hạn ngắn, khởi tạo đề xuất 15 phút; refresh session tối đa đề xuất 30 ngày với idle timeout và rotation. Các giá trị phải thống nhất với mô hình rủi ro.
- Refresh token lưu hash phía server; token reuse thu hồi token family theo policy. Khóa tài khoản phải tác động API và realtime đang hoạt động.
- Admin dùng MFA và xác thực tăng cường cho cấp quyền, xuất PII, đổi tài khoản nhận tiền và duyệt chi.
- Authorize ở application/resource level; lọc query theo chủ sở hữu/vùng. Kiểm thử thay ID của khách/tài xế khác để phát hiện IDOR/BOLA.
- Không nhận `driverId`, `customerId`, `role`, `approved`, `balance`, `fare` tùy ý trong payload khi chúng phải được suy ra từ phiên/nghiệp vụ.
- Hạn chế SignalR token nếu transport dùng query string: TLS, log redaction, phạm vi endpoint rõ và cơ chế ngắt khi revoke.
- Web Admin dùng cookie phải có CSRF protection cho command; CORS theo allowlist, không bật wildcard kèm credentials.

### 21.2. Bảo vệ dữ liệu và file

- Mã hóa đường truyền và dữ liệu lưu trữ theo hạ tầng; khóa mã hóa và secret nằm trong secret manager, có rotation và audit truy cập.
- OTP, PIN, refresh token, thông tin tài khoản nhận tiền, giấy tờ định danh và tuyến GPS không xuất ra log thông thường.
- File upload đi qua upload intent giới hạn loại/dung lượng, kiểm tra nội dung thật, quét file độc hại khi phù hợp; không tin filename/MIME client.
- File không public; URL tải có hạn ngắn và kiểm tra quyền trước khi cấp. Đề xuất URL giấy tờ tối đa 5 phút.
- Upload chưa hoàn thành không được gắn vào hồ sơ đã duyệt. Object storage key không được client tùy ý chỉ đến file user khác.
- Không phục vụ file upload như HTML/script từ cùng origin tin cậy của Admin; thiết lập content disposition và loại nội dung phù hợp.
- Log dữ liệu tìm kiếm địa chỉ và GPS chỉ ở mức cần để vận hành; quyền đọc lịch sử chi tiết được audit.

### 21.3. Chấp thuận và vòng đời dữ liệu

| Dữ liệu | Chính sách thiết kế đề xuất | Cần chốt trước phát hành |
| --- | --- | --- |
| GPS chi tiết | Giữ ngắn hạn, khởi tạo 30 ngày; sau đó xóa/giảm độ chi tiết nếu không có hold hợp lệ | Thời hạn theo mục đích, nghĩa vụ và xử lý tranh chấp |
| Latest location/presence | TTL ngắn; không tiếp tục public sau hết quyền | TTL và ai được xem |
| OTP/PIN | Xóa/hết hiệu lực sau cửa sổ bảo mật; audit không lưu mã rõ | Thời hạn record tối thiểu phục vụ chống lạm dụng |
| Hồ sơ/giấy tờ | Theo thời gian hợp tác và yêu cầu lưu trữ đã xác nhận | Retention từng loại, quyền truy cập và yêu cầu xóa |
| Ride/biên nhận/ledger | Theo nghĩa vụ vận hành, tài chính và tranh chấp | Thời hạn được kế toán/pháp chế phê duyệt |
| Ticket/chat | Theo loại vấn đề và mục đích hỗ trợ | Retention, legal hold, hạn file đính kèm |
| Backup | Hết hạn theo lịch, bảo vệ tương đương dữ liệu gốc | Thời hạn và xử lý yêu cầu xóa khi phục hồi |

- Lưu consent theo version văn bản và mục đích. Quyền vị trí của hệ điều hành không thay thế toàn bộ việc giải thích mục đích xử lý dữ liệu.
- Người dùng có luồng yêu cầu xem/xuất/sửa/xóa dữ liệu cá nhân theo quy trình được phê duyệt.
- Khi yêu cầu xóa tài khoản có nghĩa vụ chưa hoàn tất, trả trạng thái xử lý rõ ràng. Chỉ giữ phần được phép/cần thiết, tách PII khỏi dữ liệu phải giữ khi khả thi.
- Legal hold phải có lý do, người chịu trách nhiệm và thời hạn review; không giữ vô hạn mặc định.
- Khi phục hồi backup, áp lại danh sách xóa/ẩn danh/thu hồi đã có để không vô tình hồi sinh dữ liệu và phiên.

### 21.4. Chống lạm dụng

- Rate limit OTP, login, autocomplete, quotes, create/cancel Ride, PIN, share token, chat và export theo risk profile.
- Giới hạn tổng ngân sách SMS/bản đồ; alert khi tăng bất thường. Cân nhắc challenge bổ sung khi có dấu hiệu tự động hóa.
- Theo dõi hành vi tạo/hủy hàng loạt, tài xế/khách tự tạo chuyến, GPS bất thường, nhận thưởng trùng và abuse voucher.
- Chặn/rà soát dựa nhiều tín hiệu; lưu reason và cơ chế xử lý khiếu nại.
- Quét dependency, secret scan, review quyền SDK và kiểm tra cấu hình TLS trước phát hành.

## 22. Yêu cầu phi chức năng

### 22.1. Mô hình tải để thiết kế

Các số dưới đây là giả định capacity cho bài kiểm thử P0, cần thay bằng kế hoạch kinh doanh thực tế:

| Thông số | Mục tiêu giả định | Ý nghĩa |
| --- | ---: | --- |
| Tài xế online đồng thời | 2.000 | Một vùng pilot có thể điều chỉnh |
| Ride đang di chuyển đồng thời | 500 | GPS 5 giây/lần tương đương khoảng 100 sample/s riêng nhóm này |
| Ride creation peak | 10 request/s | Phân biệt request replay và Ride mới |
| REST business traffic peak | 200 request/s, chưa gồm GPS | Load mix phải mô phỏng cả read/write |
| SignalR connections | 5.000 | Khách + tài xế + vận hành |
| Tổng GPS ingest để kiểm thử | 300 sample/s sustained; burst 2x | Bao gồm online chờ chuyến và batch reconnect |

Không suy ra cấu hình máy chủ từ số user đăng ký. Cần đo DB lock, route provider latency, fan-out realtime, socket memory, storage GPS và chi phí gọi provider dưới load mix thực.

### 22.2. SLO và ngưỡng nghiệm thu đề xuất

| Mã | Chỉ tiêu | Mục tiêu/điều kiện đo |
| --- | --- | --- |
| NFR-01 | REST query thông thường | p95 < 500 ms ở tải giả định; không gồm thời gian truyền mạng thiết bị |
| NFR-02 | Lệnh trạng thái Ride | p95 < 1.000 ms, correctness bắt buộc kể cả khi chậm |
| NFR-03 | Báo giá | p95 < 2.500 ms khi provider đáp ứng; đo riêng latency nhà cung cấp |
| NFR-04 | Phát sự kiện lifecycle | p95 < 2 giây từ DB commit đến client test đang kết nối |
| NFR-05 | GPS hiển thị | p95 < 10 giây trên mạng/thiết bị test đủ điều kiện; có chỉ số tuổi dữ liệu |
| NFR-06 | Availability backend | SLO khởi tạo 99,9%/tháng; định nghĩa cách đo và maintenance trước vận hành |
| NFR-07 | Tính nhất quán | 0 nhận trùng, 0 journal mất cân bằng, 0 thu/hoàn/chi trùng trong kiểm thử đồng thời |
| NFR-08 | Recovery | Mục tiêu RPO ≤ 5 phút, RTO ≤ 60 phút, cần chứng minh bằng diễn tập |
| NFR-09 | App stability | Crash-free sessions ≥ 99,5% trên bản pilot có đủ số mẫu |
| NFR-10 | Bảo mật | Không còn lỗi mức nghiêm trọng/cao trong phạm vi review trước production |
| NFR-11 | Khả năng truy cập | Font scaling, contrast, screen reader cho luồng chính, không dùng màu làm tín hiệu duy nhất |
| NFR-12 | Pin và tracking | Có đo thực tế ít nhất 60 phút online và 60 phút chuyến trên ma trận thiết bị; ngưỡng pin cần chốt |

SLO latency được đo ở tải và môi trường xác định, không phải cam kết cho mọi mạng di động hoặc trạng thái hệ điều hành. Việc ghép xe thành công còn phụ thuộc cung xe; tỉ lệ ghép là KPI sản phẩm, không thể chỉ bảo đảm bằng latency API.

### 22.3. Khả năng mở rộng và tương thích

- API stateless để tăng replica; không lưu active Ride hoặc idempotency chỉ trong RAM tiến trình.
- Khi nhiều instance SignalR, chọn backplane/managed hub và cấu hình load balancer theo transport; kiểm thử reconnect, quyền group và fan-out thực tế.
- Scale worker riêng, phân chia dispatch theo Ride/zone khi cần, giữ guard DB cho cạnh tranh.
- GPS partition/retention và batch write để không làm chậm transaction nhận chuyến. Cache báo cáo và đọc từ projection khi phù hợp.
- Hỗ trợ ít nhất bản app hiện hành và bản liền trước trong cửa sổ chuyển đổi được công bố. API/client có feature flag và min version an toàn.
- Phiên bản Flutter/Dart/Riverpod, .NET/EF Core, target/min SDK Android/iOS, DB và plugin native phải khóa bằng quyết định dự án khi bắt đầu. Không coi tài liệu này là danh sách phiên bản mới nhất.

## 23. Triển khai, vận hành và khôi phục

### 23.1. Môi trường

| Môi trường | Dữ liệu | Tích hợp |
| --- | --- | --- |
| Local | Seed tổng hợp, giả lập vị trí, OTP stub | Fake adapters/sandbox; không có khóa production |
| Development | Tài khoản thử riêng | Provider test, push app dev |
| Staging/UAT | Dữ liệu mô phỏng hoặc đã ẩn danh | Sandbox, cấu hình gần production |
| Production | Dữ liệu thật được cấp quyền | Provider thật, secret tách biệt, giám sát đầy đủ |

- Mobile có flavor dev/staging/prod với application ID/bundle ID, API base URL, push config và map key riêng.
- Backend container hóa nếu hạ tầng phù hợp; tách tiến trình API, Worker và migration job.
- Secret không commit vào repo; giá trị cấu hình nhạy cảm không được trả trong app config công khai.
- Mỗi release có version, commit SHA, migration version và feature flag đi kèm để truy vết.

### 23.2. CI/CD

1. Kiểm tra định dạng, static analysis, dependency/secret scan.
2. Chạy unit test domain/use case, integration test DB thật phù hợp, contract test API/event và kiểm thử mobile liên quan.
3. Build backend và hai app; khóa dependency, signing asset lấy từ kho bảo mật.
4. Kiểm tra migration theo chiến lược expand → migrate/backfill → contract. Không xóa cột đang được bản app/backend cũ dùng trong cùng đợt rollout.
5. Deploy staging, smoke test đặt/nhận/bắt đầu/hoàn tất, cash ledger và quyền truy cập.
6. Deploy theo canary/rolling có health check; feature P1 có thể bật theo vùng hoặc nhóm test.
7. Theo dõi error rate, dispatch lag, outbox lag, payment discrepancy và rollback khi vượt ngưỡng.

Rollback code không tự đảo ngược giao dịch tiền. Migration phá hủy dữ liệu cần kế hoạch riêng; nếu schema mới chưa backward compatible, không rollback binary mù quáng.

### 23.3. Observability

| Nhóm | Chỉ số/log cần theo dõi |
| --- | --- |
| API | RPS, p50/p95/p99, 4xx/5xx, rate limit, dependency latency |
| Dispatch | Time-to-first-offer, time-to-assignment, tỷ lệ reject/timeout/no-driver, contention |
| Ride | Số active theo trạng thái, Ride stuck, assignment inconsistency |
| GPS | Ingest rate, age latest, dropped/rejected sample, driver stale |
| Realtime | Connection count, reconnect rate, fan-out lag, delivery error |
| Worker | Queue length, oldest pending age, retry, dead-letter, lease lost |
| Payments | Unknown/processing quá hạn, webhook lag, duplicate, provider mismatch |
| Finance | Ledger imbalance (bắt buộc 0), projection mismatch, cash debt, payout unknown |
| Mobile | Crash, command timeout, refresh failure, tracking stopped, pin usage không chứa mã |
| Cost | SMS, map route/search calls, storage, egress, provider fee |

Trace liên kết request → handler → transaction → outbox → worker → provider theo correlation ID. Không dùng PII làm metric label; tránh cardinality cao như mọi ride ID trong time-series label.

### 23.4. Runbook tối thiểu

- **Không ghép xe:** kiểm tra vùng/giá, eligible drivers, location age, offer lease, worker backlog và quota bản đồ; không sửa DB để ép ghép.
- **GPS ngừng:** phân biệt lỗi permission/device, ingest API, Redis và fan-out; giữ Assignment, cảnh báo và liên hệ theo quy trình.
- **Provider thanh toán lỗi:** tắt tạo attempt mới bằng flag nếu cần, giữ unknown, chạy query/reconcile; không chuyển sang tiền mặt khi giao dịch cũ chưa rõ mà không có quy trình.
- **Outbox/DLQ tồn đọng:** xác định schema/error, sửa consumer, replay có audit và dedupe; không tạo event ID mới cho cùng hiệu ứng tài chính.
- **Khôi phục Redis:** dựng lại presence từ heartbeat và DB; offer đã accepted phải khôi phục từ Assignment, không coi mọi driver là rảnh.
- **Khôi phục DB:** phục hồi point-in-time, kiểm tra journal, active Ride/Assignment, idempotency và provider reference; đồng bộ lại giao dịch ngoài DB sau điểm khôi phục trước khi mở thu/chi.
- **Rò rỉ credential:** thu hồi/rotate, khóa scope liên quan, hủy phiên cần thiết và kiểm tra audit; không chỉ xóa secret khỏi commit mới.

### 23.5. Backup và diễn tập

- Backup DB mã hóa, kiểm tra khả năng point-in-time recovery; lưu ở miền lỗi phù hợp và giới hạn quyền.
- Backup object storage/giấy tờ theo nhu cầu phục hồi, version/retention rõ; bảo vệ truy cập tương đương production.
- Diễn tập restore ít nhất theo chu kỳ được chốt; đo RPO/RTO thực tế, kiểm chứng API, ledger, file và các phiên bị thu hồi.
- Nếu phục hồi về trước một giao dịch provider đã thành công, reconciliation phải tìm lại giao dịch đó trước khi cho retry charge/payout.

## 24. Kiểm thử và tiêu chí nghiệm thu

### 24.1. Chiến lược kiểm thử

| Lớp kiểm thử | Phạm vi cần chứng minh |
| --- | --- |
| Domain unit | State transition, eligibility, fare rounding, commission base, promo budget và invariant tiền |
| Application unit | Quyền, use case, lỗi provider, idempotency decision và concurrency handling |
| Backend integration | Transaction/constraint với PostgreSQL thật, spatial query, outbox/inbox và migration |
| Contract | OpenAPI request/response, enum/time/money, Problem Details và event schema |
| Flutter provider | Override dependency, state loading/success/error, command retry và dispose |
| Flutter widget | Render trạng thái, validation, disabled command, recovery UI và accessibility |
| End-to-end | Hai app + API + worker + admin thực hiện trọn vòng đời |
| Load/concurrency | Nhận trùng, cancel/start race, tạo Ride song song, webhook replay, double payout |
| Device/system | Background GPS, tắt màn hình, battery saver, revoke permission, process killed, deep link |
| Security | Ownership, upload, role escalation, token revoke, PIN brute force và signed webhook |
| Recovery | Restart worker/API, Redis loss, DB restore và provider reconciliation |

Không chỉ mock DB trong bài kiểm thử chống nhận trùng: phải chứng minh constraint/transaction trên engine DB mục tiêu.

### 24.2. Bộ kịch bản nghiệm thu chính

| ID | Kịch bản | Kết quả bắt buộc |
| --- | --- | --- |
| AT-01 | Khách đăng nhập OTP đúng/sai/hết hạn | Chỉ mã đúng, còn hạn và chưa dùng tạo được phiên |
| AT-02 | Khách từ chối GPS | Vẫn nhập điểm đón/đến thủ công được |
| AT-03 | Quote hết hạn hoặc thuộc user khác | Không tạo Ride, trả code rõ |
| AT-04 | Quote policy mới publish giữa xem và tạo Ride | Quote còn hạn vẫn theo version đã hứa hoặc yêu cầu xác nhận mới theo policy đã công bố |
| AT-05 | 20 request tạo Ride cùng idempotency key | Một Ride và một kết quả nghiệp vụ |
| AT-06 | Hai key khác nhau tạo đồng thời cho một khách | Tối đa một Ride active |
| AT-07 | Nhiều tài xế nhận cùng Ride | Chỉ một Assignment active, một người thắng |
| AT-08 | Một tài xế nhận hai Ride đồng thời | Chỉ một Ride gắn tài xế; Ride còn lại tiếp tục tìm |
| AT-09 | Nhận offer hết hạn/push đến muộn | Không có Assignment mới |
| AT-10 | Hủy và Accept đồng thời | Một thứ tự commit hợp lệ, không Ride bị hủy vẫn có Assignment active |
| AT-11 | Start và Cancel đồng thời | Một chuyển trạng thái thắng; không thu phí hủy kèm chuyến do race |
| AT-12 | PIN sai nhiều lần hoặc tài xế cũ dùng PIN | Bị chặn, không chuyển IN_PROGRESS |
| AT-13 | Tài xế nhấn đến nơi xa điểm đón | Yêu cầu vị trí/ngoại lệ có lý do, không bỏ qua kiểm tra |
| AT-14 | Tài xế rời Assignment trước bắt đầu | Assignment cũ đóng; khách thấy tài xế mới khi có; không nhân đôi Ride |
| AT-15 | GPS/heartbeat mất khi đang chở | Giữ Ride/Assignment; thông báo dữ liệu cũ, không giao chuyến khác cho driver |
| AT-16 | App bị kill và mở lại | Khôi phục đúng active Ride, version và quyền |
| AT-17 | Complete commit nhưng mất response | Retry cùng key trả kết quả cũ, chỉ một completion event |
| AT-18 | Tiền mặt thu đủ | Payment đủ tiền, ledger cân bằng, không cộng trùng số được rút |
| AT-19 | Tiền mặt thu thiếu/chưa thu | Có remaining/debt/dispute phù hợp, Ride vẫn kết thúc đúng |
| AT-20 | Retry cash collection cùng operationId | Không ghi hai lần khoản thu/journal |
| AT-21 | Voucher nền tảng 5.000 đ trong ví dụ 60.000 đ | Khách trả 55.000 đ, entitlement tài xế 50.000 đ, đúng bù trừ tiền mặt |
| AT-22 | Hai người redeem lượt voucher/ngân sách cuối cùng | Không dùng vượt ngân sách/giới hạn |
| AT-23 | Webhook giả chữ ký/sai amount/currency | Không ghi payment succeeded; audit/cảnh báo phù hợp |
| AT-24 | Webhook lặp hoặc đảo thứ tự | Một hiệu ứng tài chính, không lùi trạng thái thành công sai |
| AT-25 | Payment timeout nhưng provider đã thu | Query/reconcile tìm lại kết quả, không tạo charge thứ hai |
| AT-26 | Hai lệnh refund/payout dùng cùng số dư | Không hoàn vượt tiền hoặc chi vượt available |
| AT-27 | Maker tự approve refund/payout của mình | Bị từ chối theo policy phân tách nhiệm vụ |
| AT-28 | Khách/tài xế đổi rideId của người khác | Không đọc/thao tác được; không lộ PIN/GPS/PII |
| AT-29 | Tài xế cũ sau reassignment còn hub connection | Không nhận GPS/chat/quyền thao tác của Assignment mới |
| AT-30 | Redis mất và khởi động lại | Không mất Ride/Payment, không coi driver ON_RIDE là rảnh |
| AT-31 | Worker crash sau publish trước đánh dấu | Event phát lại không gây side effect trùng |
| AT-32 | OTP/PIN brute force và autocomplete spam | Rate limit và giới hạn chi phí hoạt động, không lộ mã trong log |
| AT-33 | Link chia sẻ hết hạn/thu hồi/chuyến kết thúc | Không tiếp tục lộ vị trí trực tiếp |
| AT-34 | SOS khi offline | Hiển thị chưa gửi được; phương án liên hệ hệ điều hành còn truy cập được |
| AT-35 | File upload giả MIME/quá lớn/không thuộc user | Không gắn vào hồ sơ, không tải public |
| AT-36 | Khóa driver/giấy tờ hết hạn giữa chuyến | Chặn chuyến mới, không tự kết thúc chuyến đang chạy |
| AT-37 | Logout rồi đăng nhập tài khoản khác | Cache/socket/push binding cũ không lộ dữ liệu |
| AT-38 | Restore DB trước một giao dịch provider thành công | Reconcile phục hồi reference trước khi thu/chi lại |
| AT-39 | Deadline worker chạy cùng Accept | Ride terminal không bị worker ghi đè thành trạng thái mâu thuẫn |
| AT-40 | GPS batch cũ gửi sau reconnect | Latest marker không lùi về sample cũ |

### 24.3. Ma trận truy vết nhóm yêu cầu

| Nhóm yêu cầu | Chương/ID liên quan | Bộ nghiệm thu trọng tâm | Giai đoạn |
| --- | --- | --- | --- |
| Auth/profile | C-FR-01/02, D-FR-01, chương 21 | AT-01/28/32/35/37 | P0; saved places P1 |
| Địa chỉ/quote | C-FR-03/04, chương 12/14 | AT-02/03/04 | P0 |
| Đặt và ghép xe | C-FR-05, D-FR-02/03, chương 10/11 | AT-05 đến AT-11, AT-39 | P0 |
| Thực hiện chuyến | C-FR-06/07, D-FR-04 đến D-FR-07 | AT-12 đến AT-17, AT-29/36/40 | P0 |
| Tiền mặt/thu nhập | C-FR-08, D-FR-08, chương 13 | AT-18/19/20/26/27 | P0; self-service payout P1 |
| Gateway/voucher/refund | Chương 12/13 | AT-21 đến AT-27 | P1 |
| Safety/support | C-FR-09, A-FR-08 | AT-28/33/34 | P0; chat/masking P1 |
| Ops/security/recovery | Chương 9/21/23 | AT-27 đến AT-40 theo phạm vi | P0 và kiểm lại khi P1 |

### 24.4. Điều kiện hoàn thành P0

- Chạy trọn kịch bản hai app thật: khách đặt → tài xế nhận → đến nơi → PIN → bắt đầu → hoàn tất → thu tiền mặt → xem thu nhập/đối soát.
- Chạy trọn nhánh không có xe, hủy, no-show, thay tài xế, mất mạng và khôi phục.
- Các bài kiểm thử P0 về nhận trùng, sai quyền, tiền mặt, ledger và replay phải đạt; không chấp nhận dùng thao tác sửa DB để hoàn tất demo.
- Có cấu hình vùng/giá/giấy tờ, admin tối thiểu, monitoring, backup đã restore thử và runbook xử lý sự cố.
- Các tính năng P1/P2 chưa triển khai phải được tắt ở API/UI/flag; không hiển thị luồng thanh toán, hoàn tiền hoặc promo giả hoạt động.
- Ma trận thiết bị có ít nhất Android/iOS mục tiêu, máy cấu hình thấp trong phạm vi hỗ trợ và kiểm thử tracking thực tế khi màn hình tắt.
- Các quyết định chính sách trước launch tại chương 27 được chốt, tài liệu điều khoản/quyền riêng tư khớp tính năng thực tế.

## 25. Backlog và lộ trình

### 25.1. Phân rã epic

| Epic | Kết quả bàn giao | Phụ thuộc | Ưu tiên |
| --- | --- | --- | --- |
| E01 Foundation | Repo, flavor, CI, Clean Architecture, design system, lỗi chuẩn, logging | Chốt stack/toolchain | P0 |
| E02 Identity | OTP, token, session, quyền/scope, hồ sơ hai app | E01, SMS adapter | P0 |
| E03 Driver onboarding | File private, giấy tờ, xe, admin duyệt, eligibility | E02, object storage | P0 |
| E04 Maps/catalog/pricing | Vùng, dịch vụ, tìm địa chỉ, route, quote có version | E01/E02, map provider | P0 |
| E05 Ride core | Aggregate, state machine, constraints, idempotency, events | E02/E04 | P0 |
| E06 Dispatch | Candidate, reservation, offer, Accept transaction, deadline | E03/E05, location ingest | P0 |
| E07 Tracking/realtime | GPS, presence, hub, push, recovery stream | E02/E05/E06 | P0 |
| E08 Ride mobile flows | UI hai app, PIN, arrive/start/complete/cancel, recovery | E05/E06/E07 | P0 |
| E09 Cash/finance | Payment cash, ledger, entitlement, debt, settlement view | E05/E08 | P0 |
| E10 Ops/safety/support | Console, ticket, SOS, chia sẻ, rating, audit | E02/E05/E07 | P0 |
| E11 Hardening/pilot | E2E, load, security, device/background, restore và runbook | E01–E10 | P0 |
| E12 Online payment | Provider adapter, setup/charge/webhook/query/refund | E09, provider contract | P1 |
| E13 Promotions/payout | Budget reservation, sponsor, reward, payout approvals | E09/E12 khi liên quan | P1 |
| E14 Advanced services | Scheduled/multi-stop/enterprise/đội xe | Dữ liệu pilot và đặc tả riêng | P2 |

### 25.2. Mốc nghiệm thu theo phụ thuộc

1. **M0 — Chốt thiết kế:** kiến trúc, phiên bản toolchain, OpenAPI phần lõi, schema và policy pilot.
2. **M1 — Định danh và đủ điều kiện:** hai app đăng nhập được, tài xế nộp hồ sơ, admin duyệt, vùng và dịch vụ hoạt động.
3. **M2 — Đặt và nhận chuyến:** quote → Ride → dispatch → accept trên hai thiết bị; chứng minh chống nhận trùng.
4. **M3 — Thực hiện hoàn chỉnh:** vị trí, arrive, PIN, start, complete, cash, ledger, lịch sử và thu nhập.
5. **M4 — Pilot P0:** safety/support, mất mạng, background, load/security/recovery đạt tiêu chí.
6. **M5 — P1:** gateway/voucher/payout được nghiệm thu với sandbox và đối soát end-to-end trước bật thật.

Không gán thời gian hay số lập trình viên khi chưa biết đội ngũ, giao diện, provider và phạm vi vùng. Ước lượng sau khi phân rã từng epic thành user story và đo năng lực thực hiện.

### 25.3. Mẫu user story để chuyển backlog

**US-RIDE-ACCEPT:** Với vai trò tài xế đã duyệt và đang online, tôi muốn nhận một offer còn hạn để được giao chuyến và xem thông tin đón khách.

- Given tài xế không có active Assignment và offer thuộc phiên hợp lệ, When nhận trước deadline, Then server tạo đúng một Assignment và trả Ride ASSIGNED.
- Given Ride đã hủy/đã gán hoặc offer hết hạn, When nhận, Then không tạo Assignment và trả mã nghiệp vụ tương ứng.
- Given response bị mất sau commit, When retry cùng key, Then trả kết quả nhận ban đầu.
- Given hai request nhận cạnh tranh, Then invariants một Ride/một tài xế active vẫn được bảo vệ tại DB.
- Done khi API contract, app state, audit/outbox, integration concurrency test và recovery UI đều có bằng chứng đạt.

## 26. Quy tắc phát triển và bàn giao

### 26.1. Quy tắc triển khai Flutter

- Đọc quy ước kiến trúc trong repo trước khi tạo feature; nếu cấu trúc repo khác đề xuất này, cập nhật quyết định kiến trúc và map lớp rõ ràng.
- Screen chỉ xử lý hiển thị/tương tác; HTTP, parsing, cache và rule dùng use case/repository/datasource đúng lớp.
- Không trộn thêm Bloc/GetX/ChangeNotifier làm state chính trong feature Riverpod nếu không có quyết định được ghi nhận.
- Widget nhỏ theo trách nhiệm, text trong localization, theme/design token tập trung, không hard-code route/API key/giá.
- Tránh một `services.dart`/`providers.dart` khổng lồ cho toàn bộ app. Đặt provider theo module và wiring tại composition root.
- Khi sửa active ride, luôn xét nguồn event, version, reconnect và quyền tài khoản; không chỉ kiểm tra happy path.
- Không vô hiệu xác thực chứng chỉ HTTPS trong bản release.

### 26.2. Quy tắc triển khai C#

- Controller mỏng, use case rõ; entity không phải DTO public; mapping và validation có nơi sở hữu.
- Dùng async I/O, truyền CancellationToken khi phù hợp; không kéo dài transaction vì tác vụ bên ngoài.
- Mọi query danh sách có phân trang, giới hạn và index phù hợp; tránh N+1 và tải GPS toàn lịch sử lên RAM.
- Mọi command tiền/chuyến phải xác định transaction boundary, concurrency token, idempotency và outbox nếu có event.
- Không cập nhật tiền bằng số dư gửi từ client; không gọi provider hai lần khi request cũ chưa rõ kết quả.
- Đổi schema phải có migration và phương án tương thích; seed chỉ dữ liệu danh mục/demo theo môi trường.
- Rule kinh doanh dùng clock abstraction để kiểm thử deadline; không rải `DateTime.Now` theo timezone máy chủ.

### 26.3. Definition of Done cho một feature

1. Yêu cầu/acceptance được gắn ID trong backlog và không còn điều kiện nghiệp vụ mơ hồ quan trọng.
2. OpenAPI/event schema và permission được cập nhật cùng code.
3. UI đủ loading/empty/error/offline/success cho trạng thái liên quan.
4. Validation client để trải nghiệm tốt; validation server và authorization để bảo vệ dữ liệu.
5. Có kiểm thử phù hợp với rủi ro, đặc biệt transaction/tiền/ownership, và bằng chứng chạy đạt.
6. Log/metric cần thiết không lộ PII/secret; lỗi có trace để hỗ trợ.
7. Migration/feature flag/config/runbook được bổ sung nếu thay đổi ảnh hưởng vận hành.
8. Review kiến trúc, kiểm tra dependency và smoke test trên môi trường mục tiêu hoàn tất.

### 26.4. Bộ bàn giao dự án

- Source backend, hai mobile app, admin portal và lịch sử version trong Git.
- Hướng dẫn chạy local, flavor, secret mẫu không có giá trị thật, seed và tài khoản demo an toàn.
- OpenAPI, event contracts, ERD và migration; mô tả trạng thái/giá/tài chính khớp code.
- Thiết kế UI và trạng thái màn hình; mapping route ↔ feature ↔ use case.
- Pipeline build/deploy, signing procedure, release/rollback và các runbook.
- Báo cáo kiểm thử, ma trận thiết bị, kết quả load/security, bằng chứng restore và danh sách hạn chế còn lại.
- Quy trình cấu hình giá/vùng, duyệt tài xế, đối soát tiền mặt, hỗ trợ và xử lý sự cố.

## 27. Quyết định cần chốt

Những mục sau là đầu vào cần xác nhận trong kickoff; tài liệu đã dùng giả định để đội có thể bắt đầu thiết kế, nhưng không coi các giả định này là chính sách kinh doanh đã duyệt.

| ID | Quyết định | Mặc định đang dùng | Cần có trước |
| --- | --- | --- | --- |
| D01 | Phạm vi dịch vụ | Xe máy, ô tô 4/7 chỗ; một vùng pilot | Chốt backlog P0 |
| D02 | Kiến trúc dự án hiện hữu | Feature-first Clean Architecture theo chương 5/6 | Tạo cấu trúc repo; nếu có repo phải đối chiếu |
| D03 | DB/hạ tầng | PostgreSQL + PostGIS, Redis, private object storage | Làm migration, triển khai |
| D04 | Phiên bản toolchain | Chưa pin số phiên bản | Khởi tạo code/CI |
| D05 | Thiết bị/OS hỗ trợ | Android và iOS; min/target chưa chốt | Chọn plugin định vị và build release |
| D06 | Nhà cung cấp bản đồ | Adapter, chưa chọn thương hiệu/gói | Báo giá, điều hướng và ước lượng chi phí |
| D07 | OTP/push và quota | OTP qua SMS adapter; push theo nền tảng | UAT và pilot |
| D08 | Giá, commission, thuế, toll | Upfront fare, hệ số 1, không tự tính thuế suất | Bật đặt chuyến thật |
| D09 | Phí hủy/no-show | P0 bằng 0; P1 có preview/consent | Bật thu phí |
| D10 | Cổng thanh toán/pháp nhân | P0 tiền mặt; gateway P1 | Tích hợp provider và dòng tiền thật |
| D11 | Cơ sở commission/nguồn voucher | Theo ví dụ chương 13, cần duyệt riêng | Đối soát thật/khuyến mại |
| D12 | Tài liệu tài xế và quy trình vận hành | Cấu hình theo vùng/xe | Duyệt tài xế thật |
| D13 | Thông tin điểm đến trước nhận | Cần policy và mức hiển thị API | Hoàn thiện offer UI/contract |
| D14 | Liên hệ/phone masking | P0 theo kênh đã công bố, masking P1 | Chia sẻ số và gọi thật |
| D15 | Hỗ trợ/SOS | Quy trình tiếp nhận nội bộ cần phân công | Pilot; không để nút SOS không có đầu mối |
| D16 | Retention, consent, privacy | Theo bảng đề xuất, chưa phải quyết định pháp lý | Thu thập dữ liệu thật/nộp store |
| D17 | Retention tài chính/kế toán | Sổ cái bất biến, thời hạn cần chuyên môn duyệt | Thu/chi thật |
| D18 | Công nợ/payout/kiểm soát rủi ro | Tách available/held/debt, maker/checker | Thanh toán/chi trả thật |
| D19 | Capacity/SLO và hạ tầng dự phòng | Mô hình tải/SLO chương 22 | Ký cam kết vận hành và mở rộng pilot |
| D20 | Công nghệ Admin Portal | Chưa chốt; backend API không phụ thuộc UI framework | Triển khai giao diện quản trị |

## 28. Tài liệu kỹ thuật tham khảo

Đã đối chiếu nguồn chính thức trong ngày biên soạn. Các liên kết là căn cứ kỹ thuật về phân lớp, cơ chế nền tảng, concurrency và payment integration; trạng thái nghiệp vụ, cấu trúc thư mục và thông số sản phẩm trong tài liệu là thiết kế đề xuất của Grap Solution.

1. [Flutter — Guide to app architecture](https://docs.flutter.dev/app-architecture/guide): tách UI/data, repository/service và domain/use case khi cần; kiến trúc bốn lớp của tài liệu này là cách cụ thể hóa cho nghiệp vụ gọi xe.
2. [Riverpod — Getting started](https://riverpod.dev/docs/introduction/getting_started): nền tảng quản lý provider; dùng làm nguồn kiểm tra lựa chọn package và quy trình khởi tạo khi pin toolchain.
3. [Microsoft — SignalR authentication and authorization](https://learn.microsoft.com/en-us/aspnet/core/signalr/authn-and-authz): xác thực bearer và đặc điểm quyền trong vòng đời connection; cần cơ chế thu hồi và kiểm tra quyền tài nguyên của hệ thống.
4. [PostgreSQL — Explicit locking](https://www.postgresql.org/docs/current/explicit-locking.html): row locking và concurrency; dùng cùng constraint để bảo vệ việc giao chuyến.
5. [Android — Request location permissions](https://developer.android.com/develop/sensors-and-location/location/permissions): phân biệt foreground, background và độ chính xác vị trí; quyền phải khớp use case.
6. [Android — Access location in the background](https://developer.android.com/develop/sensors-and-location/location/background): hạn chế vị trí nền và yêu cầu chỉ sử dụng khi cần cho chức năng cốt lõi.
7. [Apple — Handling location updates in the background](https://developer.apple.com/documentation/corelocation/handling-location-updates-in-the-background): điểm tham chiếu triển khai Core Location theo lifecycle và quyền; phải kiểm thử thiết bị thật.
8. [Stripe — Webhooks](https://docs.stripe.com/webhooks): ví dụ nguồn chính thức về xác minh chữ ký và xử lý webhook; chỉ áp dụng chi tiết protocol nếu chọn Stripe. Provider khác phải theo tài liệu của chính provider đó.
9. [Stripe — Idempotent requests](https://docs.stripe.com/api/idempotent_requests): ví dụ về retry an toàn bằng khóa; retention và semantics idempotency nội bộ của Grap được quy định riêng tại chương 17.

---

**Trạng thái tài liệu:** Đã bao phủ thiết kế hệ thống, backend C#, hai app Flutter/Riverpod, vận hành, hợp đồng dữ liệu/API, tài chính và nghiệm thu. Khi có kiến trúc repo, thiết kế UI hoặc chính sách kinh doanh chính thức, cần cập nhật các quyết định tương ứng và lưu lịch sử thay đổi phiên bản tài liệu.



