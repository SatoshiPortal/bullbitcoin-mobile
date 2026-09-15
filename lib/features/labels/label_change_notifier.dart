import 'dart:async';

final class LabelChangeNotifier {
  final _controller = StreamController<void>.broadcast(sync: true);

  Stream<void> get changes => _controller.stream;

  void notify() => _controller.add(null);
}
