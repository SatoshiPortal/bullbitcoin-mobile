import 'package:mempool/mempool.dart';

enum MempoolServerStatus { online, offline, checking, unknown }

class MempoolServerRow {
  final MempoolServer server;
  final MempoolServerStatus status;

  const MempoolServerRow(
    this.server, {
    this.status = MempoolServerStatus.unknown,
  });

  @override
  bool operator ==(Object other) =>
      other is MempoolServerRow &&
      other.server == server &&
      other.status == status;

  @override
  int get hashCode => Object.hash(server, status);
}
