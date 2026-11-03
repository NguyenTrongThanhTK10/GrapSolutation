import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_driver/core/widgets/app_widgets.dart';
import 'package:image_picker/image_picker.dart';

import 'onboarding_controller.dart';

const documentNames = {
  'IDENTITY': 'Giấy tờ định danh',
  'DRIVING_LICENSE': 'Giấy phép lái xe',
  'VEHICLE_REGISTRATION': 'Đăng ký phương tiện',
  'INSURANCE': 'Bảo hiểm',
};

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final vehicle = TextEditingController(),
      plate = TextEditingController(),
      color = TextEditingController();
  String service = 'BIKE';
  bool initialized = false, picking = false;
  @override
  void dispose() {
    vehicle.dispose();
    plate.dispose();
    color.dispose();
    super.dispose();
  }

  Future<void> pick(String type) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Chụp ảnh giấy tờ'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Chọn từ thư viện'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    setState(() => picking = true);
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        maxWidth: 2000,
        maxHeight: 2000,
        imageQuality: 85,
        requestFullMetadata: false,
      );
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      final mime = bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80
          ? 'image/png'
          : bytes.length > 3 && bytes[0] == 255 && bytes[1] == 216
          ? 'image/jpeg'
          : null;
      if (mime == null) {
        throw Exception('Chỉ hỗ trợ ảnh JPEG/PNG. Vui lòng chọn ảnh khác.');
      }
      final now = DateUtils.dateOnly(DateTime.now());
      final expiry = await showDatePicker(
        context: context,
        helpText: 'Ngày hết hạn ${documentNames[type]}',
        initialDate: now.add(const Duration(days: 365)),
        firstDate: now.add(const Duration(days: 1)),
        lastDate: DateTime(now.year + 30),
      );
      if (expiry == null || !mounted) return;
      await ref
          .read(onboardingControllerProvider.notifier)
          .upload(
            type,
            bytes,
            mime,
            expiry.add(const Duration(days: 1)).toUtc(),
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => picking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = ref.watch(onboardingControllerProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hồ sơ đối tác'),
        actions: [
          IconButton(
            tooltip: 'Tải trạng thái duyệt mới nhất',
            onPressed: () => ref.invalidate(onboardingControllerProvider),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: snapshot.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              GrapNotice(e.toString(), error: true),
              TextButton(
                onPressed: () => ref.invalidate(onboardingControllerProvider),
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
        data: (s) {
          if (!initialized) {
            service = s.application.service;
            vehicle.text = s.application.vehicle;
            plate.text = s.application.plate;
            color.text = s.application.color;
            initialized = true;
          }
          final editable = s.application.editable && !s.busy && !picking;
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(onboardingControllerProvider);
              await ref.read(onboardingControllerProvider.future);
            },
            child: ListView(
              padding: const EdgeInsets.all(22),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  s.application.status == 'APPROVED'
                      ? 'Hồ sơ đã được duyệt'
                      : s.application.status == 'PENDING_REVIEW'
                      ? 'Hồ sơ đang chờ duyệt'
                      : 'Hoàn thiện hồ sơ của bạn',
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    color: grapInk,
                  ),
                ),
                const SizedBox(height: 12),
                if (s.application.reason != null)
                  GrapNotice(
                    'Nhận xét xét duyệt: ${s.application.reason}',
                    error: s.application.status == 'REJECTED',
                  ),
                if (s.error != null) GrapNotice(s.error!, error: true),
                if (s.message != null) GrapNotice(s.message!),
                if (s.application.status == 'PENDING_REVIEW')
                  const GrapNotice(
                    'Hồ sơ đang được kiểm tra. Trong thời gian này, phương tiện và giấy tờ được giữ nguyên để đối chiếu.',
                  ),
                const SizedBox(height: 20),
                GrapCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Thông tin phương tiện',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      DropdownButtonFormField<String>(
                        initialValue: service,
                        decoration: const InputDecoration(labelText: 'Dịch vụ'),
                        items: ['BIKE', 'CAR_4', 'CAR_7']
                            .map(
                              (code) => DropdownMenuItem(
                                value: code,
                                child: Text(serviceLabel(code)),
                              ),
                            )
                            .toList(),
                        onChanged: editable
                            ? (v) => setState(() => service = v!)
                            : null,
                      ),
                      const SizedBox(height: 15),
                      TextField(
                        controller: vehicle,
                        enabled: editable,
                        maxLength: 100,
                        decoration: const InputDecoration(
                          labelText: 'Hãng / dòng xe',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: plate,
                        enabled: editable,
                        maxLength: 20,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(
                          labelText: 'Biển kiểm soát',
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: color,
                        enabled: editable,
                        maxLength: 30,
                        decoration: const InputDecoration(labelText: 'Màu xe'),
                      ),
                      const SizedBox(height: 15),
                      if (s.application.editable)
                        FilledButton(
                          onPressed: editable
                              ? () => ref
                                    .read(onboardingControllerProvider.notifier)
                                    .save(
                                      service,
                                      vehicle.text,
                                      plate.text,
                                      color.text,
                                    )
                              : null,
                          child: Text(
                            s.busy ? 'Đang lưu…' : 'Lưu thông tin xe',
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                GrapCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Giấy tờ xác minh',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const GrapNotice(
                        'Ảnh JPEG/PNG tối đa 5 MB, chỉ được truy cập bởi bạn và nhân sự xét duyệt có quyền. Nộp lại tạo phiên bản mới; không ghi đè giấy tờ cũ.',
                      ),
                      for (final type in s.documents.requiredTypes)
                        Builder(
                          builder: (context) {
                            final doc = s.documents.latest(type);
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    documentNames[type] ?? type,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    doc == null
                                        ? 'Chưa nộp'
                                        : ('${doc.status == 'APPROVED'
                                              ? 'Đã duyệt'
                                              : doc.status == 'REJECTED'
                                              ? 'Cần bổ sung'
                                              : 'Chờ kiểm tra'} · v${doc.version} · Hạn ${doc.expiresAt.toLocal().toString().substring(0, 10)}'),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: grapMuted,
                                    ),
                                  ),
                                  if (doc?.reason != null)
                                    GrapNotice(
                                      doc!.reason!,
                                      error: doc.status == 'REJECTED',
                                    ),
                                  if (s.application.editable)
                                    Align(
                                      alignment: Alignment.centerLeft,
                                      child: TextButton.icon(
                                        onPressed: editable && s.uploadEnabled
                                            ? () => pick(type)
                                            : null,
                                        icon: const Icon(
                                          Icons.upload_file_outlined,
                                          size: 18,
                                        ),
                                        label: Text(
                                          doc == null
                                              ? 'Nộp giấy tờ'
                                              : 'Nộp phiên bản mới',
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                      if (!s.uploadEnabled)
                        const GrapNotice(
                          'Môi trường này chưa bật storage private. Bạn vẫn có thể lưu nháp thông tin xe.',
                        ),
                      const Divider(),
                      if (s.application.editable)
                        FilledButton(
                          onPressed: editable && s.documents.ready
                              ? () => ref
                                    .read(onboardingControllerProvider.notifier)
                                    .submit()
                              : null,
                          child: const Text('Gửi hồ sơ xét duyệt'),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const GrapNotice(
                  'Chỉ được online sau khi hồ sơ và giấy tờ còn hạn đã được xét duyệt. Danh mục hiện là cấu hình mẫu của vùng pilot.',
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
