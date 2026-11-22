import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Server address. Override at build time:
///   flutter run --dart-define=STAGE_SERVER=ws://192.168.1.20:8787
/// Android emulator: ws://10.0.2.2:8787
const serverUrl = String.fromEnvironment('STAGE_SERVER', defaultValue: 'ws://localhost:8787');

class StageSocket {
  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  final _messages = StreamController<Map<String, dynamic>>.broadcast();
  final _closed = StreamController<void>.broadcast();

  Stream<Map<String, dynamic>> get messages => _messages.stream;
  Stream<void> get closed => _closed.stream;
  bool get isOpen => _channel != null;

  Future<void> connect() async {
    await close();
    final channel = WebSocketChannel.connect(Uri.parse(serverUrl));
    await channel.ready;
    _channel = channel;
    _sub = channel.stream.listen(
      (raw) {
        try {
          final decoded = jsonDecode(raw as String);
          if (decoded is Map<String, dynamic>) _messages.add(decoded);
        } catch (_) {
          // Ignore anything that isn't valid JSON.
        }
      },
      onDone: _onClosed,
      onError: (_) => _onClosed(),
    );
  }

  void send(Map<String, dynamic> msg) => _channel?.sink.add(jsonEncode(msg));

  void _onClosed() {
    _channel = null;
    _closed.add(null);
  }

  Future<void> close() async {
    await _sub?.cancel();
    await _channel?.sink.close();
    _channel = null;
  }
}
