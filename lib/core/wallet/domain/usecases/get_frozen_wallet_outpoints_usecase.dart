import 'package:bb_mobile/core/wallet/domain/entities/frozen_wallet_outpoint.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';

final class GetFrozenWalletOutpointsUsecase {
  final WalletUtxoRepository _repository;

  const GetFrozenWalletOutpointsUsecase(this._repository);

  Future<List<FrozenWalletOutpoint>> execute() {
    return _repository.getAllFrozenWalletOutpoints();
  }
}
