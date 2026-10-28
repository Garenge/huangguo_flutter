import 'dart:io';

/// 本地 HTTP 服务器，用于让 video_player 以 HLS 方式播放已下载的 m3u8 + TS 分片。
/// 单例，每次播放时指定服务目录，播完关闭。
class LocalMediaServer {
  static final LocalMediaServer _instance = LocalMediaServer._();
  factory LocalMediaServer() => _instance;
  LocalMediaServer._();

  HttpServer? _server;
  int _port = 0;
  String? _serveDir;

  /// 启动服务器，绑定到指定目录，返回端口号。
  Future<int> start(String serveDir) async {
    stop();
    _serveDir = serveDir;
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;
    _server!.listen(_handleRequest);
    return _port;
  }

  /// 关闭服务器。
  void stop() {
    _server?.close();
    _server = null;
    _serveDir = null;
  }

  int get port => _port;
  bool get isRunning => _server != null;

  /// 播放地址：http://127.0.0.1:$port/playlist.m3u8
  String get playlistUrl => 'http://127.0.0.1:$port/playlist.m3u8';

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      final path = request.uri.path.substring(1); // 去掉开头的 /
      final filePath = '$_serveDir/$path';
      final file = File(filePath);

      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        request.response
          ..statusCode = HttpStatus.ok
          ..headers.contentType = _contentType(path)
          ..add(bytes);
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
    } catch (_) {
      request.response.statusCode = HttpStatus.internalServerError;
    }
    await request.response.close();
  }

  ContentType _contentType(String path) {
    if (path.endsWith('.m3u8')) {
      return ContentType('application', 'vnd.apple.mpegurl');
    }
    if (path.endsWith('.ts')) {
      return ContentType('video', 'mp2t');
    }
    return ContentType('application', 'octet-stream');
  }
}
