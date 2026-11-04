# Đối chiếu đặc tả và trạng thái triển khai

Ngày kiểm tra: **03/11/2026**, múi giờ Asia/Ho_Chi_Minh. Nguồn: `GRAP_SOLUTION_DAC_TA_HE_THONG.md`, phiên bản 1.0.

## Kết quả phân tích

Tài liệu mô tả một nền tảng vận tải nhiều tác nhân, không chỉ một trang đặt xe. Ba vòng đời phải tách biệt: **Ride**, **Payment** và **Settlement**. Điểm rủi ro chính là nhận chuyến đồng thời, khôi phục sau mất response, phân quyền theo tài nguyên, PIN, dữ liệu vị trí và việc ghi nhận tiền mặt vào sổ cái.

Các quyết định áp dụng trong mã nguồn:

- Backend modular monolith .NET 10, tách Domain/Application/Infrastructure/Api. Worker chạy cùng host API ở bản local; chưa tách process Worker riêng.
- Web quản trị Vue 3/TypeScript/PrimeVue theo yêu cầu người dùng. Leaflet cho bản đồ nền, Chart.js cho số liệu API, layout đáp ứng desktop/mobile.
- Hai project Flutter/Riverpod độc lập. Mỗi app chứa core/domain/application/data/network/providers/theme/widgets và các màn hình trong features; dùng Dio trực tiếp, không còn package core/design system ngoài app.
- PostgreSQL là database triển khai; migration tạo kiểu `bigint`, `timestamp with time zone`, FK và filtered unique index. SQLite là adapter phát triển/kiểm thử local riêng.
- Giá chốt từ Quote, VND nguyên, thời hạn 120 giây. Bản giá được phát hành theo version; không cập nhật snapshot chuyến cũ.
- Dispatch tuần tự, offer TTL 15 giây, deadline 120 giây, bán kính mở rộng 1/3/5 km. Eligibility dựa DB, session, giấy tờ, presence, location và assignment.
- Tiền mặt thuộc P0. Gateway, voucher và payout tự phục vụ chưa được bật; không hiển thị các luồng này như đã tích hợp.
- Route fixture local chỉ hỗ trợ các địa điểm mẫu. Khi cấu hình provider, backend gọi HTTP adapter; không chuyển khoảng cách đường chim bay thành báo giá thật.

## Ma trận triển khai

