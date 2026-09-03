import 'package:bb_mobile/features/wallet/domain/wallet.dart';

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
