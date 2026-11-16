# REST và realtime

Base path `/api/v1`, JSON camelCase, tiền VND nguyên, timestamp UTC. OpenAPI thực tế được generate tại `/openapi/v1.json` trong Development; `openapi.json` trong thư mục này là snapshot từ build đã kiểm tra.

## Auth

- `GET /auth/development/accounts`, `POST /auth/development`: chỉ Development.
- `POST /auth/otp/challenges`, `/auth/otp/verify`: đã có hợp đồng; SMS chưa cấu hình trả 503.
- `POST /auth/token/refresh`: rotate token, reuse thu hồi family.
- `POST /auth/logout`, `GET /me`, `PATCH /me/profile`.

`Authorization: Bearer <accessToken>` cho tài nguyên có quyền. Tạo/chuyển trạng thái chuyến, accept, cash và command tài chính cần `Idempotency-Key` 8–150 ký tự. Giữ nguyên payload/key khi retry sau mất mạng.

## Luồng tiền mặt

```text
POST /quotes
POST /rides                                      Idempotency-Key
GET  /drivers/me/offers/current
POST /driver-offers/{id}/accept                   Idempotency-Key + expectedVersion
POST /rides/{id}/arrive                           Idempotency-Key + expectedVersion + location
POST /rides/{id}/start                            Idempotency-Key + expectedVersion + pickupPin
POST /rides/{id}/complete                         Idempotency-Key + expectedVersion + location
POST /payments/{id}/cash-collections              Idempotency-Key + operationId + collectedAmount
```

Start chỉ hợp lệ ở DRIVER_ARRIVED. Complete chỉ hợp lệ ở IN_PROGRESS; Payment có thể tiếp tục pending sau khi Ride COMPLETED. Cash collection không được vượt remaining. Replay complete với version cũ nhưng cùng key trả snapshot đã commit.

## Hồ sơ/file local

```text
PUT  /drivers/me/application
POST /files/upload-intents                        contentType, size, purpose=DRIVER_DOCUMENT
PUT  /files/{id}/content                          raw bytes, bearer, đúng Content-Type/Length
POST /files/{id}/complete
POST /drivers/me/documents                        type, fileId, expiresAt
POST /drivers/me/application/submit               expectedVersion
GET  /admin/drivers/{id}/documents                DriverReviewer
GET  /files/{id}/content                          owner / scoped reviewer, attachment
POST /admin/driver-documents/{id}/review-decisions
POST /admin/drivers/{id}/review-decisions
```

Các loại giấy tờ mẫu: IDENTITY, DRIVING_LICENSE, VEHICLE_REGISTRATION, INSURANCE. Đây là cấu hình mẫu kỹ thuật, không phải kết luận pháp lý về danh mục cần thiết ở thị trường cụ thể.

## Location

`POST /drivers/me/location-batches` nhận `samples` tối đa 100. Mỗi sample có latitude, longitude, accuracyMeters, recordedAt, sequence và sampleId tùy chọn. Nếu không truyền sampleId, server dùng sequence làm khóa dedupe trong session. Sample cũ hợp lệ được lưu vào lịch sử nhưng không kéo latest về quá khứ. Phiên thiết bị khác không được gửi.

## Errors

Problem Details mở rộng `code`, `traceId`, `currentVersion`. Các mã chính: QUOTE_EXPIRED, ACTIVE_RIDE_EXISTS, VERSION_CONFLICT, IDEMPOTENCY_CONFLICT, OFFER_EXPIRED, PIN_INVALID, PIN_LOCKED, LOCATION_NOT_TRUSTED, INVALID_AMOUNT, FORBIDDEN, RESOURCE_NOT_FOUND.

Không map lỗi nghiệp vụ thành HTTP 200. Lỗi provider 503 không thay thế bằng dữ liệu tự tính. Khi 409 version conflict, tải snapshot rồi yêu cầu người dùng xác nhận lại ý định.

## SignalR

Hub `/hubs/rides`. Server gán group theo session đã xác thực; không có API join group tùy ý. Event envelope có eventId, eventType, schemaVersion, aggregateId, aggregateVersion, occurredAt, data. Ride state và GPS có sequence riêng; client dùng snapshot làm nguồn quyết định. Socket mất kết nối có polling foreground dự phòng.

Customer gọi `SubscribeNearby(latitude, longitude)` để nhận thông báo cho vùng chứa điểm đón. Server kiểm tra vai trò, session và tọa độ, thay subscription cũ trên cùng connection; ngoài vùng phục vụ sẽ bỏ subscription. Khi reconnect, client phải gọi lại. Event riêng `nearby.drivers.changed` chỉ mang `{serverTime}`, không mang tọa độ hoặc dữ liệu cá nhân; client tải snapshot qua REST có xác thực. Outbox phát thông báo sau khi thay đổi GPS, online/offline, lời mời hoặc trạng thái chuyến; polling còn xử lý GPS/heartbeat hết hạn và thay đổi phiên.