| Nhóm / yêu cầu | Trạng thái thực tế | Ghi chú nghiệm thu còn lại |
| --- | --- | --- |
| E01 — Repo, phân lớp, UI, CI | Đã có source, build, workflow và hướng dẫn | CI đã viết, chưa có bằng chứng chạy trên GitHub |
| E02 — Phiên, JWT, refresh rotation/reuse, logout | Đã chạy và kiểm thử local | Đăng nhập nhân sự production cần OIDC/MFA; đã có tiếp nhận/xem xét/rút yêu cầu xóa, chưa có tác vụ xóa và retention tự động |
| C-FR-01 — OTP | Có challenge/verify, TTL/attempt/rate limit và port SMS | Đã bổ sung UI countdown/gửi lại theo thời hạn server; SMS thật vẫn chưa cấu hình, chưa E2E OTP |
| C-FR-02 — Hồ sơ | Có chỉnh tên/email, saved places CRUD theo tọa độ và chọn lại khi đặt xe, kiểm tra version/ownership | Đổi số và avatar chưa triển khai; xóa dữ liệu cuối cùng chờ retention và quy trình xử lý |
| C-FR-03/04 — Điểm đón, tuyến, Quote | Có fixture, polygon check, giá version, expiry, ownership; native chọn ghim bản đồ/GPS hoặc nhập mô tả thủ công; countdown báo giá | Autocomplete/geocoding provider thật chưa nối; chưa có PostGIS spatial index |
| C-FR-05 — Tạo chuyến | Đã có, kiểm thử 20 replay cùng khóa và hai khóa cạnh tranh | Cần kiểm chứng đa instance trên PostgreSQL thật |
| D-FR-01 — Hồ sơ/giấy tờ | Đã có native onboarding: lưu xe, chụp/chọn ảnh, ngày hết hạn, upload private, submit, nhận lý do từ chối và nộp lại; version upload bất biến khi review | Cần storage/scanning provider production, chính sách giấy tờ vùng thật và kiểm tra camera/photo picker trên thiết bị vật lý |
| D-FR-02/03 — Availability/offer | Đã có, chặn thiết bị khác, stale GPS, offer TTL, accept có transaction | Thông tin offer điểm đến đang dùng policy ẩn trước khi nhận; cần chốt chính sách D13 |
| C-FR-06, D-FR-04/05 — Đón/PIN/start | Đã có ở web/mobile và kiểm thử API | Luồng ngoại lệ GPS có bằng chứng chưa hoàn thiện; kiểm thử thiết bị thật còn thiếu |
| D-FR-06 — Hoàn tất/thu tiền | Đã có, chốt nghĩa vụ riêng và retry-safe | Đã lưu command hoàn tất/thu tiền vào secure storage, giữ nguyên body/key khi mở lại; UI có kiểm tra/gửi lại. GPS quá cũ ở command chưa commit vẫn cần xác nhận mới |
| C-FR-07, D-FR-07 — Hủy/release/no-show | Có lệnh hợp lệ, phí hủy P0 = 0, release đóng assignment và xoay PIN | Đã có native no-show, ghi nhận thử liên hệ sau arrival, điều kiện chờ và kết thúc sớm có lý do. Liên hệ hiện do tài xế khai báo; chưa có bằng chứng từ telecom provider |
| E07 — GPS/realtime/recovery | Có sample history/dedupe, latest không lùi, SignalR, polling, REST recovery | Chưa có Redis, push, offline GPS buffer và foreground/background location service hoàn chỉnh |
| E09 — Payment/cash/ledger | Đã có, payment riêng, bút toán kép, số dư pending/available/debt | Cần kế toán duyệt hệ thống tài khoản và kỳ Settlement chính thức |
| A-FR-06/07 — Nộp công nợ | Có maker/checker, reference/evidence, approval idempotent và journal | Không tích hợp ngân hàng; người duyệt phải đối chiếu bằng chứng bên ngoài |
| A-FR-01/03 — Dashboard/chuyến | Đã có API/UI, filter, timeline, reassign/end-early commands | Nhiều query hiện lấy dữ liệu trong bộ nhớ; chưa phù hợp tải lớn |
| A-FR-04 — Giá/vùng | Có policy draft/publish/effective, polygon availability và xem trước giá | Chưa có editor polygon/giờ phục vụ và bước review giá bởi nhân sự độc lập |
| A-FR-05/11 — Hạn chế/audit | Có role/scope, revoke session, audit append-only tại application | Chưa có UI phân quyền/MFA, PII access audit đầy đủ và hạn mức phức tạp |
| A-FR-08 — Support/SOS | Ticket/messages/transitions, inbox/detail/reply native, incident và xác nhận tiếp nhận | Chưa có SLA worker/escalation tự động; chưa có đầu mối ứng cứu theo vùng |
| C-FR-09 — Share/safety | Token random/hash/expiry/revoke; native tạo/sao chép/thu hồi link; chặn GPS sau terminal và chặn driver cũ đọc live ride qua history | Trusted contacts đã có ở dòng riêng bên dưới; đầu mối khẩn cấp theo vùng và masking telecom chưa hoàn thiện |
| C-FR-08 — Lịch sử/đánh giá | Keyset cursor ký theo tài khoản/bộ lọc; native tải thêm, lọc ngày/trạng thái; biên nhận cước/thanh toán/timeline, sao và nhận xét trong 24 giờ sau hoàn tất; đặt lại tuyến | Cửa sổ 24 giờ hiện cố định; nhãn đánh giá và hóa đơn điện tử chưa triển khai |
| C-FR-09 — Liên hệ tin cậy | Hai app thêm/sửa/xóa tối đa 5 liên hệ có consent, số mã hóa; cache secure storage theo account TTL 30 ngày, dialer ngoại tuyến | Chưa tích hợp masking telecom hoặc đầu mối khẩn cấp theo vùng |
| Quyền riêng tư — Xóa tài khoản | Request có ticket, kiểm tra active ride/payment/số dư driver, rút yêu cầu; SecurityAdmin xem xét và phản hồi theo vùng | Không xác nhận đã xóa khi mới tiếp nhận; tác vụ xóa/anonymize và chính sách retention còn thiếu |
| A-FR-10 — CSV | Xuất dữ liệu đang có quyền trên trang hiện tại, bảo vệ CSV formula injection | Background export, quota, private expiring URL chưa triển khai |
| E11 — Hardening/pilot | Có test local, widget/provider/transport, xử lý partial failure và race storage/session, native build và runbook | Chưa load test, PG concurrency, background-device, security review hoặc restore drill |
| E12/E13 — Gateway/voucher/payout | Chưa triển khai, feature flag tắt | Cần provider/hợp đồng và nghiệm thu P1 riêng |
| E14 — P2 | Chưa triển khai | Theo đặc tả: đặt lịch, nhiều điểm dừng, doanh nghiệp, đội xe cần backlog riêng |

