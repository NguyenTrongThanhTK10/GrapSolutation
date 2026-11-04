# Kết quả kiểm tra

Kiểm tra trên macOS/Apple Silicon; giao diện mobile ngày **03/11/2026**, web quản trị và thống kê mobile cập nhật ngày **04/11/2026**. Toolchain thực tế: .NET SDK 10.0.401, Node 20.19.0, Flutter 3.47.6, Dart 3.13.5.

## Tối ưu tìm và đặt xe app khách — 04/11/2026

- `dotnet test GrapSolution.sln --no-restore --disable-build-servers -m:1`: **41/41 đạt**, thêm 7 ca về tìm không dấu/alias, giới hạn query, số xe đúng điều kiện và scope vùng, role/coordinate validation, HTTP autocomplete adapter và lỗi dữ liệu provider. Kiểm tra đủ GPS/heartbeat cũ, hồ sơ/giấy tờ, session thu hồi, tài xế bận/giữ offer và không trả PII/tọa độ trong response đếm xe.
- Toàn bộ `flutter test --no-pub` app khách: **77/77 đạt**, thêm 12 ca. Bao gồm báo giá 3 loại song song/quote đúng loại, dịch vụ lỗi riêng, đổi tuyến trong khi chờ giá, đổi service trong lúc tải, session failure không kẹt loading, không gọi autocomplete rỗng lúc startup/refresh ở chế độ live; saved/recent dedupe, tìm không dấu, response query chậm, alias provider; GPS chậm không đè ghim thủ công; snapshot số xe cũ/lỗi không biến thành 0 xe giả.
- Sheet tìm kiếm được kiểm tra ở 320×640 và 640×320, chữ 160%, bàn phím chiếm 240/130 px. Nút xác nhận ghim có kiểm tra hình học trên viewport 390×844 để nằm trên bàn phím 200 px và vùng cử chỉ 34 px.
- `flutter analyze --no-pub --no-fatal-infos`: không có error/warning; 23 lint info có sẵn trong app khách. Script QA tạm đã dọn; không thêm dependency hoặc quyền native.
- Web dùng chung backend: chạy lại toàn bộ Chrome E2E **21/21 đạt** trên Vite/API local, bao gồm quote/đặt/hủy, quyền các vai trò và nghiệp vụ có sẵn. Mã web không thay đổi trong đợt này.
- Đã xem ảnh dựng từ widget thật, Roboto, 390×844: [trang đặt xe](qa/customer-booking-home.png), [so sánh giá](qa/customer-booking-comparison.png), [tìm kiếm](qa/customer-booking-search.png). Số xe/giá trong các ảnh là dữ liệu giả lập QA; tile mạng bị chặn bởi widget test nên bản đồ có thể trống. Nút đặt và thanh điều hướng được kiểm tra nằm trong viewport khi chụp.
- Snapshot OpenAPI được xuất lại từ API đang chạy: **90 route paths**. Không đổi schema; app tài xế không đổi mã trong đợt này. Chưa đo tải lớn, chưa xác minh PostgreSQL/spatial index, provider geocoding thật hoặc GPS trên thiết bị vật lý. Chưa build lại APK/iOS sau thay đổi này.

## Báo cáo thống kê mobile — 04/11/2026

