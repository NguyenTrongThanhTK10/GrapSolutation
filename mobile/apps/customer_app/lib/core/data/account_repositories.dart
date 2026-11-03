import '../domain/models.dart';
import '../domain/repositories.dart';
import '../network/api_client.dart';
import 'mappers.dart';

Profile profileFromJson(Json j) => Profile(
  user: userFromJson(j),
  phone: j['phone'] as String? ?? '',
  email: j['email'] as String?,
  version: j['version'] as int,
);
SupportTicket ticketFromJson(Json j) => SupportTicket(
  id: j['id'] as String,
  subject: j['subject'] as String,
  status: j['status'] as String,
  category: j['category'] as String,
  priority: j['priority'] as String,
  createdAt: DateTime.parse(j['createdAt'] as String),
);
DriverApplication applicationFromJson(Json j) => DriverApplication(
  id: j['id'] as String,
  status: j['reviewStatus'] as String,
  service: j['serviceTypeCode'] as String,
  plate: j['plate'] as String,
  vehicle: j['vehicle'] as String,
  color: j['color'] as String,
  version: j['version'] as int,
  reason: j['reviewReason'] as String?,
);

class ApiAccountRepository implements AccountRepository {
  final ApiClient client;
  ApiAccountRepository(this.client);
  @override
  Future<Profile> profile() async =>
      profileFromJson(await client.request('/me') as Json);
  @override
  Future<Profile> updateProfile(
    Profile current,
    String name,
    String? email,
  ) async {
    if (name.trim().isEmpty || name.trim().length > 100) {
      throw const Failure(
        'VALIDATION_ERROR',
        'Họ tên phải có từ 1 đến 100 ký tự.',
      );
    }
    if (email != null &&
        email.isNotEmpty &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      throw const Failure('VALIDATION_ERROR', 'Địa chỉ email chưa hợp lệ.');
    }
    await client.request(
      '/me/profile',
      method: 'PATCH',
      body: {
        'expectedVersion': current.version,
        'name': name.trim(),
        'email': email == null || email.trim().isEmpty ? null : email.trim(),
      },
    );
    final result = await client.request('/me') as Json;
    await client.cacheProfile(result);
    return profileFromJson(result);
  }

  @override
  Future<List<SupportTicket>> tickets() async =>
      ((await client.request('/support/tickets') as Json)['items'] as List)
          .map((j) => ticketFromJson(j as Json))
          .toList();
  @override
  Future<TicketDetail> ticket(String id) async {
    final j = await client.request('/support/tickets/$id') as Json;
    return TicketDetail(
      ticketFromJson(j['ticket'] as Json),
      (j['messages'] as List)
          .map(
            (m) => SupportMessage(
              id: m['id'] as String,
              authorId: m['authorId'] as String,
              body: m['body'] as String,
              createdAt: DateTime.parse(m['createdAt'] as String),
            ),
          )
          .toList(),
    );
  }

  @override
  Future<void> createTicket(
    String subject,
    String category,
    String message, {
    String? rideId,
  }) async {
    if (subject.trim().length < 5 || message.trim().length < 5) {
      throw const Failure(
        'VALIDATION_ERROR',
        'Tiêu đề và nội dung cần ít nhất 5 ký tự.',
      );
    }
    await client.request(
      '/support/tickets',
      method: 'POST',
      body: {
        'subject': subject.trim(),
        'category': category,
        'message': message.trim(),
        'rideId': rideId,
      },
    );
  }

  @override
  Future<void> reply(String ticketId, String message) async {
    if (message.trim().isEmpty) {
      throw const Failure(
        'VALIDATION_ERROR',
        'Vui lòng nhập nội dung phản hồi.',
      );
    }
    await client.request(
      '/support/tickets/$ticketId/messages',
      method: 'POST',
      body: {'body': message.trim()},
    );
  }

  @override
  Future<List<AppNotification>> notifications() async =>
      ((await client.request('/notifications') as Json)['items'] as List)
          .map(
            (n) => AppNotification(
              id: n['id'] as String,
              title: n['title'] as String,
              body: n['body'] as String,
              entityId: n['entityId'] as String?,
              createdAt: DateTime.parse(n['createdAt'] as String),
              read: n['readAt'] != null,
            ),
          )
          .toList();
  @override
  Future<void> markRead(String id) async {
    await client.request('/notifications/$id/read', method: 'POST');
  }