## Bất biến đã được bảo vệ

1. Một active Ride/khách; một active Assignment/tài xế và mỗi Ride; một open offer/tài xế và Ride.
2. Idempotency scope theo actor/route/key và hash payload; replay đọc kết quả đã commit trước khi kiểm tra version cũ.
3. Complete đóng Assignment, tạo Payment và entitlement journal trong cùng transaction; thu tiền là lệnh riêng.
4. Tiền thực thu không vượt remaining; ledger không sửa/xóa qua EF; posting phải cân debit/credit.
5. Phiên bị revoke không dùng API tiếp; hub chỉ nhận group theo session do server cấp. Publisher chỉ gửi tới phiên còn hiệu lực trong scope.
6. PIN không trả cho tài xế, sai PIN được lưu attempts kể cả khi command bị bác bỏ; khóa sau 5 lần.
7. Chuyến terminal không trả vị trí sống của tài xế; link chia sẻ terminal trả 410.
8. GPS mất không làm mất assignment hoặc tự kết thúc chuyến.

## Những điều chưa được chứng minh

Không coi bản này đã đạt điều kiện hoàn thành P0 ở chương 24.4. Chưa có PostgreSQL/Docker daemon để chạy integration trên engine triển khai; build native chưa thay thế thử nghiệm trên hai thiết bị thật. Chính sách giá, thuế, giấy tờ, SOS, retention và kế toán ở chương 27 vẫn cần chủ sản phẩm xác nhận trước phát hành.

## Đợt rà soát và bổ sung mobile

Xem [REVIEW_AND_COMPLETION.md](REVIEW_AND_COMPLETION.md) để theo dõi chi tiết file thay đổi, lỗi trạng thái/phiên đã sửa và kiểm thử bổ sung. Tracking nền, provider thật, tác vụ xóa dữ liệu cuối cùng và các hạng mục còn ghi trong bảng chưa được coi là hoàn tất.

## Tối ưu bổ sung ở mobile

Chuyến hiện tại được phục hồi dù tải history/earnings lỗi. Khi polling mà Ride không đổi, history/earnings chỉ tải theo khoảng 30 giây; kéo xuống làm mới hoặc Ride đổi version tải ngay. App khách dừng xử lý tín hiệu khi xuống nền, phục hồi khi resume. Thu tiền có kiểm tra journal chưa xác nhận và khóa gửi thêm cho tới khi đủ điều kiện đọc/xác nhận snapshot.

Dio client kiểm tra session/cache/journal local, serialize ghi phiên, bảo vệ cả đọc storage chậm và refresh write chậm khi đổi account. Form gặp version conflict yêu cầu tải bản mới trước khi tiếp tục lưu. Xem đợt 7 trong báo cáo rà soát và VALIDATION.md để biết kiểm chứng cụ thể.


## Thống kê cá nhân — 04/11/2026

Hai app đã có báo cáo chuyến/chi tiêu hoặc quyền lợi theo kỳ, biểu đồ ngày/tháng, tổng hợp dịch vụ và sao chép CSV. API tổng hợp theo ngày kết thúc tại Asia/Ho_Chi_Minh, đúng chủ sở hữu và không bị giới hạn bởi trang lịch sử. Báo cáo quyền lợi không thay số dư/sổ cái; số đã thu là snapshot hiện tại của các chuyến kết thúc trong kỳ. Chưa có xuất file `.xlsx`/PDF, chia sẻ file native, job báo cáo định kỳ hoặc reporting warehouse. Xem mục 9 của [rà soát](REVIEW_AND_COMPLETION.md) và [kiểm chứng](VALIDATION.md).


## Đặt xe khách thuận tiện hơn — 04/11/2026

App khách có tìm điểm đón/đến với debounce, không dấu, saved/recent; GPS xác nhận ghim, đảo tuyến, so sánh 3 loại xe song song và dùng quote đúng loại/cùng tuyến. API đếm xe đủ điều kiện gần điểm đón không trả danh tính/tọa độ; query lọc SQL dùng chung với dispatch, nhưng tính bán kính vẫn ở RAM, chưa có PostGIS. Autocomplete đã có HTTP adapter contract; nhà cung cấp thật và reverse geocoding còn phải cấu hình/tích hợp. Không cam kết số xe/ETA chỉ từ snapshot; xem mục 10 trong [rà soát](REVIEW_AND_COMPLETION.md).
