import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> tileBytes() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xffeeeeee), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

class TileHttpClient extends Fake implements HttpClient {
  final Uint8List bytes;
  final bool Function(int request) fails;
  int requests = 0;
  bool closed = false;

  TileHttpClient(this.bytes, {required this.fails});

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    requests++;
    if (fails(requests)) {
      throw const SocketException('Connection reset by peer');
    }
    return _TileRequest(bytes);
  }

  @override
  void close({bool force = false}) => closed = true;
}

class _TileRequest extends Fake implements HttpClientRequest {
  final Uint8List bytes;
  _TileRequest(this.bytes);

  @override
  final HttpHeaders headers = _TileHeaders();
  @override
  set followRedirects(bool value) {}
  @override
  set maxRedirects(int value) {}
  @override
  set contentLength(int value) {}
  @override
  set persistentConnection(bool value) {}
  @override
  Future<void> addStream(Stream<List<int>> stream) => stream.drain<void>();
  @override
  Future<HttpClientResponse> close() async => _TileResponse(bytes);
  @override
  void abort([Object? exception, StackTrace? stackTrace]) {}
}

class _TileResponse extends Fake implements HttpClientResponse {
  final Uint8List bytes;
  _TileResponse(this.bytes);

  @override
  final HttpHeaders headers = _TileHeaders();
  @override
  int get statusCode => 200;
  @override
  int get contentLength => bytes.length;
  @override
  bool get isRedirect => false;
  @override
  bool get persistentConnection => true;
  @override
  String get reasonPhrase => 'OK';
  @override
  List<RedirectInfo> get redirects => const [];
  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int>)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) => Stream<List<int>>.value(bytes).listen(
    onData,
    onError: onError,
    onDone: onDone,
    cancelOnError: cancelOnError,
  );
}

class _TileHeaders extends Fake implements HttpHeaders {
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {}

  @override
  void forEach(void Function(String name, List<String> values) action) {
    action('content-type', ['image/png']);
    action('cache-control', ['max-age=0']);
  }
}
