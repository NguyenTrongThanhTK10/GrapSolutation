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

## Lịch sử và đánh giá

`GET /rides?status=COMPLETED&from=<UTC>&to=<UTC>&pageSize=20&cursor=<encoded>` trả `items`, `nextCursor`, `hasMore`, `serverTime`. `from` bao gồm, `to` loại trừ; ngày bắt đầu phải nhỏ hơn ngày kết thúc. Không truyền status để lấy tất cả; `ACTIVE` gộp trạng thái đang diễn ra. pageSize giới hạn 1–100. Cursor có chữ ký và gắn actor/role/bộ lọc; URL-encode giá trị nguyên vẹn, không dùng lại sau khi đổi filter. Cursor giả hoặc sai scope trả `INVALID_CURSOR` 400. Sắp giảm dần CreatedAt rồi ID, không dùng offset.

- `GET /rides/{id}`, `/events`, `/receipt`: snapshot/timeline có kiểm tra quyền.
- `GET /rides/{id}/ratings/me`: đánh giá hiện tại, `canEdit`, `editableUntil`.
- `POST /rides/{id}/ratings`: `{stars:1..5,comment:<tối đa 1000 ký tự>}`. Tạo/cập nhật một record của tác giả; cửa sổ hiện tại 24 giờ tính từ EndedAt của chuyến COMPLETED.

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
