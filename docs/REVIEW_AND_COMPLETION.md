# Rà soát file và bổ sung chức năng mobile

Ngày thực hiện: **03/11/2026**. Đối chiếu các chương 5, 7, 8, 10, 15, 17, 21 và 24 của đặc tả.

## 1. Các lỗi chức năng đã sửa

| Phát hiện | Cách sửa | Kiểm chứng |
| --- | --- | --- |
| Complete chỉ giữ key trong RAM; retry tạo GPS mới và có thể thành request khác | Secure-storage journal cho complete/cash; giữ cả body/key gốc, phục hồi sau restart, 32 lệnh/24 giờ | Test restart và kiểm tra nguyên key/body/version/GPS |
| Response refresh cũ có thể ghi đè account vừa đổi | Session epoch cho transport; refresh single-flight và kiểm tra epoch trước khi áp dụng response | Test 10 request 401 song song; test đăng nhập account B khi refresh A chưa trả |
| Refresh chậm có thể ghi đè kết quả start mới | Revision/generation guard ở controller; không áp snapshot cũ sau command mới | Provider test delayed refresh sau start |
| Assignment bị release nhưng UI giữ lại ride cũ | Đọc snapshot theo ID nếu không nằm trong history page, xử lý 404 bằng clearRide | Provider test quyền assignment bị thu hồi |
| Tài xế cũ có thể đọc live ride qua history list | Server chỉ đưa active assignment hiện hành hoặc lịch sử đã terminal vào danh sách | HTTP integration test đổi assignment rồi thử cả list/detail |
| Reviewer làm thay đổi version upload mỗi lần duyệt | Version upload giữ nguyên; chỉ review tài liệu đang PENDING_REVIEW; nộp lại mới tạo version | Integration onboarding có từ chối và nộp lại |
| Có thể sửa/nộp lại hồ sơ đang chờ duyệt | Chặn ở API và UI; chỉ DRAFT/REJECTED được sửa và gắn giấy tờ | Test cố thay xe khi PENDING_REVIEW |
| No-show chỉ kiểm tra thời gian chờ | Bổ sung contact attempt theo đúng driver/ride, ghi sau arrival và yêu cầu khi no-show | Test thiếu liên hệ bị bác bỏ, đủ điều kiện mới hủy |
| Hồ sơ mới bị thiếu lý do từ chối từng giấy tờ | Lưu ReviewReason trong document, trả về app và hiển thị cùng trạng thái/hạn dùng | Test applicant đọc được lý do reviewer ghi |
| SQLite local cũ không tự có cột bổ sung | Nâng cấp additive ReviewReason và bảng contact attempt; không xóa database | API local được khởi động trên database đã tồn tại |

## 2. Chức năng đã bổ sung

### Hồ sơ và đăng nhập

- Hai app có màn hình chỉnh tên/email, validation, lưu expectedVersion và cập nhật session cache.
- Số điện thoại vẫn chỉ đọc; không dùng profile update để bỏ qua xác minh số mới.
- OTP có countdown hết hạn, cooldown gửi lại và autofill one-time code. Thời hạn lấy từ response backend.
- Khi session kết thúc/đổi user, navigation trở về màn hình gốc để không giữ màn hình chứa dữ liệu account cũ.

### Onboarding tài xế

- Màn hình riêng `Hồ sơ, xe & giấy tờ` trong tài khoản tài xế.
- Khai báo dịch vụ, hãng/dòng xe, biển số và màu xe; lưu nháp bằng API.
- Chụp ảnh hoặc chọn ảnh thư viện bằng image_picker; giới hạn JPEG/PNG 5 MB, chọn ngày hết hạn.
- Luồng upload-intent → raw upload → complete → gắn document; file không được public.
- Hiển thị đủ từng loại giấy tờ, phiên bản, trạng thái, hạn và lý do bị từ chối.
- Chặn submit thiếu giấy tờ; gửi hồ sơ → chờ duyệt; đọc kết quả mới nhất; chỉ nộp lại khi được phép.
- Đã khai báo mô tả quyền camera/photo trên iOS. Chưa coi native build là bằng chứng thử camera trên máy thật.

### Đặt và thực hiện chuyến

