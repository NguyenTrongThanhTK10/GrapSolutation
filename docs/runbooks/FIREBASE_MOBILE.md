# Firebase cho Android và iOS

Hai app dùng Firebase project `grap-f7675`. Flutter khởi tạo bằng cấu hình native đã được đóng gói trong từng app; không cần tạo thêm `firebase_options.dart` hoặc gọi `FirebaseApp.configure()` trong Swift.

| App | Android application ID | iOS bundle ID | File nguồn iOS |
| --- | --- | --- | --- |
| Khách hàng | `vn.grapsolution.grap_customer` | `vn.grapsolution.grapCustomer` | `docs/GoogleService-Info-2.plist` |
| Tài xế | `vn.grapsolution.grap_driver` | `vn.grapsolution.grapDriver` | `docs/GoogleService-Info-3.plist` |

## Cấu hình trong source

- Android: mỗi app có `android/app/google-services.json` khớp application ID, plugin Google Services, quyền `POST_NOTIFICATIONS`, channel `grap_updates` và icon `ic_stat_grap`. File nguồn tương ứng là `docs/google-services-4.json` và `docs/google-services-5.json`.
- iOS: file nguồn được sao chép thành `ios/Runner/GoogleService-Info.plist` và được khai báo trong Resources của target Runner. Bundle ID phải giữ đúng cả chữ hoa/chữ thường như bảng trên.
- Cả ba cấu hình iOS Debug/Profile/Release dùng `Runner/Runner.entitlements` với `aps-environment`. Xcode đã khai báo Push Notifications và Background Modes; Info.plist bật `fetch` và `remote-notification`. Entitlement nguồn dùng `development`; khi ký/export bản phân phối, kiểm tra entitlement thực tế là `production` và khớp provisioning profile.
- Firebase Messaging auto-init mặc định tắt. Sau khi đăng nhập và được cấp quyền thông báo, app bật auto-init và đăng ký FCM token với API, kèm `platform` là `android` hoặc `ios`. iOS chờ APNs cấp token tối đa khoảng 5 giây trước khi lấy FCM token; nếu chưa sẵn sàng, người dùng có thể đồng bộ lại hoặc quay lại app để thử lại.
- Foreground hiển thị thông báo trong app. Background/terminated dùng notification của hệ điều hành; khi chạm thông báo, app kiểm tra tài khoản và quyền qua API trước khi điều hướng.
- `--dart-define=ENABLE_FIREBASE_PUSH=false` tắt tích hợp push lúc chạy. Desktop/web vẫn dùng gateway tắt.

## Cần cấu hình trên Apple/Firebase

1. Mở `ios/Runner.xcworkspace` của từng app trong Xcode. Trong target Runner → Signing & Capabilities, chọn Apple Developer Team và profile có Push Notifications cho đúng bundle ID.
2. Trong Firebase Console → Project settings → Cloud Messaging, tải lên APNs authentication key `.p8`, Key ID và Team ID cho cấu hình iOS của cả hai app. Dùng key hỗ trợ đúng môi trường development/production cần chạy.
3. Giữ method swizzling của Firebase được bật; không đặt `FirebaseAppDelegateProxyEnabled=false`.
4. Cài và thử trên iPhone thật để nghiệm thu APNs. Build Simulator chỉ xác nhận cấu hình và khả năng biên dịch.

Tham khảo [hướng dẫn FCM Flutter chính thức](https://firebase.google.com/docs/cloud-messaging/flutter/get-started) và [cấu hình Firebase cho Apple](https://firebase.google.com/docs/ios/setup).

## Bật gửi từ backend

Backend đã có Firebase Admin sender và chấp nhận cả thiết bị Android/iOS. Cấu hình mặc định `Firebase:Enabled=false`; file plist/Google Services của mobile không phải thông tin xác thực máy chủ.

Cấp Application Default Credentials có quyền gửi FCM cho project `grap-f7675`. Với môi trường local, trỏ biến `GOOGLE_APPLICATION_CREDENTIALS` tới file service account nằm ngoài repo, rồi chạy API:

```sh
export GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/firebase-service-account.json
export Firebase__Enabled=true
export Firebase__ProjectId=grap-f7675
cd backend
dotnet run --project src/GrapSolution.Api -- --environment Development --urls http://127.0.0.1:5080
```

Không đưa service account hoặc APNs private key vào app hay source control. Nếu backend chưa có credentials, vẫn có thể đăng ký thiết bị; giao diện sẽ báo máy chủ chưa bật gửi Firebase.

## Chạy và nghiệm thu

Trong từng thư mục `mobile/apps/customer_app` và `mobile/apps/driver_app`:

```sh
flutter pub get
flutter test test/core/firebase_push_gateway_test.dart
flutter build apk --debug
flutter build ios --simulator --debug
```

Trên thiết bị có mạng và API truy cập được:

1. Đăng nhập → Tài khoản → Thông báo → Bật thông báo, chấp nhận quyền. Xác nhận trạng thái đã đăng ký.
2. Khi backend đã bật gửi, nhấn Gửi thông báo thử. Kiểm tra ở foreground, background và khi app đã đóng; chạm thông báo để mở đúng nội dung.
3. Tắt quyền trong hệ điều hành, quay lại app và đồng bộ. Nút Mở cài đặt thiết bị phải mở được cài đặt thông báo trên Android/iOS.
4. Kiểm tra tắt thông báo, đăng xuất/đổi tài khoản và token refresh; thông báo của tài khoản cũ không được dùng để mở nội dung của tài khoản mới.

Thông báo từ Firebase Console chỉ có title/body sẽ kiểm tra được banner hệ điều hành khi app ở background. Để kiểm tra điều hướng và cập nhật trong app, dùng nút gửi thử của backend vì payload cần `notificationId`, `userId`, `kind` và `entityId`.