- Backend: `dotnet test GrapSolution.sln --no-restore --disable-build-servers -m:1` **34/34 đạt**, gồm 3 bài mới trong `StatisticsTests.cs` dùng HTTP + SQLite thật. Có kiểm tra 41 chuyến hoàn tất vượt trang lịch sử, tổng theo dịch vụ, partial payment, hai biên ngày Việt Nam, ngày tạo khác ngày kết thúc, loại trừ active, quyền của tài xế cuối và không cộng assignment cũ, dữ liệu rỗng, ngày không hợp lệ và giới hạn 366 ngày.
- Toàn bộ `flutter test --no-pub`: **65/65 customer, 69/69 driver**, tổng **134/134 đạt**. Mỗi app thêm 3 repository/domain test và 6 widget test: ngày Việt Nam, request ngày lịch, mapping/CSV, đổi kỳ và đổi account khi response cũ đang chờ, khóa xuất khi lỗi, thử lại, khoảng ngày tùy chọn, 320×640/640×320 với chữ 160%.
- `flutter analyze --no-pub --no-fatal-infos` ở cả hai app: không có error/warning; mỗi app còn **23 lint info có sẵn** về ngoặc `if`. Không có lint mới trong phần thống kê.
- Kiểm tra trực tiếp API local với `customer-0`, `driver-user-0`: trả đúng role/kỳ/totals và trạng thái rỗng; phiên kiểm tra được đăng xuất. Đã xuất OpenAPI từ API đang chạy: **89 route paths** trong `docs/api/openapi.json`.
- Đã dựng và xem ảnh widget thật ở 390×844, font Roboto, dữ liệu giả lập nhất quán tổng/bucket/dịch vụ: [khách tổng quan](qa/customer-statistics-overview.png), [biểu đồ khách](qa/customer-statistics-chart.png), [tài xế tổng quan](qa/driver-statistics-overview.png), [biểu đồ tài xế](qa/driver-statistics-chart.png). Các bài dựng ảnh chạy riêng, không cộng vào 134 kiểm thử ở trên; script QA tạm đã dọn.
- Không thêm dependency hoặc quyền native; không đổi schema. Đợt này chưa build lại APK/iOS, chưa thử trên thiết bị vật lý hoặc kiểm tra PostgreSQL thật; clipboard được kiểm tra qua platform channel giả lập. Báo cáo hiện sao chép CSV, chưa xuất file Excel/PDF hoặc gửi báo cáo định kỳ.
- Web không thay đổi trong đợt thống kê; kết quả 21 E2E thuộc đợt web bên dưới, không phải lần chạy lại mới trong đợt này.

## Hoàn thiện web quản trị — 04/11/2026

- `admin_portal`: `npm run build` đạt kiểm tra Vue/TypeScript và build production. Vite còn hai cảnh báo chú thích PURE trong dependency SignalR; không chặn build.
- Toàn bộ `npm run test:e2e`: **21/21 đạt**, Chrome headless, Node 20.19.0, API Development + SQLite local và Vite; gồm 7 bài có sẵn và 14 bài mới tại `admin_portal/tests/web-completion.spec.ts`.
- API thật: dashboard và hồ sơ của cả 7 vai trò nhân sự không gọi endpoint admin bị từ chối; điều hướng phân hệ chưa được cấp quyền có giải thích/đường về; tìm tài xế khi response đầu bị giữ chậm vẫn áp từ khóa mới nhất.
- Chi tiết chuyến tải API thật; đổi query ID trong cùng view sang ID giả lập 404 không giữ timeline hoặc thao tác của chuyến trước.
- Hỗ trợ dùng response giả lập cho OPEN/CLOSED để kiểm tra danh sách bước chuyển, bộ lọc phiếu đóng và hội thoại chỉ đọc. Phân trang nhật ký dùng hai trang giả lập để kiểm tra quay lại/tìm mới. Các bài này xác minh UI, không thay thế integration test quy tắc backend.
- Bố cục vận hành được kiểm tra ở **320×640, 390×844, 640×320**; không tràn ngang toàn trang trên tổng quan, chuyến, tài xế, khách, giá cước, hỗ trợ, nhật ký và cấu hình. Bảng có vùng cuộn riêng; hộp thoại chuyến vừa viewport 390 px. Tài chính có kiểm tra riêng bốn tab và form đề nghị ở 320 px.
- Menu có kiểm tra nút đóng, Escape, trả focus và inert khi ẩn. Đây là kiểm tra bàn phím cơ bản, chưa phải đánh giá accessibility toàn diện hoặc thử screen reader.
- Bài kiểm tra nhiều kích thước dùng lại snapshot API GET đã tải thành công trong cùng phiên để kiểm tra bố cục; các ca nghiệp vụ và quyền vẫn dùng API thật theo phạm vi ở trên. Phiên nhân sự chỉ đọc được dùng lại trong file test để tuân thủ giới hạn đăng nhập. Không tắt/bỏ qua rate limiter của backend; khi chạy nhiều bộ liên tiếp cần đợi cửa sổ 1 phút nếu gặp 429.
- Đã xem trực tiếp ảnh mới: [desktop](qa/web-dashboard-desktop.png), [mobile](qa/web-dashboard-mobile.png), [chi tiết chuyến mobile](qa/web-ride-mobile.png). Tile OSM có lúc tải chậm hoặc thất bại, có lúc hiển thị đầy đủ; bộ E2E không coi việc tải mọi tile là điều kiện đạt.
- `git diff --check` đạt. Chỉ thay đổi web và tài liệu; không chạy lại kiểm thử backend/mobile trong đợt này. Chưa kiểm tra trình duyệt khác, thiết bị vật lý, production login hay triển khai production.