- Khách có thể đặt ghim trên bản đồ, nhập mô tả hoặc dùng GPS; không buộc phải cấp GPS để chọn điểm thủ công.
- Điểm thủ công được thêm vào danh sách lựa chọn; thay điểm/dịch vụ luôn bỏ quote cũ.
- Quote/offer có countdown; quote hết hạn lấy giá mới để người dùng xác nhận, offer hết hạn bị khóa nhận.
- Driver có UI ghi nhận đã thử liên hệ, thời gian chờ no-show và báo khách không xuất hiện.
- Driver có kết thúc sớm với lý do, vẫn giữ giá đã chốt theo P0; server tiếp tục xác minh quyền/trạng thái/vị trí.
- GPS heartbeat chạy tách khỏi busy state của command; lỗi GPS không làm UI tự coi online là offline nếu server đã nhận online.
- Khi có command hoàn tất/thu tiền chưa rõ kết quả, banner cho kiểm tra và gửi lại nội dung gốc.

### Hỗ trợ, thông báo và chia sẻ

- Hộp thư ticket của chính user, form tạo ticket có loại vấn đề, màn hình hội thoại và gửi phản hồi.
- Không cho gửi thêm message vào ticket CLOSED ở cả UI và API.
- Danh sách thông báo, phân biệt đã đọc/chưa đọc và lệnh mark-read theo ID.
- Dialog tạo link chia sẻ có hạn, sao chép và thu hồi link.
- Sự kiện vị trí và offer đóng được dùng làm tín hiệu tải REST snapshot mới.

## 3. Vị trí mã nguồn chính

| File / thư mục | Trách nhiệm |
| --- | --- |
| `mobile/apps/{customer_app,driver_app}/lib/core/network/api_client.dart` | Session fence, refresh, journal complete/cash, upload bytes |
| `mobile/apps/{customer_app,driver_app}/lib/core/domain/` | Model và repository contract typed |
| `mobile/apps/{customer_app,driver_app}/lib/core/data/account_repositories.dart` | Hồ sơ, ticket, notification, share, onboarding và recovery adapters |
| `mobile/apps/{customer_app,driver_app}/lib/features/account/presentation/account_screens.dart` | Các màn hình chung và recovery/share dialog |
| `mobile/apps/{customer_app,driver_app}/lib/features/places/presentation/place_picker_screen.dart` | Chọn ghim, vị trí thiết bị và countdown |
| `mobile/apps/driver_app/lib/features/onboarding/` | Form xe, upload giấy tờ, submit và kết quả duyệt |
| `mobile/apps/*/lib/features/` | Controller chống stale refresh và các luồng nghiệp vụ riêng |
| `backend/src/GrapSolution.Api/FileEndpoints.cs` | Khóa sửa hồ sơ, version document, lý do duyệt và audit đọc file |
| `backend/src/GrapSolution.Api/Endpoints.cs` | Contact attempt, history ownership, validation hồ sơ/ticket |
| `backend/src/GrapSolution.Infrastructure/DevelopmentSchema.cs` | Nâng cấp SQLite local giữ dữ liệu |
| `backend/src/GrapSolution.Infrastructure/Migrations/*MobileOnboardingAndNoShow*` | Migration PostgreSQL bổ sung |

## 4. Giới hạn còn lại

- Camera/photo picker chưa được thử trên thiết bị vật lý; Android process-death khi đang chọn ảnh vẫn cần bài test riêng.
- SMS thật chưa được cấu hình; countdown/resend UI không có nghĩa hệ thống đã gửi SMS thật.
- Chưa tích hợp push, ngân hàng/gateway, Redis/PostGIS spatial index và tracking background hoàn chỉnh.
- Journal chỉ lưu complete/cash, không lưu PIN. GPS buffer offline và replay nền tự động chưa triển khai.
- Nếu complete chưa từng commit và GPS trong body gốc đã quá cũ, server có thể bác bỏ replay. App không được tự thay GPS trong cùng key; cần kiểm tra snapshot và xác nhận thao tác mới hoặc hỗ trợ.
- Contact attempt là khai báo của tài xế, chưa phải bằng chứng cuộc gọi từ nhà cung cấp.
- Các tính năng lịch sử, địa chỉ, liên hệ tin cậy và tiếp nhận yêu cầu xóa được bổ sung trong đợt tiếp theo bên dưới. Xóa/anonymize dữ liệu cuối cùng và retention vẫn chưa triển khai.

Kết quả kiểm thử/build mới nhất được ghi tại [VALIDATION.md](VALIDATION.md). Bản này vẫn chưa được coi đã nghiệm thu toàn bộ P0 cho vận hành thật.

## 5. Đợt bổ sung lịch sử, địa chỉ và quyền riêng tư

Đối chiếu thêm C-FR-02, C-FR-08, C-FR-09 và các mục 5, 16, 21 của đặc tả.

