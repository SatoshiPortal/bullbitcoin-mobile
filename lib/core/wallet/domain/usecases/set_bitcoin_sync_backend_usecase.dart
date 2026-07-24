import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_sync_backend_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';

class SetBitcoinSyncBackendUsecase {
  final BitcoinSyncBackendRepository _bitcoinSyncBackendRepository;

  SetBitcoinSyncBackendUsecase({required this._bitcoinSyncBackendRepository});

  Future<Result<void, WalletSyncFailure>> execute({
    required String walletId,
    required BitcoinSyncBackend backend,
  }) => _bitcoinSyncBackendRepository.set(walletId: walletId, backend: backend);
}
