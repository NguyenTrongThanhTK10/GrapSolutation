# Grap app icons v1

- Customer: ghim định vị và mũi tên hướng đi, nền `#087F50`.
- Driver: vô lăng và cùng mũi tên hướng đi, nền `#172C24`.
- Hình chính màu trắng, không có chữ để dễ đọc khi thu nhỏ.

Xem `preview.png`. File `*-app-icon.png` là master 1024 px, `*-play-store.png` là bản 512 px, `*-foreground.png` là lớp trắng trong suốt dành cho adaptive/themed icon.

Hai hình gốc được tạo bằng công cụ **image_gen tích hợp**; prompt đầy đủ và đường dẫn tham khảo nằm trong `manifest.json`. Script xuất chuẩn hóa về đúng màu thương hiệu, lớp alpha và vùng an toàn. Không cần dịch vụ tạo ảnh để xuất lại:

```sh
swift -module-cache-path /private/tmp/grap-icon-module-cache mobile/tool/export_app_icons.swift
```

Android dùng `ic_launcher_grap`: năm mật độ legacy, hai lớp adaptive từ API 26 và lớp monochrome từ API 33. iOS dùng catalog `GrapIcon.appiconset`, đủ kích thước trong catalog của dự án; PNG không alpha, nền vuông nguyên để hệ điều hành áp dụng mask. Các asset Flutter mặc định vẫn được giữ ở tên cũ.

Sau khi build và cài lại, launcher sẽ dùng icon mới. Hot reload không cập nhật icon native.

Tham khảo: [Android adaptive icons](https://developer.android.com/develop/ui/compose/system/icon_design_adaptive), [Apple app icons](https://developer.apple.com/design/human-interface-guidelines/app-icons).
