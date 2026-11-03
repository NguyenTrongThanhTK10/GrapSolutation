import 'package:grap_customer/features/notifications/presentation/push_settings_panel.dart';
import 'package:grap_customer/features/privacy/presentation/privacy_screens.dart';
import 'package:grap_customer/features/journey/presentation/journey_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';

class GrapAccountPanel extends ConsumerWidget {
  final Widget? extra;
  const GrapAccountPanel({super.key, this.extra});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    return GrapCard(
      child: profile.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (e, _) => Column(
          children: [
            GrapNotice(e.toString(), error: true),
            TextButton(
              onPressed: () => ref.invalidate(profileProvider),
              child: const Text('Tải lại hồ sơ'),
            ),
          ],
        ),
        data: (p) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xffedf6f0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 29,
                    backgroundColor: grapGreen,
                    child: Text(
                      p.user.name.trim().isEmpty
                          ? 'G'
                          : p.user.name
                                .trim()
                                .split(' ')
                                .last
                                .characters
                                .first
                                .toUpperCase(),
                      style: const TextStyle(
                        fontSize: 25,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.user.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: grapInk,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          p.phone,
                          style: const TextStyle(
                            fontSize: 14,
                            color: grapMuted,
                          ),
                        ),
                        if (p.email != null)
                          Text(
                            p.email!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              color: grapMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 3),
              leading: const Icon(Icons.edit_outlined, color: grapGreen),
              title: const Text(
                'Chỉnh sửa hồ sơ',
                style: TextStyle(fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ProfileEditor(profile: p),
                ),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 3),
              leading: const Icon(Icons.notifications_none, color: grapGreen),
              title: const Text('Thông báo', style: TextStyle(fontSize: 14)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsScreen(),
                ),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 3),
              leading: const Icon(Icons.headset_mic_outlined, color: grapGreen),
              title: const Text(
                'Yêu cầu hỗ trợ của tôi',
                style: TextStyle(fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const SupportInboxScreen(),
                ),
              ),
            ),
            if (p.user.role == 'Customer')
              ListTile(
                contentPadding: const EdgeInsets.symmetric(vertical: 3),
                leading: const Icon(Icons.bookmark_outline, color: grapGreen),
                title: const Text(
                  'Địa chỉ đã lưu',
                  style: TextStyle(fontSize: 14),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const SavedPlacesScreen(),
                  ),
                ),
              ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 3),
              leading: const GrapIconBadge(Icons.health_and_safety_outlined),
              title: const Text(
                'Liên hệ tin cậy',
                style: TextStyle(fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const SafetyContactsScreen(),
                ),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 3),
              leading: const Icon(Icons.manage_history, color: grapGreen),
              title: const Text(
                'Xem toàn bộ lịch sử',
                style: TextStyle(fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const JourneyHistoryScreen(),
                ),
              ),
            ),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 3),
              leading: const Icon(Icons.privacy_tip_outlined, color: grapGreen),
              title: const Text(
                'Yêu cầu xóa tài khoản',
                style: TextStyle(fontSize: 14),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const DeletionRequestScreen(),
                ),
              ),
            ),
            ?extra,
            const Divider(),
            TextButton.icon(
              onPressed: () async {
                try {
                  await ref.read(sessionProvider.notifier).logout();
                } catch (_) {
                  /* Session controller always clears this device's credentials. */
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất tài khoản'),
            ),
          ],
        ),
      ),
    );
  }
}

