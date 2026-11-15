import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:primitives/primitives.dart' as primitives;
import 'package:sync/sync.dart' as sync;

class DescriptorDerivation {
  static String derivePublicBitcoinMultipathDescriptorFromXpub(
    String xpub, {
    required ScriptType scriptType,
    required bool isTestnet,
    String? masterFingerprint,
    String? derivationPath,
  }) {
    if (masterFingerprint == null && derivationPath != null) {
      throw ArgumentError('derivationPath requires a masterFingerprint');
    }

    final accountKey = Bip32Derivation.getBip32Xpub(xpub);
    final canonicalXpub = accountKey.convert(
      isTestnet ? XpubType.tpub : XpubType.xpub,
    );
    final origin = switch ((masterFingerprint, derivationPath)) {
      (null, null) => '',
      (final fingerprint?, null) => '[${fingerprint.toLowerCase()}]',
      (final fingerprint?, final path?) =>
        '[${fingerprint.toLowerCase()}/${_withoutMasterPrefix(path)}]',
      _ => throw StateError('Invalid descriptor origin'),
    };
    final descriptorKey = '$origin$canonicalXpub/<0;1>/*';
    final descriptorString = switch (scriptType) {
      ScriptType.bip84 => 'wpkh($descriptorKey)',
      ScriptType.bip49 => 'sh(wpkh($descriptorKey))',
      ScriptType.bip44 => 'pkh($descriptorKey)',
    };
    return switch (const sync.BitcoinPolicyCodec().parseDescriptor(
      descriptor: descriptorString,
      network: isTestnet
          ? primitives.BitcoinNetwork.testnet
          : primitives.BitcoinNetwork.mainnet,
    )) {
      primitives.Ok(:final value) => value.descriptor,
      primitives.Err() => throw const FormatException(
        'Invalid public descriptor',
      ),
    };
  }

  static String _withoutMasterPrefix(String derivationPath) =>
      derivationPath.startsWith('m/')
      ? derivationPath.substring(2)
      : derivationPath;
}
