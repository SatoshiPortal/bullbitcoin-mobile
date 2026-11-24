import 'package:primitives/primitives.dart';

import '../domain/wallet_registration.dart';

const _networks = <String, Network>{
  'bitcoinMainnet': BitcoinNetwork.mainnet,
  'bitcoinTestnet': BitcoinNetwork.testnet,
  'bitcoinRegtest': BitcoinNetwork.regtest,
  'liquidMainnet': LiquidNetwork.mainnet,
  'liquidTestnet': LiquidNetwork.testnet,
  'liquidRegtest': LiquidNetwork.regtest,
};

String? storedWalletNetwork(Network network) {
  for (final entry in _networks.entries) {
    if (entry.value == network) return entry.key;
  }
  return null;
}

final _originPattern = RegExp(r'\[[a-fA-F0-9]+/(\d+h)/\d+h/\d+h\]');
final _descriptorKeyOrigin = RegExp(r"\[[a-fA-F0-9]{8}((?:/\d+[hH']?)+)\]");
final _privateKeyPattern = RegExp(
  r'\b[xtyuzvYUZV]prv|\b[5KLc9][1-9A-HJ-NP-Za-km-z]{50,51}\b',
);

/// Decode untrusted SQLite values without throwing or exporting a descriptor.
WalletRegistration? decodeWalletRegistration(Map<String, Object?> row) {
  if (row case {
    'id': final String id,
    'network': final String networkCode,
    'signer': final String signerCode,
    'master_fingerprint': final String master,
    'secret_fingerprint': final String? seed,
    'external_descriptor': final String external,
    'internal_descriptor': final internal,
    'label': final String? label,
    'birthday': final String? birthday,
    'is_default': final int isDefault,
  }) {
    final network = _networks[networkCode];
    final signer = switch (signerCode) {
      'local' => WalletSigner.local,
      'remote' => WalletSigner.remote,
      'none' => WalletSigner.none,
      _ => null,
    };
    final script = switch (_originPattern.firstMatch(id)?.group(1)) {
      '84h' => ScriptType.bip84,
      '49h' => ScriptType.bip49,
      '44h' => ScriptType.bip44,
      _ => null,
    };
    if (network == null || script == null || signer == null) return null;
    if (id.endsWith(':regtest') != (network.env == NetworkEnv.regtest) ||
        id.startsWith('el') != (network is LiquidNetwork)) {
      return null;
    }
    final fingerprint = seed == null ? null : Fingerprint.tryParse(seed);
    if (signer == WalletSigner.local
        ? fingerprint == null || seed != master
        : seed != null) {
      return null;
    }
    if (!_looksPublic(external) ||
        (network is LiquidNetwork
            ? !external.startsWith('ct(')
            : internal is! String || !_looksPublic(internal))) {
      return null;
    }
    final date = birthday == null ? null : DateTime.tryParse(birthday);
    if ((birthday != null && date == null) ||
        (isDefault != 0 && isDefault != 1)) {
      return null;
    }
    final path = _descriptorKeyOrigin.firstMatch(external)?.group(1);
    final masterFingerprint = Fingerprint.tryParse(master);
    return WalletRegistration(
      id: id,
      network: network,
      scriptType: script,
      signer: signer,
      masterFingerprint: masterFingerprint?.hex == master
          ? masterFingerprint
          : null,
      secretFingerprint: fingerprint,
      derivationPath: path == null ? null : 'm$path',
      label: label,
      birthday: date,
      isDefault: isDefault == 1,
    );
  }
  return null;
}

// Same structural contract as Sync's catalog, not native descriptor parsing.
bool _looksPublic(String descriptor) =>
    descriptor.contains('(') &&
    descriptor.contains(')') &&
    !_privateKeyPattern.hasMatch(descriptor);

/// Backup must not export a confidential descriptor, even for a bad row
/// whose persisted network claims to be Bitcoin.
bool isPublicBitcoinBackupDescriptor(String descriptor) =>
    _looksPublic(descriptor) &&
    !RegExp(r'\bct\s*\(', caseSensitive: false).hasMatch(descriptor);
