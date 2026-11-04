import 'package:wallet/wallet.dart';
import 'package:primitives/primitives.dart';

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
