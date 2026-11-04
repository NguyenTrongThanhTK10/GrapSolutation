# Rà soát và hoàn thiện ứng dụng mobile, web

Các đợt mobile thực hiện ngày **03/11/2026**; đợt hoàn thiện web và thống kê app tại mục 8–10 ngày **04/11/2026**. Đối chiếu các chương 5, 7, 8, 10, 15, 17, 21 và 24 của đặc tả.

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


## 8. Hoàn thiện web quản trị — 04/11/2026

Phạm vi: `admin_portal`, giữ nhận diện xanh/trắng và hợp đồng API hiện có.

| Phát hiện | Thay đổi |
| --- | --- |
| Menu, liên kết dashboard và tìm kiếm dẫn tới phân hệ không đúng quyền | Dùng bảng quyền thống nhất với API; chỉ hiện phân hệ phù hợp, kiểm tra điều hướng và có màn giải thích quyền truy cập kèm đường về workspace |
| Dashboard của Reviewer/Security gọi danh sách chuyến hoặc tài xế không được phép | Chỉ tải các phần đúng quyền; lỗi tải bản đồ có trạng thái thử lại riêng |
| Hồ sơ nhân sự bị chặn vì tải hạ tầng cùng lúc | Mọi vai trò nhân sự được xem/sửa hồ sơ; chỉ OperationsAdmin/SecurityAdmin tải phần hạ tầng |
| Đổi bộ lọc khi request trước đang chạy làm mất lần tải mới | Xếp lần tải theo bộ lọc mới nhất, bỏ kết quả cũ; polling dùng request đang có, có trạng thái đang tải và giữ dữ liệu gần nhất khi lỗi |
| Chi tiết chuyến giữ timeline trước hoặc không đổi khi query ID thay đổi | Theo dõi ID trên URL, xóa dữ liệu khi đổi chuyến, chặn response cũ, có loading/lỗi/thử lại; khóa lệnh vận hành khi snapshot chưa xác minh |
| Bộ lọc và phân trang thiếu thao tác quay lại | Thêm xóa bộ lọc chuyến; khóa chuyển trang lúc đang tải; nhật ký có trang trước và chỉ áp từ khóa khi tìm kiếm |
| Hỗ trợ cho chọn trạng thái không hợp lệ và trả lời phiếu đã đóng | Chỉ hiện bước chuyển hợp lệ theo backend, thêm lọc CLOSED, hội thoại đóng chỉ đọc; giới hạn phản hồi 5.000 ký tự và xóa nháp khi đổi phiếu |
| Nhân sự hỗ trợ thấy nút hạn chế khách dù không có quyền ghi | Chỉ OperationsAdmin/SecurityAdmin thấy hành động; tiêu đề xác nhận phân biệt hạn chế và mở lại |
| Tài chính thiếu làm mới, trạng thái rỗng và phạm vi số liệu | Thêm làm mới, thông báo rỗng từng bảng, làm rõ giới hạn danh sách 100 khoản thu/50 bút toán và xuất các khoản thu đã tải |
| Chữ nhỏ, bảng/hộp thoại khó dùng trên điện thoại | Tăng cỡ chữ/độ tương phản; cuộn ngang trong bảng với chỉ dẫn; nút và bộ lọc xuống hàng; hộp thoại nằm trong viewport; bố cục 320 px có cột đơn khi cần |
| Menu ẩn vẫn nhận focus, thiếu thao tác bàn phím | Thêm inert, nút đóng, Escape, giữ focus trong menu và trả focus về nút mở; đóng menu cả khi chọn lại trang hiện tại; có liên kết bỏ qua điều hướng và bảng cuộn được bằng bàn phím |
| Thông báo có thể dẫn mọi loại entity sang chuyến xe | Chỉ loại ride mở chuyến; application điều hướng theo quyền; xóa danh sách khi đổi tài khoản và không áp danh sách trả chậm của tài khoản khác |

Mã chính: `src/lib/access.ts`, `src/composables/useQuery.ts`, `src/App.vue`, `src/style.css` và các view trong `admin_portal`. Không thay đổi backend, schema hoặc mã mobile trong đợt này.

