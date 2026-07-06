import 'package:bb_mobile/features/pos/domain/pos_error.dart';
import 'package:bb_mobile/features/pos/domain/pos_terminal.dart';
import 'package:bb_mobile/features/pos/domain/usecases/get_pos_usecase.dart';

/// A "does a POS exist yet?" probe for the provisioning/status surface: returns
/// null when the server has no pos row, and rethrows every other failure
/// (network, unreachable, malformed) so the caller can degrade loudly rather
/// than treat an unreachable server as "no POS".
class FindPosUsecase {
  final GetPosUsecase _getPos;

  const FindPosUsecase(this._getPos);

  Future<PosTerminal?> execute({required String nym}) async {
    try {
      return await _getPos.execute(nym: nym);
    } on PosException catch (e) {
      if (e.kind == PosErrorKind.notFound) return null;
      rethrow;
    }
  }
}
