import 'package:convert/convert.dart';

import '../../domain/bitcoin_policy_descriptor.dart';
import '../../domain/wallet_values.dart';
import 'public_account_key.dart';

bool walletDescriptorKeyMatches({
  required BitcoinDescriptorKey key,
  required String publicKey,
  required String? fingerprint,
  required String? derivationPath,
  required Keychain? keychain,
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
  final hasMasterOrigin =
      masterFingerprint.isNotEmpty &&
      normalizedFingerprint == masterFingerprint;
  final hasAccountOrigin =
      xpubFingerprint.isNotEmpty && normalizedFingerprint == xpubFingerprint;
  if (!hasMasterOrigin &&
      !hasAccountOrigin &&
      (masterFingerprint.isNotEmpty || xpubFingerprint.isNotEmpty)) {
    return false;
  }

  final sourcePath = _pathParts(derivationPath);
  final accountPath = hasAccountOrigin && !hasMasterOrigin
      ? const <String>[]
      : _pathParts(key.derivationPath);
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
    var derived = publicAccountKey(key.xpub);
    if (suffix.isNotEmpty) derived = derived.derivePath(suffix.join('/'));
    final derivedPublicKey = hex.encode(derived.public).toLowerCase();
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
  required Keychain? keychain,
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
        Keychain.external => branches[1],
        Keychain.internal => branches[2],
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
