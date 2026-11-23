import 'package:electrum/electrum.dart';
import 'package:primitives/legacy_exceptions.dart';
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
