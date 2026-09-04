import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:meta/meta.dart';

class ResolveSelectedInputsUsecase {
  final PayjoinSessions _payjoinSessions;

  ResolveSelectedInputsUsecase(this._payjoinSessions);

  @useResult
  Future<Result<List<WalletUtxo>, SendFailure>> execute({
    required Set<Outpoint> outpoints,
    required List<WalletUtxo> availableUtxos,
  }) async {
    if (outpoints.isEmpty) {
      return const Err(SendSelectedCoinsUnavailableFailure());
    }
    final reservedResult = await _payjoinSessions.reservedOutpoints();
    final Set<Outpoint> reservedOutpoints;
    switch (reservedResult) {
      case Ok(:final value):
        reservedOutpoints = value;
      case Err(:final failure):
        return Err(SendTransactionBuildFailure(failure.logMessage));
    }
    final selected = availableUtxos
        .where((utxo) => outpoints.contains((txId: utxo.txId, vout: utxo.vout)))
        .toList();
    final selectedOutpoints = <Outpoint>{
      for (final utxo in selected) (txId: utxo.txId, vout: utxo.vout),
    };
    final isAvailable =
        selectedOutpoints.length == outpoints.length &&
        selected.every((utxo) => !utxo.isFrozen) &&
        !outpoints.any(reservedOutpoints.contains);
    if (!isAvailable) {
      return const Err(SendSelectedCoinsUnavailableFailure());
    }
    return Ok(selected);
  }
}
