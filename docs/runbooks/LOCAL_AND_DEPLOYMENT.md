# Runbook phát triển và triển khai

## Local

Chạy hai terminal theo README. Nếu port bị chiếm, dừng tiến trình do bạn quản lý hoặc đổi API port và Vite proxy; không chạy hai API cùng ghi file SQLite ở hai thư mục khác nhau.

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

HTTP map adapter nhận `POST {Maps__BaseUrl}/route` với pickup/dropoff/serviceTypeCode; trả distanceMeters/durationSeconds/geometry. Cần triển khai adapter theo provider đã chọn, kiểm tra quota và license. Autocomplete/geocoding thật còn phải nối.

SMS hiện cố ý trả 503. Development dùng tài khoản mẫu riêng; không có OTP mặc định/hardcode được trả từ API. Push, gateway, promo và self-service payout chưa bật.

Firebase client Android/iOS đã được tích hợp trong cả hai app. Để bật gửi push trên backend và cấu hình APNs, làm theo [runbook Firebase mobile](FIREBASE_MOBILE.md).

Nền bản đồ local dùng tile OpenStreetMap; web có `VITE_MAP_TILE_URL`, mobile có `--dart-define=MAP_TILE_URL=...` để chuyển provider. Không dùng máy chủ tile cộng đồng như hạ tầng có SLA cho pilot thương mại. Phải giữ attribution và chính sách cache của provider; không bật tải tile hàng loạt.

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
