import 'package:mempool/mempool.dart';

class CheckMempoolServerStatusUsecase {
  final Mempool _mempool;

  const CheckMempoolServerStatusUsecase(this._mempool);

  Future<bool> execute(MempoolServer server) async =>
      (await _mempool.servers.validate(server)).fold((_) => true, (_) => false);
}
