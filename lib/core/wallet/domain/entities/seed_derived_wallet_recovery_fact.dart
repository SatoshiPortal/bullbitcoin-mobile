import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:primitives/primitives.dart' show Fingerprint;

final class SeedDerivedWalletRecoveryFact {
  final String walletId;
  final Fingerprint seedFingerprint;
  final Network network;
  final ScriptType scriptType;
  final WalletProvenance provenance;
  final String derivationPath;
  final bool? seedPassphraseUsed;

  const SeedDerivedWalletRecoveryFact({
    required this.walletId,
    required this.seedFingerprint,
    required this.network,
    required this.scriptType,
    required this.provenance,
    required this.derivationPath,
    required this.seedPassphraseUsed,
  });
}
