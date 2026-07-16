import 'package:bb_mobile/core/wallet/domain/repositories/wallet_utxo_repository.dart';

final class WatchWalletUtxoFreezeChangesUsecase {
  final WalletUtxoRepository _repository;

  const WatchWalletUtxoFreezeChangesUsecase(this._repository);

  Stream<void> execute() => _repository.freezeChanges;
}
