import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/automatic_fallback/domain/automatic_fallback_failure.dart';
import 'package:bb_mobile/features/bullnym/public/bullnym_facade.dart'
    show BullnymAuthSigner;
import 'package:meta/meta.dart';

class AutomaticFallbackWalletContext {
  final String walletId;
  final BullnymAuthSigner signer;

  const AutomaticFallbackWalletContext({
    required this.walletId,
    required this.signer,
  });
}

abstract interface class AutomaticFallbackWalletPort {
  @useResult
  Future<Result<AutomaticFallbackWalletContext, AutomaticFallbackFailure>>
  loadCurrentDefaultBitcoinWallet();

  /// Reuse the one locally labeled, still-owned pending address when a prior
  /// registration attempt ended ambiguously. Returns null when none exists.
  @useResult
  Future<Result<String?, AutomaticFallbackFailure>> findPendingAddress(
    AutomaticFallbackWalletContext context,
  );

  @useResult
  Future<Result<String, AutomaticFallbackFailure>> generateFreshAddress(
    AutomaticFallbackWalletContext context,
  );

  @useResult
  Future<Result<bool, AutomaticFallbackFailure>> ownsAddress(
    AutomaticFallbackWalletContext context,
    String btcAddress,
  );

  @useResult
  Future<Result<void, AutomaticFallbackFailure>> ensureLabel(
    AutomaticFallbackWalletContext context,
    String btcAddress,
  );
}
