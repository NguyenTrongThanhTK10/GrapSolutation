import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'package:grap_driver/core/core.dart';
import 'package:grap_driver/core/domain/ride_chat.dart';
import 'package:grap_driver/core/providers/ride_chat_providers.dart';

class RideChatButton extends StatelessWidget {
  final String rideId;
  final bool readOnly;
  const RideChatButton({
    super.key,
    required this.rideId,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    icon: const Icon(Icons.chat_bubble_outline_rounded),
    label: Text(readOnly ? 'Xem tin nhắn chuyến xe' : 'Nhắn tin với khách'),
    onPressed: () => Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => RideChatScreen(rideId: rideId)),
    ),
  );
}

class RideChatScreen extends ConsumerStatefulWidget {
  final String rideId;
  const RideChatScreen({super.key, required this.rideId});

  @override
  ConsumerState<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends ConsumerState<RideChatScreen>
    with WidgetsBindingObserver {
  final _text = TextEditingController();
  final _messages = <RideMessage>[];
  StreamSubscription<void>? _updates;
  RideChatPage? _page;
  String? _actor,
      _error,
      _sendError,
      _pendingBody,
      _pendingKey,
      _pendingAssignment;
  int? _before;
  int _generation = 0, _lastReadSequence = 0;
  bool _foreground = true,
      _fetching = false,
      _refreshPending = false,
      _initialLoading = true,
      _olderLoading = false,
      _sending = false;

  bool get _sameActor =>
      mounted &&
      _actor != null &&
      ref.read(sessionProvider).value?.id == _actor;
  bool get _canSend => _page?.canSend == true && _foreground && _sameActor;
  RideChatRepository get _repository => ref.read(rideChatRepositoryProvider);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _actor = ref.read(sessionProvider).value?.id;
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (_foreground) _connect();
  }

  void _connect() {
    if (!_sameActor) return;
    _updates = _repository.updates().listen(
      (_) => unawaited(_load()),
      onError: (Object _) => unawaited(_load()),
    );
    unawaited(_load());
  }

  void _stop() {
    _generation++;
    unawaited(_updates?.cancel());
    _updates = null;
    _fetching = false;
    _olderLoading = false;
    _refreshPending = false;
    _sending = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    setState(() => _foreground = foreground);
    _stop();
    if (foreground) _connect();
  }

  void _merge(Iterable<RideMessage> incoming) {
    final byId = {for (final item in _messages) item.id: item};
    for (final item in incoming) {
      byId[item.id] = item;
    }
    _messages
      ..clear()
      ..addAll(byId.values);
    _messages.sort((a, b) => a.sequence.compareTo(b.sequence));
  }

  void _clearThread() {
    _messages.clear();
    _page = null;
    _before = null;
    _lastReadSequence = 0;
    _pendingBody = _pendingKey = _pendingAssignment = null;
    _sendError = null;
    _text.clear();
  }

  Future<void> _load({bool older = false}) async {
    if (!_sameActor || !_foreground) return;
    if (_fetching) {
      if (!older) _refreshPending = true;
      return;
    }
    final generation = _generation;
    _fetching = true;
    if (older) setState(() => _olderLoading = true);
    try {
      var after = !older && _page != null ? _lastReadSequence : null;
      do {
        final page = await _repository.load(
          widget.rideId,
          beforeSequence: older ? _before : null,
          afterSequence: after,
        );
        if (!_sameActor || generation != _generation) return;
        if (_page != null && _page!.assignmentId != page.assignmentId) {
          setState(() {
            _clearThread();
            _error = 'Tài xế đã thay đổi. Đã mở cuộc trò chuyện mới.';
          });
          _refreshPending = true;
          return;
        }
        setState(() {
          if (after == null) _before = page.nextBeforeSequence;
          _page = page;
          _merge(page.items);
          if (!older && page.items.isNotEmpty) {
            _lastReadSequence = page.items.last.sequence;
          }
          _error = null;
          _initialLoading = false;
        });
        if (older || after == null || !page.hasMore || page.items.isEmpty) {
          break;
        }
        after = _lastReadSequence;
      } while (_foreground);
    } catch (error) {
      if (!_sameActor || generation != _generation) return;
      setState(() {
        if (error is Failure &&
            const [
              'RESOURCE_NOT_FOUND',
              'FORBIDDEN',
              'CHAT_UNAVAILABLE',
              'CHAT_ASSIGNMENT_CHANGED',
            ].contains(error.code)) {
          _clearThread();
        }
        _error = error.toString();
        _initialLoading = false;
      });
    } finally {
      if (_sameActor && generation == _generation) {
        setState(() {
          _fetching = false;
          _olderLoading = false;
        });
        if (_refreshPending) {
          _refreshPending = false;
          unawaited(_load());
        }
      }
    }
  }

