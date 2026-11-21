import 'package:mempool/mempool.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class DeleteCustomMempoolServerUsecase {
  final Mempool _mempool;

  const DeleteCustomMempoolServerUsecase(this._mempool);

  @useResult
  Future<Result<void, MempoolFailure>> execute(
    DeleteCustomMempoolServerRequest request,
  ) => _mempool.deleteCustomServer(request);
}
