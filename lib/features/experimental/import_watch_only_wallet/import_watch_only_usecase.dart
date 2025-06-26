import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/repositories/wallet_repository.dart';
import 'package:satoshifier/satoshifier.dart' show WatchOnly;

class ImportWatchOnlyUsecase {
  final WalletRepository _wallet;

  ImportWatchOnlyUsecase({required WalletRepository walletRepository})
    : _wallet = walletRepository;

  Future<Wallet> call({
    required WatchOnly watchOnly,
    String label = '',
    String? masterFingerprint,
  }) async {
    try {
      final wallet = await _wallet.importWatchOnlySatoshifier(
        watchOnly: watchOnly,
        label: label,
        masterFingerprint: masterFingerprint,
      );

      return wallet;
    } catch (e) {
      throw ImportWatchOnlyException(e.toString());
    }
  }
}

class ImportWatchOnlyException implements Exception {
  final String message;

  ImportWatchOnlyException(this.message);
}