## Lịch sử và đánh giá

`GET /rides?status=COMPLETED&from=<UTC>&to=<UTC>&pageSize=20&cursor=<encoded>` trả `items`, `nextCursor`, `hasMore`, `serverTime`. `from` bao gồm, `to` loại trừ; ngày bắt đầu phải nhỏ hơn ngày kết thúc. Không truyền status để lấy tất cả; `ACTIVE` gộp trạng thái đang diễn ra. pageSize giới hạn 1–100. Cursor có chữ ký và gắn actor/role/bộ lọc; URL-encode giá trị nguyên vẹn, không dùng lại sau khi đổi filter. Cursor giả hoặc sai scope trả `INVALID_CURSOR` 400. Sắp giảm dần CreatedAt rồi ID, không dùng offset.

- `GET /rides/{id}`, `/events`, `/receipt`: snapshot/timeline có kiểm tra quyền.
- `GET /rides/{id}/ratings/me`: đánh giá hiện tại, `canEdit`, `editableUntil`.
- `POST /rides/{id}/ratings`: `{stars:1..5,comment:<tối đa 1000 ký tự>}`. Tạo/cập nhật một record của tác giả; cửa sổ hiện tại 24 giờ tính từ EndedAt của chuyến COMPLETED.

## Chat theo chuyến xe

- `GET /rides/{id}/messages`: chỉ khách của chuyến và tài xế của lần phân công hiện hành/cuối cùng. Trả `assignmentId`, `rideCode`, `peerName`, `canSend`, `items`, `hasMore`, `nextBeforeSequence`. Mỗi tin gồm `id`, `assignmentId`, `senderId`, `body`, `sequence`, `createdAt`.
- Không truyền mốc: lấy 50 tin mới nhất, sắp theo `sequence` tăng dần. `beforeSequence=N` lấy tối đa 50 tin trước N; `nextBeforeSequence` dùng để tải trang cũ hơn. `afterSequence=N` lấy tối đa 50 tin sau N, tăng dần; tiếp tục lấy từ sequence cuối cho tới khi `hasMore=false` để khôi phục tin bị lỡ. Hai mốc không được dùng cùng lúc; before phải > 0, after >= 0.
- `POST /rides/{id}/messages`: bắt buộc `Idempotency-Key` 8–150 ký tự và JSON `{assignmentId,body}`. Body được trim, dài 1–1.000 ký tự UTF-16, không nhận ký tự điều khiển ngoài xuống dòng/tab. `senderId` lấy từ phiên xác thực. Trả 201 và tin nhắn đã lưu.
- Chỉ gửi trong ASSIGNED, DRIVER_ARRIVED, IN_PROGRESS và Assignment chưa đóng. Chuyến kết thúc chỉ cho đọc. Không có Assignment phù hợp trả `CHAT_UNAVAILABLE` 409; Assignment body cũ trả `CHAT_ASSIGNMENT_CHANGED` 409; chuyến đóng trả `CHAT_CLOSED` 409; người ngoài trả 404, nhân sự trả 403. Đổi tài xế thu hồi quyền tài xế cũ và tạo luồng tin riêng, kể cả khi thử replay khóa cũ. Quyền replay được kiểm tra trong cùng transaction/command lock.
- Giới hạn gửi 30 request/phút/tài khoản, trả 429 khi vượt. Client dùng khóa mới cho mỗi tin chủ động; giữ nguyên key/body/assignment khi gửi lại một yêu cầu chưa rõ kết quả. Replay sau khi kết thúc vẫn trả kết quả đã commit nếu quyền Assignment còn hợp lệ.
- SignalR phát `ride.message.created` tới session khách và tài xế hiện hành, không phát tới nhân sự. Payload chỉ có `aggregateId` và `data{assignmentId,messageId,sequence}`; client đọc nội dung qua REST có kiểm tra quyền. Outbox bỏ qua sự kiện của Assignment đã đóng/đổi tài xế. Nội dung được mã hóa khi lưu; không đưa body vào event hoặc thông báo push.

Bản mobile hiện giữ bản nháp và khóa gửi lại trong vòng đời màn chat; không có hàng đợi gửi tin ngoại tuyến qua lần khởi động lại. Retention/xóa tự động cho hội thoại chưa được áp dụng; dữ liệu dùng cùng quy trình quyền riêng tư đang có của hệ thống.

## Địa chỉ và liên hệ tin cậy

