import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

/// The wallet identity one passphrase produces, plus the private material that
/// would open it.
///
/// The caller takes ownership of [seed] the moment this is returned and is
/// responsible for clearing it (spec 20.3).
final class PassphraseWalletDerivation {
  final String walletId;
  final String combinedPublicDescriptor;
  final MnemonicSeed seed;

  const PassphraseWalletDerivation({
    required this.walletId,
    required this.combinedPublicDescriptor,
    required this.seed,
  });

  @override
  String toString() => 'PassphraseWalletDerivation(<redacted>)';
}

/// Derives the BIP84 account-0 wallet a passphrase produces from the active
/// mnemonic.
///
/// The implementation owns BIP39/BIP32/BDK and keeps the expensive part off the
/// UI thread; the use case above it sees domain values only. Failure is an
/// exception rather than a typed value here: nothing but "we could not derive"
/// can be said about it without describing the passphrase.
abstract interface class PassphraseWalletDeriver {
  Future<PassphraseWalletDerivation> derive({
    required MnemonicSeed parentSeed,
    required String passphrase,
    required Network network,
  });
}
