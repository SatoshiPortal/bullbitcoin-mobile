import 'package:mempool/mempool.dart';

class CheckMempoolServerStatusUsecase {
  final Mempool _mempool;

  const CheckMempoolServerStatusUsecase(this._mempool);

  Future<bool> execute(MempoolServerDto server) async =>
      (await _mempool.validateServer(server)).fold((_) => true, (_) => false);
}
