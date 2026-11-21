import 'package:mempool/mempool.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class SetCustomMempoolServerUsecase {
  final Mempool _mempool;

  const SetCustomMempoolServerUsecase(this._mempool);

  @useResult
  Future<Result<void, MempoolFailure>> execute(
    SetCustomMempoolServerRequest request,
  ) => _mempool.setCustomServer(request);
}
