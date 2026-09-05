import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_policy_registration_name.dart';
import 'package:ledger_bitcoin/ledger_bitcoin.dart';

abstract final class LedgerWalletPolicyAdapter {
  static String? minimumBitcoinAppVersion(
    Wallet wallet, {
    required bool hasUnspendablePolicyKey,
  }) {
    if (!wallet.publicDescriptor.toLowerCase().startsWith('tr(')) return null;
    return hasUnspendablePolicyKey ? '2.2.2' : '2.2.1';
  }

  static WalletPolicy fromWallet(
    Wallet wallet, {
    required List<WalletDescriptorKey> descriptorPolicyKeys,
    String? registrationName,
  }) {
    if (!wallet.supportsLedgerWalletPolicy) {
      throw const FormatException('Unsupported Ledger wallet policy');
    }

    var template = wallet.publicDescriptor.split('#').first;
    final policyKeys = <String>[];
    final policyKeyIndexes = <String, int>{};
    final policyKeyBranches = <int, Set<int>>{};
    for (final atom in _descriptorAtoms(template)) {
      final key = _LedgerPolicyKey.tryParse(atom, wallet: wallet);
      if (key == null) continue;
      if (!descriptorPolicyKeys.any(key.matchesDescriptorKey)) {
        throw const FormatException('Descriptor key is missing from policy');
      }
      var index = policyKeyIndexes[key.keyInfo];
      if (index == null) {
        index = policyKeys.length;
        policyKeyIndexes[key.keyInfo] = index;
        policyKeys.add(key.keyInfo);
      }
      final usedBranches = policyKeyBranches.putIfAbsent(index, () => {});
      if (usedBranches.contains(key.externalBranch) ||
          usedBranches.contains(key.internalBranch)) {
        throw const FormatException(
          'Overlapping Ledger wallet policy key role',
        );
      }
      usedBranches.addAll([key.externalBranch, key.internalBranch]);
      template = template.replaceAll(
        key.expression,
        '@$index${key.derivationTemplate}',
      );
    }
    if (policyKeys.isEmpty ||
        template.contains('xpub') ||
        template.contains('tpub')) {
      throw const FormatException('Unmapped descriptor key in policy');
    }

    return WalletPolicy(
      _walletName(wallet, registrationName: registrationName),
      template,
      policyKeys,
    );
  }

  static Iterable<String> _descriptorAtoms(String descriptor) sync* {
    var start = 0;
    for (var index = 0; index < descriptor.length; index++) {
      if (!'(),{}'.contains(descriptor[index])) continue;
      final atom = descriptor.substring(start, index).trim();
      if (atom.isNotEmpty) yield atom;
      start = index + 1;
    }
    final atom = descriptor.substring(start).trim();
    if (atom.isNotEmpty) yield atom;
  }

  static String _walletName(Wallet wallet, {String? registrationName}) {
    if (registrationName != null) {
      return WalletPolicyRegistrationName.validate(
        registrationName,
        wallet.signers
            .map((signer) => signer.signerDevice)
            .whereType<SignerDeviceEntity>()
            .firstWhere((device) => device.isLedger),
      );
    }
    final source = wallet.label?.trim() ?? '';
    final ascii = source.codeUnits
        .where((unit) => unit >= 0x20 && unit <= 0x7e)
        .map(String.fromCharCode)
        .join()
        .trim();
    if (ascii.isEmpty) {
      final id = wallet.id.length <= 8 ? wallet.id : wallet.id.substring(0, 8);
      return 'Bull $id';
    }
    return ascii.length <= 64 ? ascii : ascii.substring(0, 64).trimRight();
  }
}

final class _LedgerPolicyKey {
  static final _pattern = RegExp(
    r"^(?:\[([0-9a-fA-F]{8})((?:/[0-9]+(?:'|h)?)*)\])?"
    r'((?:xpub|tpub)[1-9A-HJ-NP-Za-km-z]+)'
    r'((?:/[0-9]+)*)/<([0-9]+);([0-9]+)>/\*$',
  );

  final String expression;
  final String masterFingerprint;
  final String? derivationPath;
  final String xpub;
  final String keyInfo;
  final String derivationTemplate;
  final int externalBranch;
  final int internalBranch;

  const _LedgerPolicyKey({
    required this.expression,
    required this.masterFingerprint,
    required this.derivationPath,
    required this.xpub,
    required this.keyInfo,
    required this.derivationTemplate,
    required this.externalBranch,
    required this.internalBranch,
  });

  static _LedgerPolicyKey? tryParse(
    String expression, {
    required Wallet wallet,
  }) {
    final match = _pattern.firstMatch(expression);
    if (match == null) return null;

    final fingerprint = match.group(1)?.toLowerCase() ?? '';
    final originPath = match.group(2) ?? '';
    final xpub = match.group(3)!;
    final suffix = match.group(4) ?? '';
    final externalBranch = int.tryParse(match.group(5)!);
    final internalBranch = int.tryParse(match.group(6)!);
    if (externalBranch == null ||
        internalBranch == null ||
        externalBranch == internalBranch ||
        externalBranch >= 0x80000000 ||
        internalBranch >= 0x80000000) {
      return null;
    }
    final derivedXpub = suffix.isEmpty
        ? xpub
        : Bip32Derivation.getBip32Xpub(xpub)
              .derivePath(suffix.substring(1))
              .convert(wallet.isTestnet ? XpubType.tpub : XpubType.xpub);
    final ledgerOriginPath = originPath.replaceAll('h', "'");
    final origin = fingerprint.isEmpty
        ? ''
        : '[$fingerprint$ledgerOriginPath$suffix]';

    return _LedgerPolicyKey(
      expression: expression,
      masterFingerprint: fingerprint,
      derivationPath: originPath.isEmpty ? null : 'm$originPath',
      xpub: xpub,
      keyInfo: '$origin$derivedXpub',
      derivationTemplate: externalBranch == 0 && internalBranch == 1
          ? '/**'
          : '/<$externalBranch;$internalBranch>/*',
      externalBranch: externalBranch,
      internalBranch: internalBranch,
    );
  }

  bool matchesDescriptorKey(WalletDescriptorKey key) =>
      key.masterFingerprint.toLowerCase() == masterFingerprint &&
      _normalizePath(key.derivationPath) == _normalizePath(derivationPath) &&
      key.xpub == xpub;

  static String? _normalizePath(String? path) => path?.replaceAll("'", 'h');
}
