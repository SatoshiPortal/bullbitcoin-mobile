/// The request timeouts of a `Bbx`, per phase.
///
/// A null or zero duration means no timeout on that phase, so the default
/// [BbxTimeouts] waits as long as the server takes.
final class BbxTimeouts {
  final Duration? connect;
  final Duration? send;
  final Duration? receive;

  const BbxTimeouts({this.connect, this.send, this.receive});

  /// The 30-second phase timeouts the app's authenticated clients use.
  static const standard = BbxTimeouts(
    connect: Duration(seconds: 30),
    send: Duration(seconds: 30),
    receive: Duration(seconds: 30),
  );

  /// No timeout on any phase.
  static const none = BbxTimeouts();
}
