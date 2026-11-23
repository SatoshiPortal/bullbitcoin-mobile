import 'package:electrum/electrum.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/features/wallet/data/wallet_repository.dart';

class WatchElectrumSyncResultsUsecase {
  final WalletRepository _walletRepository;

  WatchElectrumSyncResultsUsecase({required this._walletRepository});

  Stream<ElectrumSyncResult> execute() {
    try {
      return _walletRepository.electrumSyncResultStream;
    } catch (e) {
      throw WatchElectrumSyncResultsException(e.toString());
    }
  }
}

class WatchElectrumSyncResultsException extends BullException {
  WatchElectrumSyncResultsException(super.message);
}
