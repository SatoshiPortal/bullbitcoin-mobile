import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/uint_8_list_x.dart';
import 'package:bb_mobile/core/wallet/data/models/bitcoin_policy_maturity_model.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_descriptor_key_model.dart';

bool walletDescriptorKeyMatches({
  required WalletDescriptorKeyModel key,
  required String publicKey,
  required String? fingerprint,
  required String? derivationPath,
  required BitcoinPolicyKeychainModel? keychain,
  bool isXOnly = false,
}) {
  final normalizedPublicKey = publicKey.toLowerCase();
  if (key.xpub.toLowerCase() == normalizedPublicKey) {
    return key.descriptorPath.isEmpty;
  }
  if (key.xpub.isEmpty) return false;

  final normalizedFingerprint = fingerprint?.toLowerCase();
  final masterFingerprint = key.masterFingerprint.toLowerCase();
  final xpubFingerprint = key.xpubFingerprint.toLowerCase();
  if (masterFingerprint.isNotEmpty &&
      normalizedFingerprint != masterFingerprint) {
    return false;
  }
  if (masterFingerprint.isEmpty &&
      xpubFingerprint.isNotEmpty &&
      normalizedFingerprint != xpubFingerprint) {
    return false;
  }

  final sourcePath = _pathParts(derivationPath);
  final accountPath = _pathParts(key.derivationPath);
  if (accountPath.isNotEmpty && !_startsWith(sourcePath, accountPath)) {
    return false;
  }
  final suffix = accountPath.isEmpty
      ? sourcePath
      : sourcePath.sublist(accountPath.length);
  if (suffix.any(_isHardened) ||
      !_matchesDescriptorPath(suffix, key.descriptorPath, keychain: keychain)) {
    return false;
  }

  try {
    var derived = Bip32Derivation.getBip32Xpub(key.xpub);
    if (suffix.isNotEmpty) derived = derived.derivePath(suffix.join('/'));
    final derivedPublicKey = derived.public.toHexString().toLowerCase();
    return isXOnly
        ? derivedPublicKey.substring(2) == normalizedPublicKey
        : derivedPublicKey == normalizedPublicKey;
  } on Exception {
    return false;
  }
}

bool _matchesDescriptorPath(
  List<String> actual,
  String descriptorPath, {
  required BitcoinPolicyKeychainModel? keychain,
}) {
  if (descriptorPath.isEmpty) return true;
  final expected = _pathParts(descriptorPath);
  if (actual.length != expected.length) return false;
  for (var index = 0; index < expected.length; index++) {
    final component = expected[index];
    if (component == '*') continue;
    final branches = RegExp(r'^<(\d+);(\d+)>$').firstMatch(component);
    if (branches != null) {
      final branch = switch (keychain) {
        BitcoinPolicyKeychainModel.external => branches[1],
        BitcoinPolicyKeychainModel.internal => branches[2],
        null => null,
      };
      if (actual[index] != branch) return false;
      continue;
    }
    if (actual[index] != component) return false;
  }
  return true;
}

List<String> _pathParts(String? path) {
  if (path == null || path.isEmpty || path == 'm') return const [];
  return path
      .replaceAllMapped(RegExp(r'(\d+)[hH]'), (match) => "${match[1]}'")
      .split('/')
      .where((part) => part.isNotEmpty && part != 'm')
      .toList();
}

bool _startsWith(List<String> path, List<String> prefix) {
  if (path.length < prefix.length) return false;
  for (var index = 0; index < prefix.length; index++) {
    if (path[index] != prefix[index]) return false;
  }
  return true;
}

bool _isHardened(String component) => component.endsWith("'");
