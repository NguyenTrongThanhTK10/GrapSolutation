# Runbook phát triển và triển khai

## Local

### Chạy debug từng project

Các lệnh dưới đây dùng shell macOS/Linux (zsh/bash). Mở mỗi terminal mới tại thư mục gốc `GrapSolution`; chạy API trước, sau đó portal và các app mobile cần thử. Giữ terminal của từng project đang chạy.

| Project | Thư mục | Chế độ / địa chỉ local |
| --- | --- | --- |
| Backend API | `backend` | .NET Debug, môi trường Development, `http://127.0.0.1:5080` |
| Admin portal | `admin_portal` | Vite development server, `http://127.0.0.1:5173` |
| App khách hàng | `mobile/apps/customer_app` | Flutter debug trên Android/iOS |
| App tài xế | `mobile/apps/driver_app` | Flutter debug trên Android/iOS |

Cài .NET SDK 10 theo `backend/global.json`, Node.js ≥ 20.19 (phiên bản trong `admin_portal/.nvmrc`) kèm npm, Flutter 3.47.6/Dart 3.13.5. Android cần Android SDK; iOS Simulator cần macOS và Xcode. Dùng `flutter doctor` để kiểm tra toolchain mobile. Các lệnh local dùng SQLite tự tạo và cấu hình mặc định, không cần Docker hay tạo file `.env`. `backend/.env.example` chỉ liệt kê biến cấu hình; API không tự nạp file `.env`.

**Terminal 1 — Backend API:**

```sh
cd backend
dotnet restore
dotnet run --project src/GrapSolution.Api --configuration Debug -- --environment Development --urls http://127.0.0.1:5080
```

Kiểm tra API bằng `curl http://127.0.0.1:5080/health/ready` trong terminal khác; OpenAPI tại `http://127.0.0.1:5080/openapi/v1.json`. `Debug` là cấu hình build, `Development` bật dữ liệu/tài khoản mẫu và OpenAPI. Để dùng hot reload, dừng API bằng `Ctrl+C`, rồi chạy lệnh sau tại `backend`:

```sh
ASPNETCORE_ENVIRONMENT=Development \
ASPNETCORE_URLS=http://127.0.0.1:5080 \
dotnet watch --project src/GrapSolution.Api run --configuration Debug
```

Chạy bằng CLI chưa gắn debugger .NET. Để dừng ở breakpoint C#, dùng debugger của IDE attach vào tiến trình `GrapSolution.Api` đang chạy ở cấu hình Debug.

**Terminal 2 — Admin portal:**

```sh
cd admin_portal
nvm use # chỉ chạy nếu đã cài nvm
npm ci
npm run dev -- --strictPort
```

Mở `http://127.0.0.1:5173`. Vite chuyển tiếp `/api` và `/hubs` tới API cổng 5080, nên để `VITE_API_BASE_URL` trống khi dùng cấu hình này. Portal dùng script `dev` để chạy phát triển; mở DevTools của trình duyệt để xem Network/Console và đặt breakpoint trong Sources. Sửa Vue/TypeScript sẽ tự cập nhật qua Vite.