| Route | Body / quyền |
| --- | --- |
| GET/POST `/customers/me/saved-places` | Customer; POST cần Idempotency-Key; label, point{latitude,longitude,address}, note |
| PATCH `/customers/me/saved-places/{id}` | Chính chủ; body trên + expectedVersion |
| DELETE `/customers/me/saved-places/{id}?expectedVersion=N` | Chính chủ; clears label/address/note/coordinates ở entity và đánh dấu deleted |
| GET/POST `/me/trusted-contacts` | Customer/Driver; POST cần Idempotency-Key; name, phone, consentAccepted=true |
| PATCH `/me/trusted-contacts/{id}` | Chính chủ; body trên + expectedVersion |
| DELETE `/me/trusted-contacts/{id}?expectedVersion=N` | Chính chủ; clears name/PhoneProtected và đánh dấu deleted |

Tối đa 20 địa chỉ, label không trùng theo account; tối đa 5 liên hệ. Số Việt Nam dạng 0… được chuyển +84…, E.164 được kiểm tra và mã hóa bằng Data Protection; chỉ API của chính chủ trả số đọc được. Response idempotency mới cũng được mã hóa với prefix `dp:` để tránh lưu rõ PIN/số/địa chỉ trong bảng replay. Record cũ đọc tương thích; chưa có job chuyển đổi/retention record cũ.

## Yêu cầu xóa tài khoản

- GET/POST `/me/account-deletion-requests`: C/D; POST cần Idempotency-Key, `{reason}`; tạo SupportTicket liên quan.
- POST `/me/account-deletion-requests/{id}/recheck` hoặc `/cancel`: chính chủ, Idempotency-Key + expectedVersion.
- GET `/admin/account-deletion-requests`: SecurityAdmin, scope vùng.
- POST `/admin/account-deletion-requests/{id}/review`: SecurityAdmin, Idempotency-Key + `{expectedVersion,decision,reason}`; decision là IN_REVIEW, NEEDS_INFORMATION hoặc REJECTED.

Mỗi user có tối đa một yêu cầu mở (REQUESTED, BLOCKED_OBLIGATIONS, IN_REVIEW, NEEDS_INFORMATION). Blockers: ACTIVE_RIDE, OUTSTANDING_PAYMENT, DRIVER_BALANCE_PENDING. IN_REVIEW yêu cầu không còn blocker; người dùng được rút thành WITHDRAWN. Không có quyết định COMPLETED/xóa dữ liệu tự động; response luôn `dataDeleted:false`. SecurityAdmin được đọc/phản hồi ticket thuộc ACCOUNT_DELETION cùng vùng, không được mở mọi ticket.


## Thống kê cá nhân theo kỳ

`GET /me/ride-statistics?from=2026-10-29&to=2026-11-04` dành cho Customer/Driver đã đăng nhập. Hai tham số là **ngày lịch `yyyy-MM-dd` tại Asia/Ho_Chi_Minh**, bao gồm cả ngày đầu và ngày cuối. Phải truyền cả hai hoặc bỏ cả hai (mặc định 7 ngày đến hôm nay). Tối đa 366 ngày, không vượt hôm nay; khoảng không hợp lệ trả 400.

Response có `from`, `to`, `timezone`, `currency`, `role`, `generatedAt`, `granularity`, `totals`, `buckets`, `services`. `totals` gồm `totalRides`, `completedRides`, `canceledRides`, `unfulfilledRides`, `grossFare`, `commission`, `entitlement`, `payable`, `paid`, `outstanding`. Mỗi bucket có `date` và `totals`; mỗi dịch vụ có `service` và `totals`.

- Chỉ tính trạng thái COMPLETED/CANCELED/NO_DRIVER/EXPIRED có EndedAt trong kỳ. Truy vấn UTC là `[đầu ngày from, đầu ngày sau to)`. Khác lịch sử, báo cáo lọc **ngày kết thúc**, không lọc CreatedAt. Chuyến active hoặc không có EndedAt chưa được tính.
- Tổng kết không phụ thuộc pageSize của lịch sử. Kỳ đến 31 ngày có bucket theo ngày; kỳ dài hơn có bucket theo tháng. Ngày/tháng không có chuyến vẫn trả giá trị 0; tháng đầu/cuối chỉ tổng hợp phần nằm trong kỳ.
- Khách chỉ có dữ liệu của chính mình. Tài xế chỉ có chuyến có DriverId cuối cùng của mình; assignment cũ không nhận quyền lợi của tài xế cuối cùng. Nhân sự không được dùng route này để đọc báo cáo người khác.
- Các số tiền chỉ cộng từ chuyến COMPLETED. `payable` là cước phải trả; `paid` là số tiền hiện đã ghi nhận của các chuyến đó; `outstanding` cộng phần còn lại không âm từng chuyến. Đây không phải báo cáo dòng tiền theo ngày thu tiền.
- `entitlement = grossFare - commission` dành cho tài xế, không phải số dư có thể rút. Customer nhận commission/entitlement bằng 0; ứng dụng khách không xuất các cột này.
- Không trả địa chỉ, số điện thoại, ID khách/tài xế/chuyến hoặc tọa độ trong báo cáo. Không thay đổi ledger, balance hoặc database schema.