Ảnh kiểm tra: [desktop](qa/web-dashboard-desktop.png), [mobile](qa/web-dashboard-mobile.png), [chi tiết chuyến mobile](qa/web-ride-mobile.png). Kết quả chạy thực tế, phạm vi API thật/snapshot giả lập và giới hạn được ghi tại [VALIDATION.md](VALIDATION.md).


## 9. Báo cáo và thống kê trên hai app — 04/11/2026

- **Khách:** mở Hành trình → Thống kê chuyến & chi tiêu. Xem chuyến đã kết thúc/hoàn tất/hủy/không thành, tỷ lệ hoàn tất, cước phải trả, đã thanh toán, còn lại và thống kê dịch vụ.
- **Tài xế:** mở Thu nhập → Báo cáo thu nhập theo kỳ. Xem các chỉ số chuyến, giá gộp, hoa hồng, quyền lợi và khoản đã thu/còn phải thu. Phần thu nhập cũ được ghi rõ là lũy kế, độc lập số liệu theo kỳ.
- Cả hai có Hôm nay, 7 ngày, Tháng này và chọn khoảng ngày tối đa 366 ngày. Biểu đồ cột theo ngày, tự gộp theo tháng khi kỳ dài hơn 31 ngày; điền cả ngày/tháng không có chuyến. Bảy ngày vừa màn hình 390 px ở cỡ chữ thường; kỳ dài hoặc chữ lớn cuộn ngang.
- API mới `/me/ride-statistics` tổng hợp toàn bộ dữ liệu đúng chủ, theo EndedAt và ngày Việt Nam, không cộng riêng trang lịch sử đang tải. Tài xế từng nhận assignment nhưng không phải tài xế cuối không được cộng quyền lợi của người khác.
- Phân biệt cước nghĩa vụ, tiền hiện đã ghi nhận và quyền lợi tài xế; chỉ chuyến hoàn tất đóng góp số tiền. Thanh toán cập nhật muộn vẫn cập nhật số đã thu cho kỳ kết thúc chuyến khi tải lại báo cáo, không coi đó là tiền được thu đúng ngày kết thúc.
- Có làm mới/kéo xuống, lỗi và thử lại, trạng thái rỗng, chặn xuất khi chưa có dữ liệu hợp lệ; phản hồi chậm không thay kết quả kỳ/tài khoản mới. Provider thống kê không tự lặp retry khi lỗi.
- **Sao chép CSV** xuất tổng hợp, các bucket và dịch vụ; có thời điểm tải UTC, ngày kỳ, số tiền VND nguyên và BOM UTF-8. Dữ liệu không có PII. Đây là sao chép văn bản CSV vào clipboard; chưa tạo file tải/chia sẻ trực tiếp, `.xlsx` hoặc PDF.

Mỗi app giữ domain/repository/provider/screen và test trong project của mình. Không thêm package, quyền iOS/Android hoặc migration. Mã mới tại `lib/core/domain/statistics.dart`, `lib/core/data/statistics_repository.dart`, `lib/features/statistics/statistics_screen.dart`; backend tại `StatisticsEndpoints.cs`. Hợp đồng trong [API README](api/README.md); snapshot OpenAPI đã cập nhật từ API đang chạy.

Ảnh widget thật với dữ liệu giả lập: [khách – tổng quan](qa/customer-statistics-overview.png), [khách – biểu đồ](qa/customer-statistics-chart.png), [tài xế – tổng quan](qa/driver-statistics-overview.png), [tài xế – biểu đồ](qa/driver-statistics-chart.png). Kiểm chứng và giới hạn tại [VALIDATION.md](VALIDATION.md).


## 10. Tìm địa điểm và đặt xe thuận tiện hơn trên app khách — 04/11/2026