| Chức năng | Hành vi đã thực hiện | File chính |
| --- | --- | --- |
| Lịch sử | Sắp CreatedAt/ID, signed keyset cursor gắn actor và filter, lọc ngày UTC từ ngày địa phương, tải thêm 20, chống response cũ và ID lặp | `HistoryEndpoints.cs`, `journey_repository.dart`, `journey_screens.dart` |
| Biên nhận | REST snapshot có quyền + timeline + đánh giá của mình, fare components/cước tối thiểu, nghĩa vụ/đã thu/còn lại tách biệt, hỗ trợ theo Ride | `RideReceiptScreen`, `Fare`, `RideReceipt` |
| Đánh giá | Chọn 1–5 sao và nhận xét tối đa 1000 ký tự, một đánh giá/người/chuyến, gửi/sửa trong 24 giờ từ hoàn tất | `MapReceiptFeatures`, rating endpoint, review dialog |
| Đặt lại | Mang tọa độ và loại dịch vụ từ chuyến cũ, xóa quote cũ để lấy giá mới; chặn khi có chuyến đang diễn ra | `CustomerController.rebook` |
| Saved places | Tạo/sửa/xóa tối đa 20, tên duy nhất theo account, tọa độ và ghi chú, chọn điểm đón/đến từ danh sách lưu | `CustomerFeatureEndpoints.cs`, `SavedPlacesScreen` |
| Trusted contacts | Tối đa 5, xác nhận đồng ý, chuẩn hóa số, version/ownership, mã hóa số phía server, dialer, secure cache 30 ngày theo user | `CustomerFeatureEndpoints.cs`, `SafetyContactsScreen`, `ApiClient` |
| Yêu cầu xóa | Tạo ticket, phát hiện chuyến/payment/số dư chưa tất toán, theo dõi, kiểm tra lại, rút yêu cầu, chống trùng | `AccountDeletionEndpoints.cs`, `DeletionRequestScreen` |
| SecurityAdmin | Danh sách theo vùng, tiếp nhận/yêu cầu bổ sung/từ chối có lý do, xem và phản hồi đúng ticket quyền riêng tư | `PrivacyRequests.vue` trong Settings |
| Bảo vệ replay | Mã hóa response mới trong IdempotencyRecord vì có thể chứa PIN, số liên hệ và địa chỉ; vẫn đọc record local cũ | `AtomicExecutor.cs` |

Các màn hình dùng chung ở `mobile/apps/{customer_app,driver_app}/lib/features/journey/presentation/journey_screens.dart` và `features/privacy/presentation/privacy_screens.dart` trong từng app; ports/models ở `lib/core/domain/journey.dart` trong từng app. Migration PostgreSQL mới là `20261103053443_CustomerJourneyAndPrivacy`. SQLite local thêm bảng mà không xóa dữ liệu đang có.

Cách kiểm tra: khách mở Hành trình → lọc/tải thêm → chi tiết → đánh giá hoặc đặt lại. Trong Tài khoản mở Địa chỉ đã lưu, Liên hệ tin cậy, Yêu cầu xóa tài khoản. Tài xế có lịch sử trong Thu nhập và cùng các màn hình liên hệ/quyền riêng tư. Nhân sự `staff-SecurityAdmin` mở Cấu hình hệ thống → Yêu cầu xóa tài khoản.

Yêu cầu xóa chỉ là tiếp nhận và xem xét, **không phải đã xóa dữ liệu**. Chưa có pipeline erase/anonymize, retention từng loại dữ liệu hay thu hồi toàn bộ backup theo policy. Chưa có nhãn đánh giá, cấu hình cửa sổ sửa, hóa đơn điện tử hoặc masking số điện thoại. Các kiểm thử/build được ghi riêng trong VALIDATION.md.

## 6. Gộp core vào từng app theo yêu cầu

Đã chuyển toàn bộ domain, use case, repositories, Dio client, session/cache, provider, theme, widgets và các màn hình trước đây nằm ngoài app vào hai project Flutter độc lập. `mobile/apps/customer_app` và `mobile/apps/driver_app` không có path dependency vào thư mục bên ngoài. Từng app có `lib/core/network/api_client.dart`, `dio_config.dart`, `api_providers.dart` và dependency Dio trực tiếp.

