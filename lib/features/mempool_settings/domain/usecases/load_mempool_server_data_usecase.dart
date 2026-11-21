import 'package:mempool/mempool.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

class LoadMempoolServerDataUsecase {
  final Mempool _mempool;

  const LoadMempoolServerDataUsecase(this._mempool);

  @useResult
  Future<Result<LoadMempoolServerDataResponse, MempoolFailure>> execute(
    LoadMempoolServerDataRequest request,
  ) => _mempool.loadServers(request);
}