| Phần | Hành vi đã bổ sung / tối ưu |
| --- | --- |
| Tìm điểm đón/đến | Ô tìm kiếm ngay trong sheet, chờ 300 ms sau khi gõ, tối đa 150 ký tự; bỏ phản hồi query cũ, xóa query không phát request mới |
| Gợi ý cá nhân | Tìm không dấu trong tên/địa chỉ đã lưu; gợi ý địa điểm từ lịch sử gần đây và địa điểm API; khử trùng theo tọa độ, ưu tiên địa chỉ của mình |
| GPS và ghim | Có lối tắt dùng GPS, vẫn phải xem/xác nhận ghim; pin thủ công thắng response GPS cũ; đổi pin xóa mô tả cũ; nút xác nhận ở trên bàn phím/vùng cử chỉ; từ chối GPS vẫn chọn thủ công |
| Đảo tuyến | Đổi điểm đón/đến một chạm, xóa toàn bộ giá cũ; chặn khi đang gửi lệnh đặt xe hoặc có chuyến active |
| So sánh loại xe | Một lần xem giá tải BIKE/CAR_4/CAR_7 song song qua API quote hiện có; có giá/thời gian di chuyển trên thẻ và nút chọn giá thấp nhất |
| Đổi loại xe | Dùng đúng quote của loại đó trong cùng tuyến; thiếu giá thì không dùng quote loại khác. Quote hết hạn vẫn buộc lấy giá mới trước khi đặt |
| Chờ giá | Có thể sửa địa điểm/chọn loại xe khi đang tải; đổi tuyến hủy hiệu lực toàn bộ comparison cũ. Một dịch vụ lỗi không làm mất giá dịch vụ còn lại |
| Xe gần điểm đón | API Customer-only trả số lượng theo loại trong bán kính 3 km, không trả danh tính hoặc tọa độ tài xế; thẻ loại xe có số lượng riêng |
| Tính đủ điều kiện | Dùng cùng bộ lọc với dispatch: duyệt hồ sơ/giấy tờ, user/session active, online, GPS/heartbeat mới, accuracy, không bận, không giữ offer khác |
| Tải số xe | Lọc điều kiện trong SQL rồi chỉ lấy service/tọa độ để tính khoảng cách, tránh đọc user/session/assignment lặp từng tài xế; không tự polling liên tục; snapshot quá 20 giây bị ẩn và có nút cập nhật |
| Khởi động | Ngoài chế độ demo không gọi autocomplete với query rỗng và không tự chọn tuyến mẫu; dịch vụ autocomplete chỉ được gọi khi người dùng tìm kiếm |
| Giao diện | Các bước hành trình/chọn xe rõ ràng, thêm lối tắt GPS/đảo tuyến/địa điểm gần đây, bỏ banner quảng bá dài, giữ hành động chính cố định, sheet cuộn được khi có bàn phím và chữ lớn |

Backend autocomplete hiện gọi `IMapProvider.Search`: Development không cấu hình Maps dùng fixture có tìm không dấu/nhiều từ/alias TSN-SGN; khi có `Maps__BaseUrl`, gọi `/autocomplete?q=...` của adapter. Adapter lỗi hoặc dữ liệu tọa độ không hợp lệ trả 503, không âm thầm thay bằng địa điểm mẫu. Nhà cung cấp geocoding thật vẫn phải được triển khai/cấu hình theo [runbook](runbooks/LOCAL_AND_DEPLOYMENT.md).

Số xe là snapshot tham khảo, không giữ chỗ hoặc cam kết có tài xế nhận chuyến. Thời gian trên thẻ là thời gian **di chuyển của tuyến**, không phải ETA tài xế đến đón. Bán kính là khoảng cách địa lý, chưa có PostGIS/spatial index. Không có cơ chế ưu tiên sai giá hoặc tự tạo chuyến khi người dùng đổi loại xe.

Mã chính trong `mobile/apps/customer_app/lib/features/booking/`, `features/places/`, `core/domain/booking_discovery.dart`, `core/data/booking_discovery_repository.dart`; backend ở `RideService.cs`, `MapProviders.cs`, `Ports.cs`, `Endpoints.cs`. Không thêm package, quyền native hay migration. Ảnh widget thật với dữ liệu giả lập: [đặt xe](qa/customer-booking-home.png), [so sánh](qa/customer-booking-comparison.png), [tìm địa điểm](qa/customer-booking-search.png). Kiểm chứng chi tiết tại [VALIDATION.md](VALIDATION.md).