MaterialApp nằm tại `lib/app/grap_app.dart`, đăng nhập tại `features/auth/presentation/auth_gate.dart`, màn hình nghiệp vụ nằm trong `features`. Core không import features. Kiểm thử mạng và giao diện đã được đưa vào `test/core` và `test/features` của mỗi app. CI chạy pub get/analyze/test trực tiếp ở hai project. Thư mục package cũ được gỡ sau khi kiểm tra mã đã chuyển.

## 7. Tối ưu tải dữ liệu và sửa các tình huống gián đoạn

| Phát hiện | Sửa đổi | Kiểm chứng |
| --- | --- | --- |
| Lỗi history/earnings/config có thể làm toàn màn hình chuyến lỗi dù active endpoint thành công | Tải các phần độc lập song song; capture lỗi theo phần, giữ Ride và dữ liệu gần nhất, hiện cảnh báo kéo xuống thử lại | Startup history/earnings 503, refresh Ride version mới trong lúc history lỗi |
| Polling tải cả dữ liệu ít thay đổi mỗi 5 giây | Chuyến/offer vẫn được hỏi thường xuyên; history/earnings có khoảng tải 30 giây khi Ride không đổi; manual refresh hoặc Ride đổi version tải ngay; command đổi Ride bỏ cache để vòng đồng bộ tiếp theo tải lại | Đếm số lần gọi active/history/earnings khi polling liên tục và làm mới thủ công |
| App khách vẫn xử lý polling khi xuống nền | Thêm lifecycle observer, bỏ qua tín hiệu khi background, làm mới khi resume | Test tín hiệu nền không gọi active; resume có recovery |
| Lịch sử cache chứa Ride active cũ có thể che kết quả active=null | Không dùng cache active làm bằng chứng đang có chuyến; đọc detail, xóa Ride và entry active cũ khi API trả 404 | Test history lỗi đồng thời quyền detail bị thu hồi |
| Thu tiền đã commit nhưng tải history/earnings lỗi làm UI quay lại snapshot chưa thu | Đọc detail theo Ride ID; giữ thông báo đã ghi nhận, tách lỗi tải dữ liệu; không phụ thuộc trang history đầu tiên | Test cash thành công trong khi history/earnings 503 |
| Chưa có snapshot thanh toán mới nhưng vẫn có thể bấm thu thêm | Khóa thu thêm đến khi đọc được snapshot mới; thêm nút kiểm tra lại; chặn cả khi còn cash command trong recovery journal | Test detail mất mạng, chặn lần thu tiếp, phục hồi snapshot; test pending command không gửi cash mới |
| Gửi hỗ trợ có thể làm GPS/heartbeat dừng theo busy state | Cho publish vị trí chạy độc lập, giữ khóa chống publish trùng theo generation | Test GPS/heartbeat vẫn gửi khi lệnh support đang chờ |
| Dữ liệu local là JSON hợp lệ nhưng sai shape gây TypeError | Kiểm tra cấu trúc session/cache/journal; session hỏng trở về đăng nhập, journal bỏ entry hỏng nhưng giữ phiên và entry hợp lệ | Test JSON list, thiếu trường, journal có entry hỏng, cache contacts sai shape |
| Restore hoặc ghi refresh chậm có thể ghi đè tài khoản mới trên disk | Guard epoch cả khi đọc storage; serialize session write chung queue; bỏ write cũ và kiểm tra epoch sau IO | Test chặn đọc restore và chặn ghi refresh, đăng nhập B rồi giải phóng IO A |
| Refresh trả session sai user hoặc vẫn bị 401 sau retry | Validate response/user ID; không thay phiên bằng payload sai; khi retry vẫn 401 thì thu hồi phiên local và thông báo sessionEnded một lần | Test refresh malformed/foreign user và retry 401 |
| Form sửa hồ sơ/địa chỉ/liên hệ giữ expectedVersion cũ sau conflict | Khóa nút lưu và có thao tác đóng/tải bản mới để người dùng kiểm tra lại | Widget test conflict địa chỉ, trở về danh sách được tải lại |

Mã nằm trong `lib/core/network/api_client.dart`, `core/application/load_result.dart`, các controller booking/driving và các màn hình account/journey/privacy của từng app. Hai project vẫn độc lập và dùng Dio trực tiếp. Không có thay đổi hợp đồng API hoặc schema database trong đợt này.

Giới hạn: đây là kiểm thử với transport/storage fake và widget/provider; không thay thế kiểm thử thiết bị, mất mạng thật, tracking nền hoặc tải đồng thời trên PostgreSQL. Cache history/earnings ở controller chỉ ở RAM, không phải cache lịch sử offline bền vững.