**Terminal 3 và 4 — Hai app Flutter:** dùng [các lệnh `flutter run --debug` trong README](../../README.md#chạy-mobile-ở-chế-độ-debug), mỗi app một terminal. Chạy `flutter pub get` riêng trong từng app trước lần đầu hoặc khi dependency thay đổi. Không chạy `flutter run` tại thư mục `mobile` vì mỗi app là project độc lập.

Mở emulator/simulator trước, dùng `flutter devices` để lấy ID rồi truyền `-d <DEVICE_ID>` vào lệnh. Nếu chưa mở Android Emulator, có thể liệt kê và khởi động AVD bằng:

```sh
flutter emulators
flutter emulators --launch "<EMULATOR_ID>"
flutter devices
```

Thay `<EMULATOR_ID>` bằng ID trong `flutter emulators`; ID này có thể khác ID thiết bị dùng với `flutter run -d`. Trên macOS, mở iOS Simulator bằng `open -a Simulator`, rồi lấy ID bằng `flutter devices`.

| Thiết bị / cách kết nối | `API_BASE_URL` | `PORTAL_BASE_URL` |
| --- | --- | --- |
| Android Emulator (mạng mặc định) | `http://10.0.2.2:5080` | `http://10.0.2.2:5173` |
| iOS Simulator trên máy Mac chạy API | `http://127.0.0.1:5080` | `http://127.0.0.1:5173` |
| Android có ADB reverse cả hai cổng | `http://127.0.0.1:5080` | `http://127.0.0.1:5173` |

Không thêm `/api/v1` vào `API_BASE_URL`; client tự gắn prefix. Bật `--dart-define=ENABLE_DEV_LOGIN=true` để chọn tài khoản mẫu khi API chạy Development. Trong terminal Flutter: `r` hot reload, `R` hot restart, `q` thoát. Đổi `API_BASE_URL`, `PORTAL_BASE_URL`, `ENABLE_DEV_LOGIN` hoặc `MAP_TILE_URL` cần dừng rồi chạy lại, vì các giá trị này được nạp khi biên dịch.

### Android qua ADB reverse

Dùng cách này khi muốn app Android gọi API/portal tại `127.0.0.1` như cấu hình VS Code hiện có, hoặc chạy trên điện thoại Android qua USB. Bật USB debugging và chấp nhận kết nối trên điện thoại nếu dùng máy thật. Với ID ví dụ `emulator-5554`:

```sh
adb devices
adb -s emulator-5554 reverse tcp:5080 tcp:5080
adb -s emulator-5554 reverse tcp:5173 tcp:5173
adb -s emulator-5554 reverse --list
```

Thay ID trong các lệnh ADB và lệnh Flutter nếu thiết bị khác. Sau đó, tại thư mục `mobile/apps/customer_app` hoặc `mobile/apps/driver_app`, chạy:

```sh
flutter pub get
flutter run --debug -d emulator-5554 \
  --dart-define=ENABLE_DEV_LOGIN=true \
  --dart-define=API_BASE_URL=http://127.0.0.1:5080 \
  --dart-define=PORTAL_BASE_URL=http://127.0.0.1:5173
```

Chạy lại ADB reverse nếu emulator khởi động lại hoặc thiết bị kết nối lại và mất ánh xạ cổng. `127.0.0.1` trong app Android chỉ trỏ tới API trên máy phát triển khi có ánh xạ này.

### Debug bằng VS Code

Mở thư mục gốc `GrapSolution`, cài extension Flutter/Dart và khởi động API/portal bằng các lệnh ở trên. Cấu hình hiện tại nằm trong [launch.json](../../.vscode/launch.json) và [tasks.json](../../.vscode/tasks.json):

- **customer_app**: nhấn F5 để chạy debug trên `emulator-5554`; task tự ADB reverse cổng 5080/5173, bật đăng nhập mẫu và truyền API/portal `127.0.0.1`. Cần có `adb` trong PATH và emulator đúng ID. Cấu hình này cũng chọn nguồn tile thay thế như mục Mạng và provider.
- **driver_app**: cấu hình hiện có dùng thiết bị đang chọn, chưa truyền `ENABLE_DEV_LOGIN` hay URL portal. Để thử tài khoản mẫu ngay, dùng lệnh CLI của app tài xế trong README.
- Với app đã chạy bằng CLI ở chế độ debug, dùng lệnh **Debug: Attach to Flutter Process** trong Command Palette, nhập VM Service URI được in trong terminal `flutter run`, rồi đặt breakpoint Dart. Dùng URI của đúng app nếu có nhiều phiên đang chạy.

### Xử lý lỗi khi chạy local

Nếu port bị chiếm, dừng tiến trình do bạn quản lý hoặc đổi API port và Vite proxy cùng các URL/ADB reverse liên quan; không chạy hai API cùng ghi file SQLite ở hai thư mục khác nhau. Portal chạy với `--strictPort` sẽ báo lỗi thay vì tự chuyển sang cổng khác.

Nếu app không kết nối được API, kiểm tra `/health/ready` trên máy host trước, sau đó kiểm tra ID thiết bị và bảng URL ở trên. Nếu không thấy tài khoản mẫu, kiểm tra cả API Development lẫn cờ `ENABLE_DEV_LOGIN=true`, rồi dừng/chạy lại app. `No supported devices connected` cần mở emulator/simulator hoặc kết nối thiết bị trước khi chạy `flutter run`.

Không có tài xế sẵn sàng trên dashboard lúc mới seed là đúng: tài xế mẫu chưa online, GPS có timestamp cũ. Đăng nhập app tài xế, bật online và gửi vị trí/heartbeat để được dispatch.

Không nhận được offer: kiểm tra cùng loại xe, cùng vùng, trạng thái được duyệt, giấy tờ còn hạn, vị trí/heartbeat mới trong 30 giây và không có assignment/open offer khác. Offer 15 giây nên giữ cửa sổ tài xế ở foreground.

Đến nơi/hoàn tất bị từ chối: kiểm tra timestamp trong 30 giây, accuracy ≤ 100 m và khoảng cách đến điểm xác nhận. Local có vị trí thử nghiệm tại từng địa điểm mẫu. Không bỏ kiểm tra tọa độ chỉ để demo thành công.

## Database

SQLite local được tạo tự động. Khởi động thêm bảng mới bằng schema additive không xóa dữ liệu cũ; không thay thế migration nâng cấp database production. Nếu muốn bộ seed sạch, tự sao lưu rồi dùng đường dẫn SQLite mới qua `ConnectionStrings__Sqlite`; không cần sửa/xóa DB để hoàn tất một chuyến demo.

PostgreSQL dùng EF migrations:

```sh
cd backend
dotnet tool restore
dotnet ef migrations script --idempotent --project src/GrapSolution.Infrastructure --startup-project src/GrapSolution.Api --output ../docs/api/migrations.sql
```

Review script trước triển khai. API hiện tự chạy Migrate ở startup PostgreSQL cho tiện local; production nên chạy migration riêng dưới tài khoản có quyền DDL trước khi rollout API với quyền tối thiểu.

Không tự đánh dấu payment succeeded, sửa driver balance hoặc xóa ledger để xử lý sự cố. Dùng command và journal điều chỉnh có thiết kế, actor và reason.

## Mạng và provider

HTTP map adapter nhận `POST {Maps__BaseUrl}/route` với pickup/dropoff/serviceTypeCode; trả distanceMeters/durationSeconds/geometry. Cần triển khai adapter theo provider đã chọn, kiểm tra quota và license. Autocomplete đi qua `GET {Maps__BaseUrl}/autocomplete?q=...` và trả `{items:[{placeId,latitude,longitude,address}]}`; adapter thật phải triển khai endpoint này cùng `/route`. Khi có Maps__BaseUrl, lỗi tìm kiếm trả 503 và app vẫn cho chọn ghim; không thay bằng dữ liệu demo. Reverse geocoding tự lấy tên đường từ GPS vẫn chưa tích hợp.

SMS hiện cố ý trả 503. Development dùng tài khoản mẫu riêng; không có OTP mặc định/hardcode được trả từ API. Push, gateway, promo và self-service payout chưa bật.

Firebase client Android/iOS đã được tích hợp trong cả hai app. Để bật gửi push trên backend và cấu hình APNs, làm theo [runbook Firebase mobile](FIREBASE_MOBILE.md).

Nền bản đồ local dùng tile OpenStreetMap; web có `VITE_MAP_TILE_URL`, mobile có `--dart-define=MAP_TILE_URL=...` để chuyển provider. Không dùng máy chủ tile cộng đồng như hạ tầng có SLA cho pilot thương mại. Phải giữ attribution và chính sách cache của provider; không bật tải tile hàng loạt.

Nếu ảnh tile báo `Connection reset by peer`, thử chính URL bằng `curl -I -A 'GrapCustomer/0.1' '<URL ảnh>'` trên máy host. Nếu host cũng lỗi thì cần kiểm tra đường mạng/VPN/firewall tới nhà cung cấp. Lỗi này độc lập với API local. App giữ thông báo và nút **Thử lại bản đồ** khi không tải được ảnh; ảnh trong suốt thay cho tile lỗi không được coi là tải bản đồ thành công.

Bản đồ ở cả hai app theo dõi toàn bộ tile trong vùng đang xem, kiểm tra lại khi kéo/phóng to và hiển thị thông báo sau 8 giây nếu còn thiếu ảnh. Một tile tải thành công không che lỗi của phần còn lại. Nút **Thử lại bản đồ** tạo phiên tải mới và giữ nguyên vị trí camera; các ảnh hợp lệ vẫn dùng cache. App không tự chuyển nguồn tile khi lỗi.

Khi người dùng kéo hoặc phóng to, marker tài xế vẫn cập nhật nhưng camera giữ vùng đang xem. Nhấn **Xem toàn bộ hành trình** để căn lại và tiếp tục tự theo dõi; ở trang chính tài xế, nút lấy vị trí GPS cũng căn lại camera. Chọn điểm đón/đến mới sẽ căn lại theo các điểm mới. Trong màn chọn ghim, thao tác chọn điểm giữ mức zoom; ghim thủ công được ưu tiên hơn kết quả GPS trả chậm và cần mô tả mới khớp với vị trí đã chọn.

Cấu hình VS Code **customer_app** dành cho Android Emulator `emulator-5554`: tự nối cổng API/portal qua ADB, bật tài khoản mẫu, và đặt `MAP_TILE_URL=https://tile.openstreetmap.de/{z}/{x}/{y}.png` cho xem thử local khi miền `.org` không truy cập được. Dừng và chạy lại cấu hình để áp dụng `--dart-define`; hot reload không đổi các giá trị này. Nguồn tile thay thế chỉ dùng cho xem thử phát triển, có thể hiện thêm tên địa danh tiếng Đức; đọc [điều kiện của OSM Germany](https://openstreetmap.de/germanstyle/) trước khi sử dụng ngoài local. Khi phát hành, cấu hình nhà cung cấp phù hợp cùng attribution của họ.

## Release mobile

Android release không dùng debug keystore. Cấu hình signing riêng, application ID, store policies và secret trong CI. Không bật ENABLE_DEV_LOGIN ở release. iOS cần team/provisioning riêng; bản Simulator đã kiểm tra không phải IPA ký để phát hành.

App driver hiện chỉ gửi GPS foreground. Trước pilot cần Android foreground service phù hợp, iOS background capability/quyền đúng use case, queue bounded và ma trận thử nghiệm: khóa màn hình, battery saver, revoke GPS, kill process và đổi mạng.

## Backup và restore

Tối thiểu cần backup PostgreSQL và storage private, keyring Data Protection, cấu hình phiên bản và bản phát hành. Không in key/token/PIN vào log hoặc ticket. Thực hiện restore vào môi trường cách ly, kiểm tra journal cân bằng, reference, phiên bị thu hồi và quyền file.

Chưa có restore drill thực tế trong lần triển khai này; không được coi tài liệu hướng dẫn là bằng chứng đã đạt RPO/RTO.

## Outbox và sự cố

Trang cấu hình cho biết pending/dead-letter. Worker retry exponential backoff, dừng tự phát sau 10 attempt. Khi điều tra, giữ nguyên eventId và xác minh nghiệp vụ đã commit trước khi replay; không tạo operation key tài chính mới để “thử lại”.

SOS local chỉ lưu cảnh báo và tạo ticket khẩn. UI chỉ báo đã được tiếp nhận khi SupportAgent xác nhận. Cần đầu mối vận hành và escalation thật trước khi quảng bá tính năng ứng cứu.

## Chạy thử các luồng vừa bổ sung

1. Khởi động API Development và portal theo README. Trên Android Emulator dùng API `http://10.0.2.2:5080`, iOS Simulator dùng `http://127.0.0.1:5080`.
2. Đăng nhập Customer bằng tài khoản mẫu → Tài khoản → Địa chỉ đã lưu → thêm địa chỉ bằng ghim và mô tả; quay lại Đặt xe chọn địa chỉ đó làm điểm đón/đến.
3. Hành trình → lọc ngày/trạng thái → Tải thêm → Chi tiết → xem cước/đã thu/còn lại/timeline; đánh giá sao và nhận xét nếu còn hạn 24 giờ. Đặt lại tuyến luôn lấy báo giá mới.
4. Liên hệ tin cậy → nhập người/số và xác nhận đồng ý. Sau khi đã tải danh sách thành công, ngắt mạng rồi mở lại để xem bản lưu có nhãn ngoại tuyến; chạm gọi chỉ mở dialer của thiết bị. Logout xóa bản lưu này.
5. Yêu cầu xóa tài khoản → nhập lý do; xem nghĩa vụ chưa hoàn tất. Dùng `staff-SecurityAdmin` trên portal → Cấu hình → Yêu cầu xóa tài khoản để phản hồi/kiểm tra. Người dùng mở ticket liên quan hoặc rút yêu cầu. Không coi trạng thái IN_REVIEW là đã xóa dữ liệu.

Các APK debug hiện có bật development login để dùng trên emulator. Khi build release, bỏ ENABLE_DEV_LOGIN và cấu hình đầy đủ SMS/identity provider; không phân phối bản demo như ứng dụng production.
