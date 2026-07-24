import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_sync_backend.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/bitcoin_sync_backend_repository.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_sync_failure.dart';

class GetBitcoinSyncBackendUsecase {
  final BitcoinSyncBackendRepository _bitcoinSyncBackendRepository;

  GetBitcoinSyncBackendUsecase({required this._bitcoinSyncBackendRepository});

  Future<Result<BitcoinSyncBackend, WalletSyncFailure>> execute({
    required String walletId,
  }) => _bitcoinSyncBackendRepository.get(walletId: walletId);
}