  Future<void> _send() async {
    if (!_canSend || _sending) return;
    final body = _pendingBody ?? _text.text.trim();
    if (body.isEmpty) return;
    if (body.length > 1000) {
      setState(() => _sendError = 'Tin nhắn cần từ 1–1.000 ký tự.');
      return;
    }
    final generation = _generation;
    final assignment = _pendingAssignment ?? _page!.assignmentId;
    _pendingBody = body;
    _pendingAssignment = assignment;
    _pendingKey ??= const Uuid().v4();
    setState(() {
      _sending = true;
      _sendError = null;
    });
    try {
      final message = await _repository.send(
        widget.rideId,
        assignment,
        body,
        idempotencyKey: _pendingKey!,
      );
      if (!_sameActor || generation != _generation) return;
      if (_page?.assignmentId != message.assignmentId) return;
      setState(() {
        // Keep the read cursor separate from send acknowledgements to recover concurrent messages.
        _merge([message]);
        _text.clear();
        _pendingBody = _pendingKey = _pendingAssignment = null;
      });
      await _load();
    } catch (error) {
      if (!_sameActor || generation != _generation) return;
      setState(() {
        _sendError = error.toString();
        if (error is Failure &&
            const [
              'CHAT_CLOSED',
              'CHAT_ASSIGNMENT_CHANGED',
              'CHAT_UNAVAILABLE',
              'RESOURCE_NOT_FOUND',
              'FORBIDDEN',
              'VALIDATION_ERROR',
            ].contains(error.code)) {
          _pendingBody = _pendingKey = _pendingAssignment = null;
        }
      });
      unawaited(_load());
    } finally {
      if (_sameActor && generation == _generation) {
        setState(() => _sending = false);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(sessionProvider, (previous, next) {
      if (next.isLoading || next.value?.id == _actor) return;
      _stop();
      setState(_clearThread);
    });
    final user = ref.watch(sessionProvider).value;
    if (user?.id != _actor || _actor == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Tin nhắn chuyến xe')),
        body: const Center(
          child: Text('Vui lòng đăng nhập lại để xem tin nhắn.'),
        ),
      );
    }
    final driver = user!.role == 'Driver';
    final quickReplies = driver
        ? [
            'Tôi đã đến điểm đón.',
            'Bạn đang ở đâu?',
            'Tôi sẽ đến trong ít phút.',
          ]
        : [
            'Tôi đang ở điểm đón.',
            'Anh/chị chờ tôi một chút nhé.',
            'Anh/chị đang ở đâu?',
          ];
    return Scaffold(
      backgroundColor: const Color(0xfff3f7f4),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _page?.peerName ??
                  (driver ? 'Nhắn tin với khách' : 'Nhắn tin với tài xế'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (_page != null)
              Text(
                'Chuyến ${_page!.rideCode}',
                style: const TextStyle(fontSize: 12, color: Color(0xff68776d)),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Làm mới tin nhắn',
            onPressed: _fetching ? null : () => _load(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (!_foreground)
              const _ChatNotice('Tạm dừng cập nhật khi ứng dụng ở nền.'),
            if (_error != null) _ChatNotice(_error!, onRetry: () => _load()),
            if (_page?.canSend == false)
              const _ChatNotice(
                'Chuyến đã kết thúc. Bạn có thể xem lại cuộc trò chuyện.',
              ),
            Expanded(
              child: _initialLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _messages.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(28),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 48,
                              color: Color(0xff00a868),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'Chưa có tin nhắn',
                              style: TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              driver
                                  ? 'Trao đổi với khách để hẹn điểm đón.'
                                  : 'Gửi lời nhắn để tài xế dễ tìm thấy bạn.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: _messages.length + (_before != null ? 1 : 0),
                      itemBuilder: (context, index) {
                        if (index == _messages.length) {
                          return Center(
                            child: TextButton(
                              onPressed: _fetching
                                  ? null
                                  : () => _load(older: true),
                              child: Text(
                                _olderLoading
                                    ? 'Đang tải…'
                                    : 'Xem tin nhắn trước',
                              ),
                            ),
                          );
                        }
                        final message = _messages[_messages.length - index - 1];
                        return _MessageBubble(
                          key: ValueKey(message.id),
                          message: message,
                          mine: message.senderId == _actor,
                        );
                      },
                    ),
            ),
            if (_sendError != null)
              _ChatNotice('$_sendError Nhấn Gửi lại để thử lại.'),
            if (_page?.canSend == true)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final reply in quickReplies)
                            Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: ActionChip(
                                label: Text(reply),
                                onPressed:
                                    !_canSend ||
                                        _sending ||
                                        _pendingBody != null
                                    ? null
                                    : () {
                                        _text.text = reply;
                                        _text.selection =
                                            TextSelection.collapsed(
                                              offset: reply.length,
                                            );
                                      },
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _text,
                            readOnly: _sending || _pendingBody != null,
                            enabled: _canSend,
                            minLines: 1,
                            maxLines: 4,
                            maxLength: 1000,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Nhập tin nhắn…',
                              counterText: '',
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _text,
                          builder: (context, value, _) => IconButton.filled(
                            tooltip: _pendingBody != null && !_sending
                                ? 'Gửi lại'
                                : 'Gửi tin nhắn',
                            onPressed:
                                !_canSend ||
                                    _sending ||
                                    value.text.trim().isEmpty
                                ? null
                                : _send,
                            icon: _sending
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Icon(
                                    _pendingBody != null
                                        ? Icons.refresh
                                        : Icons.send_rounded,
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChatNotice extends StatelessWidget {
  final String text;
  final VoidCallback? onRetry;
  const _ChatNotice(this.text, {this.onRetry});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    color: const Color(0xfffff5dd),
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    child: Row(
      children: [
        Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        if (onRetry != null)
          TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  final RideMessage message;
  final bool mine;
  const _MessageBubble({super.key, required this.message, required this.mine});
  @override
  Widget build(BuildContext context) {
    final time = message.createdAt.toLocal();
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * .78,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: mine ? const Color(0xff008f59) : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            SelectableText(
              message.body,
              style: TextStyle(
                fontSize: 15,
                color: mine ? Colors.white : const Color(0xff182e22),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 11,
                color: mine ? Colors.white70 : const Color(0xff68776d),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
