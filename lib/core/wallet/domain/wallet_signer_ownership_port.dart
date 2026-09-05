import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

abstract interface class WalletSignerOwnershipPort {
  Future<Wallet> markSignerLocal({
    required String walletId,
    required String signerId,
    required String seedFingerprint,
    required Set<String> passphraseProtectedKeyIds,
  });
}

final class WalletSignerOwnershipUpdateException implements Exception {
  const WalletSignerOwnershipUpdateException();
}