## Hoàn thiện giao diện v2 — 03/11/2026

- Thiết kế nền sáng, xanh emerald làm điểm nhấn, bộ nhận diện và khoảng cách thống nhất cho khách hàng/tài xế. Các thẻ dịch vụ dùng ảnh xe nền trong suốt thay biểu tượng đơn sắc; ảnh được decode theo kích thước hiển thị để giảm bộ nhớ.
- Cập nhật màn đặt xe, thanh hành động, bảng điều khiển tài xế, màn đăng nhập và phần hồ sơ/tài khoản. Các callback đặt xe, báo giá, nhận chuyến, đăng nhập và cập nhật hồ sơ giữ nguyên luồng xử lý hiện có.
- Bộ ảnh mới dùng công cụ imagegen built-in; prompt đầy đủ và đường dẫn asset của từng app nằm trong [vehicle-assets.json](design/vehicle-assets.json).
- Ảnh từ bản QA chạy native trên iOS Simulator iPhone 17 Pro, dùng dữ liệu mẫu: [đặt xe](screenshots/customer-app-v2.png), [tài xế](screenshots/driver-app-v2.png), [đăng nhập](screenshots/login-app-v2.png). Các ảnh v1 bên dưới được giữ để đối chiếu.
- QA bản đồ: endpoint mặc định bị reset kết nối khi kiểm tra từ host; các nguồn thay thế cũng chưa hiển thị tile trong simulator ở lần kiểm tra này. Ảnh tài xế có nền bản đồ trống; chưa kết luận nguyên nhân ở mạng, provider hay simulator. Các cờ provider dùng cho QA không được đưa vào bản build cuối.
- Bổ sung hiển thị thông báo và nút thử lại nếu chưa có tile thành công sau 8 giây; tự bỏ thông báo khi tile tải được. Bản đồ giữ marker và thao tác đặt điểm. Ghi công bản đồ hiển thị trực tiếp và có thể cấu hình bằng `MAP_ATTRIBUTION` khi đổi `MAP_TILE_URL`.
- `flutter test --no-pub`: **56/56 customer**, **60/60 driver**, tổng **116/116 đạt**. Có kiểm thử mới cho trạng thái bản đồ chưa sẵn sàng và nút thử lại; các kiểm thử màn 320 px, chữ 160%, bố cục ngang, biểu mẫu, phiên và Firebase đều đạt.
- Build APK debug và iOS Simulator debug thành công cho cả hai app từ `lib/main.dart`. Đã kiểm tra cấu hình cuối không còn entrypoint, nguồn tile hay cờ đăng nhập của bản QA; đã dọn simulator kiểm tra tạm. Analyze không có error/warning, còn 23 lint info có sẵn trên mỗi app.