  @override
  Future<RideShare> createShare(RideSnapshot ride) async {
    final j = await client.request(
      '/rides/${ride.id}/share-tokens',
      method: 'POST',
    ) as Json;
    const portal = String.fromEnvironment(
      'PORTAL_BASE_URL',
      defaultValue: 'http://127.0.0.1:5173',
    );
    return RideShare(
      j['id'] as String,
      '$portal/share/${j['token']}',
      DateTime.parse(j['expiresAt'] as String),
    );
  }

  @override
  Future<void> revokeShare(RideSnapshot ride, String shareId) async {
    await client.request(
      '/rides/${ride.id}/share-tokens/$shareId',
      method: 'DELETE',
    );
  }
}

class ApiOnboardingRepository implements OnboardingRepository {
  final ApiClient client;
  ApiOnboardingRepository(this.client);
  @override
  Future<DriverApplication> application() async => applicationFromJson(
    await client.request('/drivers/me/application') as Json,
  );
  @override
  Future<DriverApplication> save(
    DriverApplication current,
    String service,
    String vehicle,
    String plate,
    String color,
  ) async {
    if (!current.editable) {
      throw const Failure(
        'APPLICATION_LOCKED',
        'Chỉ sửa hồ sơ nháp hoặc hồ sơ cần bổ sung.',
      );
    }
    if (vehicle.trim().isEmpty ||
        plate.trim().isEmpty ||
        color.trim().isEmpty) {
      throw const Failure(
        'VALIDATION_ERROR',
        'Cần nhập đầy đủ thông tin phương tiện.',
      );
    }
    return applicationFromJson(
      await client.request(
        '/drivers/me/application',
        method: 'PUT',
        body: {
          'expectedVersion': current.version,
          'serviceTypeCode': service,
          'vehicle': vehicle.trim(),
          'plate': plate.trim().toUpperCase(),
          'color': color.trim(),
        },
      ) as Json,
    );
  }

  @override
  Future<DocumentBundle> documents() async {
    final j = await client.request('/drivers/me/documents') as Json;
    return DocumentBundle(
      (j['requiredTypes'] as List).cast<String>(),
      (j['items'] as List)
          .map(
            (d) => DriverDocument(
              id: d['id'] as String,
              type: d['type'] as String,
              status: d['status'] as String,
              version: d['version'] as int,
              expiresAt: DateTime.parse(d['expiresAt'] as String),
              reason: d['reviewReason'] as String?,
            ),
          )
          .toList(),
    );
  }

  @override
  Future<void> uploadDocument(
    String type,
    List<int> bytes,
    String contentType,
    DateTime expiresAt,
  ) async {
    if (bytes.isEmpty || bytes.length > 5242880) {
      throw const Failure(
        'INVALID_FILE',
        'Chỉ nhận ảnh JPEG/PNG không quá 5 MB.',
      );
    }
    if (!expiresAt.isAfter(DateTime.now().toUtc())) {
      throw const Failure('INVALID_DOCUMENT', 'Ngày hết hạn phải ở tương lai.');
    }
    final intent = await client.request(
      '/files/upload-intents',
      method: 'POST',
      body: {
        'contentType': contentType,
        'size': bytes.length,
        'purpose': 'DRIVER_DOCUMENT',
      },
    ) as Json;
    final id = intent['fileId'] as String;
    await client.request(
      '/files/$id/content',
      method: 'PUT',
      bytes: bytes,
      contentType: contentType,
    );
    await client.request('/files/$id/complete', method: 'POST');
    await client.request(
      '/drivers/me/documents',
      method: 'POST',
      body: {
        'type': type,
        'fileId': id,
        'expiresAt': expiresAt.toUtc().toIso8601String(),
      },
    );
  }

  @override
  Future<void> submit(int expectedVersion) async {
    await client.request(
      '/drivers/me/application/submit',
      method: 'POST',
      body: {'expectedVersion': expectedVersion},
    );
  }

  @override
  Future<bool> uploadEnabled() async =>
      ((await client.request('/app-config') as Json)['featureFlags']
          as Json)['privateDocumentUpload'] ==
      true;
}

class ApiRecoveryRepository implements RecoveryRepository {
  final ApiClient client;
  ApiRecoveryRepository(this.client);
  @override
  Future<List<PendingOperation>> pending() => client.pending();
  @override
  Future<void> retry(String id) => client.retry(id);
}
