import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';

final class RestoreFrozenWalletOutpointsUsecase {
  final WalletUtxoRepository _repository;

  const RestoreFrozenWalletOutpointsUsecase(this._repository);

  Future<void> execute(List<FrozenWalletOutpoint> outpoints) {
    return _repository.restoreFrozenWalletOutpoints(outpoints);
  }
}