## Thiết kế theo phong cách Grab — 03/11/2026

- Dùng nhận diện xanh/trắng, nền trung tính, thẻ dịch vụ có biểu tượng xe lớn và thanh thao tác nổi. Tên sản phẩm vẫn là Grap; tham khảo [Grab Transport](https://www.grab.com/vn/transport/).
- Khách hàng: phần đầu xanh, ô điểm đón/đến nổi bật; ba thẻ Xe máy/Ô tô 4 chỗ/Ô tô 7 chỗ; lối tắt địa chỉ đã lưu và an toàn đều mở chức năng hiện có. Đổi loại xe phải xem báo giá mới trước khi xác nhận.
- Tài xế: bản đồ chiếm vùng chính, thẻ thu nhập, nút GPS và làm mới trạng thái; bảng bật/tắt nhận chuyến ở dưới. Lời mời vẫn có thanh thao tác riêng và xuất hiện ở mọi tab. Chế độ phát triển vẫn có chọn/gửi vị trí thử nghiệm.
- Bản đồ giữ controller khi đổi tọa độ, kể cả khi ID địa điểm không đổi; căn đủ điểm đón/đến/tài xế và có nút căn lại sau khi kéo bản đồ.
- `flutter test --no-pub`: **55/55 customer**, **59/59 driver**, tổng **114/114 đạt**. Kiểm tra cả 320×640, 640×320 và text scale 160%.
- Analyze không có error/warning; mỗi app còn 23 lint info có sẵn về dấu ngoặc `if`.
- Build lại APK debug và iOS Simulator debug thành công cho cả hai app với thiết kế này.
- Ảnh bố cục từ widget thật, dữ liệu mẫu và nền bản đồ mô phỏng: [khách hàng](screenshots/customer-app-home.png), [tài xế](screenshots/driver-app-home.png). Bản chạy thật tải tile từ cấu hình `MAP_TILE_URL`; ảnh này không chứng minh khả năng tải bản đồ hay GPS trên thiết bị vật lý.

## Cập nhật UI mobile — 03/11/2026

- Khách hàng: chọn điểm đón/đến qua một bảng chọn gồm địa điểm gợi ý, địa chỉ đã lưu và bản đồ; chọn loại xe trước phần xem bản đồ. Giá và nút xem giá/xác nhận nằm cố định phía trên thanh điều hướng.
- Tài xế: lời mời nhận chuyến nằm cố định phía trên thanh điều hướng, kể cả khi đang ở tab Thu nhập/Tài khoản. Hiển thị riêng số tiền tài xế nhận và tiền cần thu khách; khóa nhận khi hết hạn hoặc đang xử lý.
- Cả hai app: tăng các cỡ chữ nhỏ lên tối thiểu 14, dùng màu chữ phụ đậm hơn, phân biệt trạng thái bằng màu và biểu tượng. Khung thao tác có bố cục riêng khi xoay ngang.
- Kiểm thử mới dùng màn hình 320×640 và 640×320, text scale 160%; kiểm tra nút còn bấm được sau cuộn/chuyển tab, đổi địa điểm, lấy báo giá mới khi hết hạn và chặn thao tác lặp khi đang xử lý.
- Toàn bộ `flutter test --no-pub`: **52/52 customer**, **56/56 driver**, tổng **108/108 đạt**. Các số lượng mobile trong bảng cũ bên dưới là kết quả trước đợt cập nhật này.
- Đã xem ảnh dựng từ widget thật ở 390×844 và 320×640 với font Roboto; dữ liệu giả lập và không tải tile mạng trong kiểm thử. Chưa nghiệm thu trên thiết bị vật lý.
- `flutter analyze --no-pub --no-fatal-infos`: không có error/warning; mỗi app còn **23 lint info** về dấu ngoặc của câu lệnh `if` trong mã có sẵn. Kết quả này thay cho kết quả analyze cũ ở bảng dưới.
- Build APK debug và iOS Simulator debug thành công cho cả hai app. Android còn cảnh báo tương thích Kotlin Gradle Plugin từ dependency `firebase_core`; cảnh báo không chặn build hiện tại.

## Đã chạy đạt

| Hạng mục | Kết quả | Bằng chứng / phạm vi |
| --- | --- | --- |
| Backend build | Đạt, 0 warning / 0 error | `dotnet build GrapSolution.sln --no-restore --disable-build-servers -m:1` |
| Backend tests | **31/31 đạt** | xUnit, WebApplicationFactory và SQLite thật trong file temp riêng |
| Web typecheck + production build | Đạt | `npm run build`, Vue/TS strict và Vite; đã tách route thành lazy chunks |
| Web E2E Chrome | **7/7 đạt** | `npm run test:e2e`, Chrome headless, backend và Vite local |
| npm audit | **0 vulnerability** | Sau cập nhật dependency và lockfile cuối |
| Customer app tests | **40/40 đạt** | 22 core/Dio/cache/use case + 12 UI + 6 booking controller, toàn bộ nằm trong app |
| Driver app tests | **45/45 đạt** | 22 core/Dio/cache/use case + 12 UI + 11 driving/onboarding, toàn bộ nằm trong app |
| Flutter analyze | Đạt, 0 issue | Hai project app độc lập, không có path dependency hoặc import package nội bộ cũ |
| Android customer | Build thành công | `mobile/apps/customer_app/build/app/outputs/flutter-apk/app-debug.apk` |
| Android driver | Build thành công | `mobile/apps/driver_app/build/app/outputs/flutter-apk/app-debug.apk` |
| iOS Simulator customer | Build thành công, không codesign | `mobile/apps/customer_app/build/ios/iphonesimulator/Runner.app` |
| iOS Simulator driver | Build thành công, không codesign | `mobile/apps/driver_app/build/ios/iphonesimulator/Runner.app` |
| PostgreSQL migration generation | Đạt | Bốn migration + `docs/api/migrations.sql`, SQL idempotent 906 dòng |
| OpenAPI snapshot | Đã xuất từ API đang chạy | 86 route paths trong `docs/api/openapi.json` |

Artifact build lớn được gitignore; source, lockfile và cấu hình đủ để build lại. Các artifact debug cuối cùng dùng ENABLE_DEV_LOGIN=true để thử local: Android Emulator gọi API/portal tại 10.0.2.2:5080/5173; iOS Simulator tại 127.0.0.1:5080/5173. Đây là bản demo phát triển, không phải cấu hình phát hành.

## Backend integration đã kiểm chứng

- API health/OpenAPI.
- Khách không đọc được admin và chuyến của người khác.
- 20 request cùng key chỉ tạo một Ride; khác payload cùng key trả 409.
- Hai khóa tạo chuyến khác nhau của một khách chỉ có một chuyến active.
- Quote hết hạn hoặc sai chủ không được dùng.
- Full flow: availability → GPS/heartbeat → offer → accept → arrive → PIN → start → complete → cash.
- Accept lần hai bị bác bỏ; đến điểm đón ở quá xa bị bác bỏ.
- PIN sai được persist attempts, không chuyển trạng thái; PIN không có trong driver snapshot.
- Không hủy thông thường khi đã IN_PROGRESS.
- Complete/cash replay không tạo thêm journal; debit = credit; assignment được giải phóng.
- Thu vượt remaining bị bác bỏ.
- GPS cũ lưu được nhưng không kéo latest lùi; sample lặp được dedupe.
- Complete không tiếp tục trả tọa độ sống; link chia sẻ sau terminal trả 410.
- Refresh rotation và token reuse thu hồi family.
- Upload ảnh giả MIME bị bác bỏ; file private chỉ chủ sở hữu/người có quyền xem được.
- Người lập không tự duyệt nộp công nợ; duyệt replay chỉ có một journal.

## Web E2E đã kiểm chứng

1. Đăng nhập mẫu và dashboard dùng API thật.
2. Các route vận hành render không có JavaScript page error.
3. Chi tiết chuyến tải snapshot có quyền và timeline.
4. Vai trò tài chính xem các bút toán cân bằng.
5. Viewport 390×844: không tràn ngang toàn trang; mở/đóng menu khi điều hướng.
6. Khách xem giá, đặt và hủy chuyến qua giao diện.

## QA giao diện

- [Đăng nhập desktop](screenshots/login-desktop.png)
- [Dashboard desktop](screenshots/dashboard-desktop.png)
- [Dashboard mobile](screenshots/dashboard-mobile.png)

Đã kiểm tra screenshot trực tiếp. QA phát hiện tile endpoint cũ hiển thị yêu cầu API key; đã chuyển mặc định sang tile URL OpenStreetMap cấu hình được. UI có attribution, giữ cache mặc định và không có tính năng tải hàng loạt/offline. Khi triển khai thương mại cần provider phù hợp và tuân thủ [tile usage policy](https://operations.osmfoundation.org/policies/tiles/).

## Giới hạn của kết quả

Chưa chạy database integration/concurrency trên PostgreSQL thật, Docker Compose, load test, SMS/gateway/push sandbox hoặc bài test thiết bị vật lý. Build iOS Simulator không thay thế IPA ký để phát hành. Chưa diễn tập restore và chưa chứng minh tracking nền khi khóa màn hình.

Không suy ra đã đạt toàn bộ AT-01…AT-40 từ số lượng test local. Ma trận những yêu cầu còn thiếu nằm tại [IMPLEMENTATION_STATUS.md](IMPLEMENTATION_STATUS.md).

## Kiểm thử bổ sung trong đợt rà soát mobile

- App restart vẫn gửi lại complete bằng key, expectedVersion và GPS gốc; cash giữ operationId; logout loại queue account cũ.
- 10 response 401 dùng một refresh flight; refresh cũ không thay account mới.
- Private upload gửi bytes với Content-Type/Length đúng; PIN không được persist vào journal.
- Widget: sửa hồ sơ/email, tạo và phản hồi ticket, mark-read notification, countdown hết hạn và toàn luồng onboarding.
- Provider: refresh chậm không ghi đè start; assignment bị revoke được xóa khỏi state.
- HTTP: tài xế mới nộp đủ giấy tờ, bị từ chối, nộp lại và được duyệt; hồ sơ pending không thể sửa.
- HTTP: no-show cần chờ và contact attempt; driver cũ không thể xem live ride từ history list.

## Kiểm thử bổ sung lịch sử và quyền riêng tư

- Backend: cursor có timestamp trùng và có chuyến mới chen vào, chữ ký giả, đổi bộ lọc/đổi chủ, khoảng ngày không hợp lệ.
- Backend: saved places idempotent/nhãn duy nhất, ownership, version conflict và xóa PII địa chỉ; liên hệ có consent, giới hạn 5, số mã hóa và kiểm tra xóa số.
- Backend: yêu cầu xóa bị chặn bởi chuyến đang diễn ra, chống trùng, kiểm tra lại, chỉ SecurityAdmin xem xét, người dùng rút yêu cầu; không cho quyết định COMPLETED giả.
- Backend: đánh giá 1 lần rồi sửa, sau 24 giờ từ EndedAt bị khóa; response idempotency mới được mã hóa và replay tiền mặt/chuyến vẫn đạt.
- Mobile: cache liên hệ dùng được sau restart ngoại tuyến, TTL 30 ngày, xóa khi logout, phản hồi cũ không lọt sang tài khoản mới, tải chậm không khôi phục số đã xóa.
- Widget: tải thêm giữ trang trước, form sửa địa chỉ, chọn sao và gửi nhận xét, không hiện nút đánh giá quá hạn, consent trước khi lưu liên hệ, không tạo trùng yêu cầu xóa đang mở.
- Chrome E2E: tạo yêu cầu bằng khách thật, SecurityAdmin yêu cầu bổ sung và trả lời ticket liên quan, khách rút yêu cầu sau kiểm thử. Ảnh kiểm tra: [privacy-request-desktop.png](qa/privacy-request-desktop.png).

Đợt gộp core đã đạt 27 customer + 31 driver = 58 lượt kiểm thử mobile. Sau đợt tối ưu khôi phục dữ liệu/phiên/thu tiền, bộ hiện tại đạt **40 customer + 45 driver = 85 lượt kiểm thử mobile**. Các bài core/UI trước đây chạy tại package nay nằm trong test của từng app; số lượt tăng do hai project kiểm thử độc lập, không phải thêm 26 hành vi mới. Backend 31 và web 7 đã đạt ở đợt trước, mã backend/web không thay đổi trong lần gộp này. Không bao gồm kiểm thử thiết bị vật lý hay PostgreSQL thật.

## Kiểm chứng cấu trúc app độc lập

- Đã đưa mã và toàn bộ kiểm thử package cũ vào `mobile/apps/customer_app` và `mobile/apps/driver_app`, sau đó gỡ thư mục package cũ.
- Hai pubspec khai báo Dio 5.11.1, secure storage, geolocator, SignalR, map và các dependency giao diện trực tiếp. Hai lockfile đã cập nhật; package_config không còn package nội bộ bên ngoài app.
- `core/network/dio_config.dart` giữ base URL `/api/v1`, timeout 12/20 giây và JSON headers; provider tạo Dio riêng cho app và đóng kết nối khi dispose. ApiClient giữ bearer, refresh single-flight, session guard, idempotency và upload bytes đã kiểm thử.
- Màn hình nghiệp vụ nằm trong features; core/theme/widgets không import features. MaterialApp và reset navigation khi đổi user nằm trong `lib/app/grap_app.dart`.
- CI, README gốc và README của từng app dùng pub get/analyze/test ngay trong project app; không còn bước chạy package riêng.

## Đợt tối ưu khôi phục dữ liệu, phiên và thu tiền

- Hai app: analyze đạt 0 issue; test trực tiếp trong từng project đạt 40/40 và 45/45.
- Customer provider: giữ active ride khi history 503 ở startup/refresh; polling hỏi active nhưng không hỏi history liên tiếp trong khoảng 30 giây; manual refresh và Ride version mới tải lại ngay; background không gọi active, resume có recovery; cached active bị xóa khi detail 404.
- Driver provider: history/earnings 503 không che assignment; polling giới hạn extras; cash đọc detail trực tiếp, không rollback local khi history/earnings lỗi; detail lỗi thì khóa thu tiếp tới snapshot mới; pending cash journal chặn cash mới; support pending không ngăn GPS/heartbeat; cached active không giữ assignment đã bị thu hồi.
- Transport/storage: session JSON sai shape trả về đăng nhập; journal bỏ entry hỏng nhưng giữ command/phiên hợp lệ; contacts cache hỏng trả null; restore read chậm và refresh write chậm không khôi phục account cũ trên disk; retry vẫn 401 thu hồi phiên một lần; refresh sai shape/user ID không thay session.
- Widget: expectedVersion conflict khóa nút lưu cũ và thao tác đóng/tải bản mới làm danh sách được tải lại.

Các test mới ở `test/core/resilience_test.dart`, `test/customer_controller_test.dart`, `test/driver_controller_test.dart`, `test/features/journey_screens_test.dart` trong app tương ứng. Đây là test fake transport/storage và provider/widget, chưa phải thử lỗi mạng thật trên thiết bị vật lý. Mã backend/web không thay đổi trong đợt này; các kết quả 31 backend/7 web trong bảng thuộc đợt kiểm chứng trước.
