import 'package:grap_customer/features/account/presentation/account_screens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_customer/core/core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';

class SafetyContactsScreen extends ConsumerWidget {
  const SafetyContactsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(
      title: const Text('Liên hệ tin cậy'),
      actions: [
        IconButton(
          tooltip: 'Làm mới liên hệ',
          onPressed: () => ref.invalidate(trustedContactsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: ref.watch(trustedContactsProvider).value?.offline == true
          ? null
          : () => _edit(context, ref),
      icon: const Icon(Icons.person_add_alt),
      label: const Text('Thêm liên hệ'),
    ),
    body: ref
        .watch(trustedContactsProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GrapNotice(e.toString(), error: true),
                TextButton(
                  onPressed: () => ref.invalidate(trustedContactsProvider),
                  child: const Text('Thử lại'),
                ),
              ],
            ),
          ),
          data: (d) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              const GrapNotice(
                'Lưu tối đa 5 người đã đồng ý làm liên hệ tin cậy. Chạm nút gọi để mở ứng dụng điện thoại.',
              ),
              if (d.offline)
                const GrapNotice(
                  'Đang ngoại tuyến: hiển thị bản lưu trên thiết bị. Cần có mạng để thêm, sửa hoặc xóa.',
                ),
              if (d.items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('Bạn chưa lưu liên hệ tin cậy.'),
                ),
              for (final p in d.items)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: GrapCard(
                    padding: const EdgeInsets.all(6),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person_outline),
                          ),
                          title: Text(p.name),
                          subtitle: Text(p.phone),
                          trailing: IconButton(
                            tooltip: 'Gọi ${p.name}',
                            icon: const Icon(
                              Icons.call_outlined,
                              color: grapGreen,
                            ),
                            onPressed: () async {
                              try {
                                final opened = await launchUrl(
                                  Uri(scheme: 'tel', path: p.phone),
                                );
                                if (!opened && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Thiết bị không mở được cuộc gọi. Số liên hệ: ${p.phone}',
                                      ),
                                    ),
                                  );
                                }
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Không mở được điện thoại. Vui lòng gọi ${p.phone}',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton(
                              onPressed: d.offline
                                  ? null
                                  : () => _edit(context, ref, p),
                              child: const Text('Sửa'),
                            ),
                            TextButton(
                              onPressed: d.offline
                                  ? null
                                  : () async {
                                      if (await confirmRemoval(
                                            context,
                                            'Xóa liên hệ ${p.name}?',
                                          ) !=
                                          true) {
                                        return;
                                      }
                                      try {
                                        await ref
                                            .read(journeyRepositoryProvider)
                                            .deleteContact(p);
                                        ref.invalidate(trustedContactsProvider);
                                      } catch (e) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                                SnackBar(
                                                  content: Text(e.toString()),
                                                ),
                                              );
                                        }
                                        ref.invalidate(trustedContactsProvider);
                                      }
                                    },
                              child: const Text('Xóa'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
  );
  Future<void> _edit(
    BuildContext context,
    WidgetRef ref, [
    TrustedPerson? person,
  ]) async {
    if (await Navigator.push<bool>(
          context,
          MaterialPageRoute(builder: (_) => _ContactEditor(person: person)),
        ) ==
        true) {
      ref.invalidate(trustedContactsProvider);
    }
  }
}

class _ContactEditor extends ConsumerStatefulWidget {
  final TrustedPerson? person;
  const _ContactEditor({this.person});
  @override
  ConsumerState<_ContactEditor> createState() => _ContactState();
}

class _ContactState extends ConsumerState<_ContactEditor> {
  late final name = TextEditingController(text: widget.person?.name ?? ''),
      phone = TextEditingController(text: widget.person?.phone ?? '');
  bool consent = false, busy = false;
  String? error;
  bool conflict = false;
  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Thông tin liên hệ tin cậy')),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        TextField(
          controller: name,
          maxLength: 100,
          enabled: !busy,
          decoration: const InputDecoration(labelText: 'Tên liên hệ'),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: phone,
          maxLength: 20,
          enabled: !busy,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            labelText: 'Số điện thoại',
            hintText: '09… hoặc +84…',
          ),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          value: consent,
          onChanged: busy ? null : (v) => setState(() => consent = v ?? false),
          title: const Text(
            'Người này đã đồng ý cho tôi lưu số làm liên hệ tin cậy.',
            style: TextStyle(fontSize: 14),
          ),
        ),
        if (error != null) GrapNotice(error!, error: true),
        if (conflict)
          GrapConflictNotice(
            onReload: () {
              ref.invalidate(trustedContactsProvider);
              Navigator.pop(context, true);
            },
          ),
        FilledButton(
          onPressed: busy || conflict || !consent
              ? null
              : () async {
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    await ref
                        .read(journeyRepositoryProvider)
                        .saveContact(
                          name.text,
                          phone.text,
                          consent,
                          current: widget.person,
                        );
                    if (context.mounted) Navigator.pop(context, true);
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
                },
          child: Text(busy ? 'Đang lưu…' : 'Lưu liên hệ'),
        ),
      ],
    ),
  );
}