## Tìm địa điểm và số xe gần điểm đón

- `GET /places/autocomplete?q=<URL-encoded>`: authenticated, query tối đa 150 ký tự. Trả `items[{placeId,latitude,longitude,address}]` (tối đa 20 từ HTTP provider) và `source=DEVELOPMENT_FIXTURE|CONFIGURED_PROVIDER`. Fixture hỗ trợ tìm không dấu/nhiều từ/alias sân bay TSN-SGN. Provider cấu hình có lỗi hoặc tọa độ không hợp lệ trả 503; không fallback fixture.
- HTTP map adapter mới nhận `GET {Maps__BaseUrl}/autocomplete?q=...`, trả `{items:[{placeId,latitude,longitude,address}]}`. ID không rỗng/tối đa 200, địa chỉ không rỗng/tối đa 500, tọa độ hữu hạn/đúng miền. Timeout theo HTTP client maps hiện có. `POST /route` giữ hợp đồng cũ.
- `GET /customers/me/nearby-services?latitude=10.7721&longitude=106.6983`: Customer-only; tọa độ phải hợp lệ. Trả `{inServiceZone,radiusMeters:3000,serverTime,items:[{code,availableCount}]}` với BIKE/CAR_4/CAR_7. Ngoài vùng đang active trả `inServiceZone:false` và 0 cho các loại xe.
- Bộ lọc xe dùng chung với dispatch; không tính xe có open offer còn hạn, assignment chưa đóng, session/user không hoạt động, hồ sơ/giấy tờ không hợp lệ, GPS/heartbeat quá 30 giây hoặc accuracy quá 100 m. Chỉ trả số lượng, không trả ID/biển số/số điện thoại/tọa độ tài xế.
- `GET /customers/me/nearby-drivers?latitude=10.7721&longitude=106.6983`: cùng quyền/bộ lọc và các trường của nearby-services, thêm `drivers:[{markerId,serviceTypeCode,latitude,longitude,locationAt}]`. Tối đa 100 marker gần nhất, tọa độ làm tròn 4 chữ số thập phân; `markerId` là HMAC riêng cho mỗi khách/ngày, không phải driver ID. Không trả danh tính/biển số/điện thoại. Endpoint nearby-services vẫn chỉ trả số lượng.
- Số lượng là snapshot theo vùng và bán kính địa lý, không giữ chỗ/không phải ETA. App tự cập nhật qua SignalR, REST dự phòng mỗi 5 giây và nút cập nhật thủ công; gộp sự kiện trong 300 ms, mỗi subscription chỉ có một REST request chạy. Snapshot hết hạn sau tối đa 15 giây, từng marker hết hạn khi GPS vượt 30 giây tính theo serverTime và trừ thời gian request. Lỗi tải có trạng thái riêng, không tự coi là 0 xe. Subscription dừng khi app chuyển nền/rời màn hình; đổi điểm đón/phiên sẽ bỏ response cũ.

## Bản đồ hành trình chuyến xe

- `GET /rides/{id}/route`: yêu cầu đăng nhập và cùng quyền xem chuyến như `/rides/{id}`. Trả `{rideId,distanceMeters,durationSeconds,routeSource,geometry,samples:[{latitude,longitude,recordedAt}],serverTime}`. Cự ly/thời gian là dự kiến từ báo giá, không phải số đo GPS thực tế.
- `geometry` là chuỗi JSON đã lưu từ nhà cung cấp bản đồ hoặc `null`. Adapter `/route` cần trả `geometry` dạng GeoJSON `{"type":"LineString","coordinates":[[longitude,latitude],...]}`. Ứng dụng bỏ qua geometry thiếu/sai định dạng và ghi rõ khi chỉ nối thẳng hai điểm. Demo provider hiện không có geometry chi tiết.
- `samples` chỉ lấy từ sự kiện `start` đến thời điểm kết thúc chuyến (hoặc hiện tại), đồng thời nằm trong thời gian assignment của tài xế thuộc chuyến. Không có `start` thì danh sách rỗng. Loại GPS có sai số ngoài `(0,100]` mét; sắp xếp theo thời gian ghi nhận rồi sequence. Không trả session ID hoặc thông tin tài xế trong mẫu GPS.
- App khách hiển thị tuyến dự kiến màu xanh lá và GPS đã ghi nhận màu xanh dương trên chuyến đang chạy và màn hình chi tiết lịch sử. Có xem toàn màn hình, thao tác phóng/thu và nút căn toàn bộ hành trình; lỗi tải tuyến có nút thử lại riêng.
