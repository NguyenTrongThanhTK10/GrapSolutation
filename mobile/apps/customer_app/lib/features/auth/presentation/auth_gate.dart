import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:grap_customer/core/core.dart';
import 'package:grap_customer/core/widgets/app_widgets.dart';

class AuthGate extends ConsumerStatefulWidget {
  final String role, title;
  final Widget Function(GrapUser) builder;
  const AuthGate({
    super.key,
    required this.role,
    required this.title,
    required this.builder,
  });
  @override
  ConsumerState<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends ConsumerState<AuthGate> {
  final phone = TextEditingController(), otp = TextEditingController();
  String? selected, error;
  OtpChallengeSnapshot? challenge;
  bool sending = false;
  @override
  void dispose() {
    phone.dispose();
    otp.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    if (session.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = session.value;
    if (user != null && user.role == widget.role) return widget.builder(user);
    final accounts = ref.watch(developmentAccountsProvider(widget.role));
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(27),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 430),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GrapBrandLockup(driver: widget.role == 'Driver'),
                  const SizedBox(height: 28),
                  if (MediaQuery.textScalerOf(context).scale(14) <= 20 &&
                      MediaQuery.sizeOf(context).height > 650) ...[
                    Container(
                      height: 176,
                      decoration: BoxDecoration(
                        color: const Color(0xffe8f4ec),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Stack(
                        children: [
                          Positioned(
                            left: 20,
                            top: 22,
                            width: 140,
                            child: Text(
                              widget.role == 'Driver'
                                  ? 'Chủ động\ntừng hành trình.'
                                  : 'Đi lại dễ dàng.\nSống thêm thảnh thơi.',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: grapInk,
                                height: 1.3,
                              ),
                            ),
                          ),
                          Positioned(
                            right: -26,
                            bottom: -18,
                            child: Image.asset(
                              'assets/illustrations/ride_car.png',
                              width: 230,
                              height: 170,
                              fit: BoxFit.contain,
                              cacheWidth: 690,
                              excludeFromSemantics: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],
                  const Text(
                    'Chào mừng bạn!',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: grapInk,
                      letterSpacing: -.7,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    enableDevelopmentLogin
                        ? 'Chọn tài khoản để trải nghiệm Grap.'
                        : 'Đăng nhập để bắt đầu hành trình của bạn.',
                    style: const TextStyle(
                      fontSize: 14,
                      color: grapMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (enableDevelopmentLogin) ...[
                    const GrapNotice(
                      'Đăng nhập phát triển · Dữ liệu mẫu tại backend local. Không sử dụng cho tài khoản thật.',
                    ),
                    accounts.when(
                      data: (items) => DropdownButtonFormField<String>(
                        initialValue: selected,
                        decoration: const InputDecoration(
                          labelText: 'Tài khoản trải nghiệm',
                        ),
                        isExpanded: true,
                        items: items
                            .map(
                              (u) => DropdownMenuItem(
                                value: u.id,
                                child: Text(
                                  u.name,
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (id) => setState(() => selected = id),
                      ),
                      loading: () => const LinearProgressIndicator(),
                      error: (e, _) => GrapNotice(e.toString(), error: true),
                    ),
                    const SizedBox(height: 18),
                    FilledButton(
                      onPressed: selected == null
                          ? null
                          : () => ref
                                .read(sessionProvider.notifier)
                                .developmentLogin(selected!),
                      child: const Text('Bắt đầu trải nghiệm'),
                    ),
                  ] else ...[
                    TextField(
                      controller: phone,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Số điện thoại',
                        prefixIcon: Icon(Icons.phone_outlined),
                      ),
                    ),
                    const SizedBox(height: 15),
                    if (challenge != null)
                      TextField(
                        controller: otp,
                        keyboardType: TextInputType.number,
                        maxLength: 6,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration: const InputDecoration(labelText: 'Mã OTP'),
                      ),
                    if (challenge != null) ...[
                      ExpiryBuilder(
                        deadline: challenge!.expiresAt,
                        builder: (seconds) => Text(
                          seconds > 0
                              ? 'Mã còn hiệu lực $seconds giây'
                              : 'Mã đã hết hạn. Vui lòng gửi lại.',
                          style: const TextStyle(
                            fontSize: 14,
                            color: grapMuted,
                          ),
                        ),
                      ),
                      ExpiryBuilder(
                        deadline: challenge!.resendAt,
                        builder: (seconds) => TextButton(
                          onPressed: sending || seconds > 0
                              ? null
                              : () async {
                                  setState(() {
                                    sending = true;
                                    error = null;
                                  });
                                  try {
                                    final next = await ref
                                        .read(sessionProvider.notifier)
                                        .requestOtp(
                                          phone.text,
                                          widget.role == 'Driver'
                                              ? 'driver'
                                              : 'customer',
                                        );
                                    if (mounted) {
                                      setState(() {
                                        challenge = next;
                                        otp.clear();
                                      });
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() => error = e.toString());
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() => sending = false);
                                    }
                                  }
                                },
                          child: Text(
                            seconds > 0
                                ? 'Gửi lại sau $seconds giây'
                                : 'Gửi lại mã xác minh',
                          ),
                        ),
                      ),
                    ],
                    FilledButton(
                      onPressed: sending
                          ? null
                          : () async {
                              setState(() {
                                sending = true;
                                error = null;
                              });
                              try {
                                if (challenge == null) {
                                  final id = await ref
                                      .read(sessionProvider.notifier)
                                      .requestOtp(
                                        phone.text,
                                        widget.role == 'Driver'
                                            ? 'driver'
                                            : 'customer',
                                      );
                                  if (mounted) setState(() => challenge = id);
                                } else {
                                  if (!challenge!.expiresAt.isAfter(
                                    DateTime.now().toUtc(),
                                  )) {
                                    throw const Failure(
                                      'OTP_EXPIRED',
                                      'Mã đã hết hạn. Vui lòng gửi lại.',
                                    );
                                  }
                                  if (!RegExp(r'^\d{6}$').hasMatch(otp.text)) {
                                    throw const Failure(
                                      'OTP_INVALID',
                                      'Nhập đủ 6 chữ số của mã xác minh.',
                                    );
                                  }
                                  await ref
                                      .read(sessionProvider.notifier)
                                      .verify(challenge!.id, otp.text);
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() => error = e.toString());
                                }
                              } finally {
                                if (mounted) setState(() => sending = false);
                              }
                            },
                      child: Text(
                        challenge == null ? 'Nhận mã xác minh' : 'Đăng nhập',
                      ),
                    ),
                  ],
                  if (error != null || session.hasError)
                    GrapNotice(error ?? session.error.toString(), error: true),
                  const SizedBox(height: 28),
                  const Text(
                    'Thông tin cá nhân được bảo vệ. Mọi giao dịch và trạng thái chuyến được xác nhận bởi máy chủ.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: grapMuted,
                      height: 1.9,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