class ProfileEditor extends ConsumerStatefulWidget {
  final Profile profile;
  const ProfileEditor({super.key, required this.profile});
  @override
  ConsumerState<ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends ConsumerState<ProfileEditor> {
  late final name = TextEditingController(text: widget.profile.user.name),
      email = TextEditingController(text: widget.profile.email ?? '');
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  bool conflict = false;
  @override
  void dispose() {
    name.dispose();
    email.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    final repository = ref.read(accountRepositoryProvider);
    try {
      final updated = await repository.updateProfile(
        widget.profile,
        name.text,
        email.text,
      );
      if (!mounted) return;
      ref.read(sessionProvider.notifier).updateProfile(updated);
      ref.invalidate(profileProvider);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          error = e.toString();
          conflict = e is Failure && e.code == 'VERSION_CONFLICT';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hồ sơ cá nhân')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        GrapCard(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: name,
                  maxLength: 100,
                  enabled: !busy,
                  decoration: const InputDecoration(labelText: 'Họ và tên'),
                  validator: (s) => s == null || s.trim().isEmpty
                      ? 'Vui lòng nhập họ tên'
                      : null,
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: email,
                  maxLength: 200,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email (không bắt buộc)',
                  ),
                  validator: (s) =>
                      s != null &&
                          s.isNotEmpty &&
                          !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s)
                      ? 'Email chưa hợp lệ'
                      : null,
                ),
                const GrapNotice(
                  'Đổi số điện thoại cần quy trình xác minh riêng; không thể sửa tại đây.',
                ),
                if (error != null) GrapNotice(error!, error: true),
                if (conflict)
                  GrapConflictNotice(
                    onReload: () {
                      ref.invalidate(profileProvider);
                      Navigator.pop(context);
                    },
                  ),
                FilledButton(
                  onPressed: busy || conflict ? null : save,
                  child: Text(busy ? 'Đang lưu…' : 'Lưu thay đổi'),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class SupportInboxScreen extends ConsumerWidget {
  const SupportInboxScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(ticketsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Trung tâm hỗ trợ')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute<void>(builder: (_) => const CreateTicketScreen()),
        ),
        icon: const Icon(Icons.add_comment_outlined),
        label: const Text('Tạo yêu cầu'),
      ),
      body: tickets.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Retry(
          error: e.toString(),
          retry: () => ref.invalidate(ticketsProvider),
        ),
        data: (items) => RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(ticketsProvider);
            await ref.read(ticketsProvider.future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              if (items.isEmpty)
                const GrapNotice(
                  'Bạn chưa có yêu cầu hỗ trợ. Mỗi yêu cầu được lưu để theo dõi và phản hồi.',
                ),
              for (final ticket in items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GrapCard(
                    padding: const EdgeInsets.all(5),
                    child: ListTile(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => TicketScreen(ticketId: ticket.id),
                        ),
                      ),
                      leading: const Icon(
                        Icons.forum_outlined,
                        color: grapGreen,
                      ),
                      title: Text(
                        ticket.subject,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _ticketState(ticket.status),
                          style: const TextStyle(
                            fontSize: 14,
                            color: grapMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

String _ticketState(String code) =>
    const {
      'OPEN': 'Chờ tiếp nhận',
      'IN_PROGRESS': 'Đang xử lý',
      'ESCALATED': 'Chuyển cấp hỗ trợ',
      'RESOLVED': 'Đã giải quyết',
      'CLOSED': 'Đã đóng',
    }[code] ??
    code;

class CreateTicketScreen extends ConsumerStatefulWidget {
  final String? rideId;
  const CreateTicketScreen({super.key, this.rideId});
  @override
  ConsumerState<CreateTicketScreen> createState() => _CreateTicketState();
}

class _CreateTicketState extends ConsumerState<CreateTicketScreen> {
  final subject = TextEditingController(), message = TextEditingController();
  String category = 'RIDE';
  bool busy = false;
  String? error;
  @override
  void dispose() {
    subject.dispose();
    message.dispose();
    super.dispose();
  }

  Future<void> submit() async {
    setState(() {
      busy = true;
      error = null;
    });
    final repository = ref.read(accountRepositoryProvider);
    try {
      await repository.createTicket(
        subject.text,
        category,
        message.text,
        rideId: widget.rideId,
      );
      if (mounted) {
        ref.invalidate(ticketsProvider);
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Gửi yêu cầu hỗ trợ')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const GrapNotice(
          'Yêu cầu sẽ xuất hiện trong hộp thư hỗ trợ sau khi máy chủ xác nhận.',
        ),
        const SizedBox(height: 15),
        TextField(
          controller: subject,
          maxLength: 200,
          enabled: !busy,
          decoration: const InputDecoration(
            labelText: 'Tiêu đề (ít nhất 5 ký tự)',
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: category,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Loại vấn đề'),
          items: const [
            DropdownMenuItem(value: 'RIDE', child: Text('Hành trình')),
            DropdownMenuItem(
              value: 'PAYMENT',
              child: Text('Thanh toán tiền mặt'),
            ),
            DropdownMenuItem(value: 'LOST_ITEM', child: Text('Đồ thất lạc')),
            DropdownMenuItem(
              value: 'ACCOUNT',
              child: Text('Tài khoản / giấy tờ'),
            ),
            DropdownMenuItem(value: 'OTHER', child: Text('Khác')),
          ],
          onChanged: busy ? null : (v) => setState(() => category = v!),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: message,
          maxLength: 5000,
          maxLines: 6,
          enabled: !busy,
          decoration: const InputDecoration(labelText: 'Mô tả chi tiết'),
        ),
        if (error != null) GrapNotice(error!, error: true),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: busy ? null : submit,
          child: Text(busy ? 'Đang gửi…' : 'Gửi yêu cầu'),
        ),
      ],
    ),
  );
}

class TicketScreen extends ConsumerStatefulWidget {
  final String ticketId;
  const TicketScreen({super.key, required this.ticketId});
  @override
  ConsumerState<TicketScreen> createState() => _TicketState();
}

class _TicketState extends ConsumerState<TicketScreen> {
  final message = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    message.dispose();
    super.dispose();
  }

  Future<void> reply() async {
    if (message.text.trim().isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref
          .read(accountRepositoryProvider)
          .reply(widget.ticketId, message.text);
      if (mounted) {
        message.clear();
        ref.invalidate(ticketProvider(widget.ticketId));
      }
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(ticketProvider(widget.ticketId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nội dung hỗ trợ'),
        actions: [
          IconButton(
            tooltip: 'Làm mới',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(ticketProvider(widget.ticketId)),
          ),
        ],
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _Retry(
          error: e.toString(),
          retry: () => ref.invalidate(ticketProvider(widget.ticketId)),
        ),
        data: (d) => ListView(
          padding: const EdgeInsets.all(22),
          children: [
            Text(
              d.ticket.subject,
              style: const TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w700,
                color: grapInk,
              ),
            ),
            const SizedBox(height: 12),
            GrapNotice(_ticketState(d.ticket.status)),
            for (final m in d.messages)
              Container(
                padding: const EdgeInsets.all(16),
                margin: EdgeInsets.fromLTRB(
                  m.authorId == ref.read(sessionProvider).value?.id ? 25 : 0,
                  8,
                  m.authorId == ref.read(sessionProvider).value?.id ? 0 : 25,
                  8,
                ),
                decoration: BoxDecoration(
                  color: m.authorId == ref.read(sessionProvider).value?.id
                      ? const Color(0xffe9f5ed)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.body,
                      style: const TextStyle(fontSize: 14, height: 1.7),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      m.createdAt.toLocal().toString().substring(0, 16),
                      style: const TextStyle(fontSize: 14, color: grapMuted),
                    ),
                  ],
                ),
              ),
            if (error != null) GrapNotice(error!, error: true),
            if (d.ticket.status != 'CLOSED') ...[
              const SizedBox(height: 22),
              TextField(
                controller: message,
                maxLines: 4,
                maxLength: 5000,
                enabled: !busy,
                decoration: const InputDecoration(
                  labelText: 'Phản hồi của bạn',
                ),
              ),
              FilledButton(
                onPressed: busy ? null : reply,
                child: const Text('Gửi phản hồi'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notices = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Thông báo')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: PushSettingsPanel(),
          ),
          Expanded(
            child: notices.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _Retry(
                error: e.toString(),
                retry: () => ref.invalidate(notificationsProvider),
              ),
              data: (items) => RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(notificationsProvider);
                  await ref.read(notificationsProvider.future);
                },
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    if (items.isEmpty)
                      const GrapNotice('Chưa có thông báo mới.'),
                    for (final n in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: GrapCard(
                          padding: const EdgeInsets.all(5),
                          child: ListTile(
                            leading: Icon(
                              n.read
                                  ? Icons.notifications_none
                                  : Icons.notifications_active_outlined,
                              color: grapGreen,
                            ),
                            title: Text(
                              n.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: n.read
                                    ? FontWeight.w400
                                    : FontWeight.w700,
                              ),
                            ),
                            subtitle: Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(
                                '${n.body}\n${n.createdAt.toLocal().toString().substring(0, 16)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  height: 1.7,
                                ),
                              ),
                            ),
                            onTap: () async {
                              try {
                                await ref
                                    .read(accountRepositoryProvider)
                                    .markRead(n.id);
                                ref.invalidate(notificationsProvider);
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(e.toString())),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GrapRecoveryBanner extends ConsumerStatefulWidget {
  final Future<void> Function() onRecovered;
  const GrapRecoveryBanner({super.key, required this.onRecovered});
  @override
  ConsumerState<GrapRecoveryBanner> createState() => _RecoveryState();
}

class _RecoveryState extends ConsumerState<GrapRecoveryBanner> {
  bool busy = false;
  String? error;
  @override
  Widget build(BuildContext context) {
    final operations = ref.watch(pendingOperationsProvider);
    return operations.maybeWhen(
      data: (items) => items.isEmpty
          ? const SizedBox.shrink()
          : GrapCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GrapNotice(
                    '${items.length} thao tác chưa được xác nhận. Nội dung và khóa gốc được lưu trên thiết bị; kiểm tra lại trước khi tiếp tục chuyến mới.',
                  ),
                  if (error != null) GrapNotice(error!, error: true),
                  FilledButton(
                    onPressed: busy
                        ? null
                        : () async {
                            setState(() {
                              busy = true;
                              error = null;
                            });
                            final repository = ref.read(
                              recoveryRepositoryProvider,
                            );
                            try {
                              for (final item in items) {
                                await repository.retry(item.id);
                              }
                              await widget.onRecovered();
                            } catch (e) {
                              if (mounted) setState(() => error = e.toString());
                            } finally {
                              if (mounted) {
                                ref.invalidate(pendingOperationsProvider);
                                setState(() => busy = false);
                              }
                            }
                          },
                    child: Text(
                      busy
                          ? 'Đang kiểm tra…'
                          : 'Kiểm tra & gửi lại thao tác gốc',
                    ),
                  ),
                ],
              ),
            ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class RideShareSheet extends ConsumerStatefulWidget {
  final RideSnapshot ride;
  const RideShareSheet({super.key, required this.ride});
  @override
  ConsumerState<RideShareSheet> createState() => _RideShareState();
}

class _RideShareState extends ConsumerState<RideShareSheet> {
  RideShare? share;
  String? error;
  bool busy = true;
  @override
  void initState() {
    super.initState();
    Future.microtask(create);
  }

  Future<void> create() async {
    try {
      final result = await ref
          .read(accountRepositoryProvider)
          .createShare(widget.ride);
      if (mounted) setState(() => share = result);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Chia sẻ chuyến có thời hạn'),
    content: SizedBox(
      width: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (busy) const LinearProgressIndicator(),
          if (error != null) GrapNotice(error!, error: true),
          if (share != null) ...[
            SelectableText(
              share!.url,
              style: const TextStyle(fontSize: 14, height: 1.7),
            ),
            const SizedBox(height: 16),
            const GrapNotice(
              'Liên kết ngừng cung cấp vị trí khi hết hạn, bị thu hồi hoặc chuyến kết thúc.',
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  Clipboard.setData(ClipboardData(text: share!.url)),
              icon: const Icon(Icons.copy, size: 17),
              label: const Text('Sao chép liên kết'),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: busy ? null : () => Navigator.pop(context),
        child: const Text('Đóng'),
      ),
      if (share != null)
        TextButton(
          onPressed: busy
              ? null
              : () async {
                  setState(() => busy = true);
                  try {
                    await ref
                        .read(accountRepositoryProvider)
                        .revokeShare(widget.ride, share!.id);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (mounted) {
                      setState(() {
                        busy = false;
                        error = e.toString();
                      });
                    }
                  }
                },
          child: const Text('Thu hồi liên kết'),
        ),
    ],
  );
}

class _Retry extends StatelessWidget {
  final String error;
  final VoidCallback retry;
  const _Retry({required this.error, required this.retry});
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GrapNotice(error, error: true),
          TextButton(onPressed: retry, child: const Text('Thử lại')),
        ],
      ),
    ),
  );
}
