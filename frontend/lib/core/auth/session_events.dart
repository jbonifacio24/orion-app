import 'dart:async';

class SessionEvents {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get onInvalidated => _controller.stream;

  void invalidate() {
    if (!_controller.isClosed) _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}