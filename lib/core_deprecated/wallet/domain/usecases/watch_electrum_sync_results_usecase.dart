import 'package:bb_mobile/core_deprecated/electrum/domain/value_objects/electrum_sync_result.dart';
import 'package:bb_mobile/core_deprecated/errors/bull_exception.dart';
import 'package:bb_mobile/core_deprecated/wallet/data/repositories/wallet_repository.dart';

class WatchElectrumSyncResultsUsecase {
  final WalletRepository _walletRepository;

  WatchElectrumSyncResultsUsecase({required WalletRepository walletRepository})
    : _walletRepository = walletRepository;

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