String deletionLabel(String status) =>
    const {
      'REQUESTED': 'Đã gửi yêu cầu',
      'BLOCKED_OBLIGATIONS': 'Cần hoàn tất nghĩa vụ còn lại',
      'IN_REVIEW': 'Đang được kiểm tra',
      'NEEDS_INFORMATION': 'Cần bổ sung thông tin',
      'REJECTED': 'Yêu cầu bị từ chối',
      'WITHDRAWN': 'Bạn đã rút yêu cầu',
    }[status] ??
    status;
String deletionBlocker(String blocker) =>
    const {
      'ACTIVE_RIDE': 'Có chuyến đang diễn ra',
      'OUTSTANDING_PAYMENT': 'Có khoản thanh toán chưa hoàn tất',
      'DRIVER_BALANCE_PENDING': 'Số dư tài xế cần được đối soát',
    }[blocker] ??
    blocker;

class DeletionRequestScreen extends ConsumerStatefulWidget {
  const DeletionRequestScreen({super.key});
  @override
  ConsumerState<DeletionRequestScreen> createState() => _DeletionState();
}

class _DeletionState extends ConsumerState<DeletionRequestScreen> {
  final reason = TextEditingController();
  bool busy = false;
  String? error;
  @override
  void dispose() {
    reason.dispose();
    super.dispose();
  }

  Future<void> perform(Future<void> Function() action) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await action();
      if (mounted) {
        ref.invalidate(deletionRequestsProvider);
        ref.invalidate(ticketsProvider);
        reason.clear();
      }
    } catch (e) {
      if (mounted) {
        setState(() => error = e.toString());
        ref.invalidate(deletionRequestsProvider);
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Yêu cầu xóa tài khoản'),
      actions: [
        IconButton(
          tooltip: 'Làm mới',
          onPressed: () => ref.invalidate(deletionRequestsProvider),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(22),
      children: [
        const GrapNotice(
          'Gửi yêu cầu để bộ phận bảo mật kiểm tra. Tài khoản và dữ liệu chưa bị xóa khi gửi yêu cầu. Bạn có thể rút yêu cầu trong lúc chờ xử lý.',
        ),
        const SizedBox(height: 16),
        ref
            .watch(deletionRequestsProvider)
            .when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Column(
                children: [
                  GrapNotice(e.toString(), error: true),
                  TextButton(
                    onPressed: () => ref.invalidate(deletionRequestsProvider),
                    child: const Text('Thử lại'),
                  ),
                ],
              ),
              data: (items) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final d in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: GrapCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              deletionLabel(d.status),
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 12),
                            Text(d.reason),
                            for (final b in d.blockers)
                              GrapNotice(deletionBlocker(b)),
                            if (d.reviewNote != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text('Phản hồi: ${d.reviewNote}'),
                              ),
                            TextButton(
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute<void>(
                                  builder: (_) =>
                                      TicketScreen(ticketId: d.ticketId),
                                ),
                              ),
                              child: const Text('Trao đổi với bộ phận hỗ trợ'),
                            ),
                            if (d.open)
                              Wrap(
                                spacing: 8,
                                children: [
                                  OutlinedButton(
                                    onPressed: busy
                                        ? null
                                        : () => perform(
                                            () => ref
                                                .read(journeyRepositoryProvider)
                                                .changeDeletion(d, 'recheck'),
                                          ),
                                    child: const Text('Kiểm tra nghĩa vụ'),
                                  ),
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () async {
                                            final yes = await showDialog<bool>(
                                              context: context,
                                              builder: (_) => AlertDialog(
                                                title: const Text(
                                                  'Rút yêu cầu xóa tài khoản?',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          false,
                                                        ),
                                                    child: const Text(
                                                      'Giữ yêu cầu',
                                                    ),
                                                  ),
                                                  FilledButton(
                                                    onPressed: () =>
                                                        Navigator.pop(
                                                          context,
                                                          true,
                                                        ),
                                                    child: const Text(
                                                      'Rút yêu cầu',
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (yes == true && mounted) {
                                              perform(
                                                () => ref
                                                    .read(
                                                      journeyRepositoryProvider,
                                                    )
                                                    .changeDeletion(
                                                      d,
                                                      'cancel',
                                                    ),
                                              );
                                            }
                                          },
                                    child: const Text('Rút yêu cầu'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (!items.any((d) => d.open)) ...[
                    TextField(
                      controller: reason,
                      maxLength: 1000,
                      maxLines: 4,
                      enabled: !busy,
                      decoration: const InputDecoration(
                        labelText: 'Lý do yêu cầu (ít nhất 5 ký tự)',
                      ),
                    ),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () {
                              if (reason.text.trim().length < 5) {
                                setState(
                                  () => error =
                                      'Vui lòng nhập lý do ít nhất 5 ký tự.',
                                );
                                return;
                              }
                              perform(
                                () => ref
                                    .read(journeyRepositoryProvider)
                                    .requestDeletion(reason.text),
                              );
                            },
                      child: Text(
                        busy
                            ? 'Đang gửi…'
                            : 'Gửi yêu cầu kiểm tra xóa tài khoản',
                      ),
                    ),
                  ],
                ],
              ),
            ),
        if (error != null) GrapNotice(error!, error: true),
      ],
    ),
  );
}
