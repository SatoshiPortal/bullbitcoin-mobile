import 'package:bb_mobile/core/wallet/domain/entities/wallet_sync_progress.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_sync_repository.dart';

class WatchWalletSyncProgressUsecase {
  final WalletSyncRepository _walletSyncRepository;

  WatchWalletSyncProgressUsecase({required this._walletSyncRepository});

  Stream<WalletSyncProgress> execute() => _walletSyncRepository.watchProgress();
}
