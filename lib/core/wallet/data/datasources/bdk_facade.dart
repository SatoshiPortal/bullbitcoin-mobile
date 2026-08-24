import 'dart:io';

import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/data/models/wallet_model.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_error.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:convert/convert.dart';
import 'package:path_provider/path_provider.dart';

const _bip341NumsKey =
    '0250929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0';

final class BdkDescriptorKey {
  final String masterFingerprint;
  final String xpubFingerprint;
  final String xpub;
  final String? derivationPath;
  final String descriptorPath;

  const BdkDescriptorKey({
    required this.masterFingerprint,
    required this.xpubFingerprint,
    required this.xpub,
    required this.derivationPath,
    this.descriptorPath = '',
  });
}

final class BdkTwoPathDescriptor {
  final String descriptor;
  final String externalDescriptor;
  final String internalDescriptor;
  final String scriptIdentity;
  final ScriptType? scriptType;
  final List<BdkDescriptorKey> keys;
  final List<BdkDescriptorKey> policyKeys;
  final Set<String> unspendablePolicyKeyIdentifiers;
  final bool inferredChangePath;

  const BdkTwoPathDescriptor({
    required this.descriptor,
    required this.externalDescriptor,
    required this.internalDescriptor,
    required this.scriptIdentity,
    required this.scriptType,
    this.keys = const [],
    this.policyKeys = const [],
    this.unspendablePolicyKeyIdentifiers = const {},
    this.inferredChangePath = false,
  });
}

class BdkFacade {
  // Standard lookahead value for address discovery
  static const int _lookahead = 25;

  static Future<bdk.Wallet> createWallet(WalletModel walletModel) {
    if (walletModel is PublicBdkWalletModel) {
      return createPublicWallet(walletModel);
    } else if (walletModel is PrivateBdkWalletModel) {
      return createPrivateWallet(walletModel);
    } else {
      throw ArgumentError('Unsupported wallet model type');
    }
  }

  static Future<bdk.Wallet> createPublicWallet(WalletModel walletModel) async {
    if (walletModel is! PublicBdkWalletModel) {
      throw ArgumentError('Wallet must be of type PublicBdkWalletModel');
    }

    final network = walletModel.isTestnet
        ? bdk.Network.testnet
        : bdk.Network.bitcoin;
    final networkKind = walletModel.isTestnet
        ? bdk.NetworkKind.test
        : bdk.NetworkKind.main;

    final parsed = parsePublicTwoPathDescriptor(
      descriptor: walletModel.descriptor,
      isTestnet: walletModel.isTestnet,
    );
    final external = bdk.Descriptor(
      descriptor: parsed.externalDescriptor,
      networkKind: networkKind,
    );
    final internal = bdk.Descriptor(
      descriptor: parsed.internalDescriptor,
      networkKind: networkKind,
    );

    // Get the database path based on the wallet's id for uniqueness and in hex
    // to ensure it's a valid filename
    final dbPath = await _getDbPath(walletModel.hexId);
    final dbFile = File(dbPath);

    try {
      final dbPersister = bdk.Persister.newSqlite(path: dbPath);

      // Use load if database (wallet) exists, otherwise create new
      final wallet = await dbFile.exists()
          ? bdk.Wallet.load(
              descriptor: external,
              changeDescriptor: internal,
              persister: dbPersister,
              lookahead: _lookahead,
            )
          : bdk.Wallet(
              descriptor: external,
              changeDescriptor: internal,
              network: network,
              persister: dbPersister,
              lookahead: _lookahead,
            );

      return wallet;
    } catch (e) {
      // If there's any error (corrupted db, etc.), delete and recreate
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      final dbPersister = bdk.Persister.newSqlite(path: dbPath);
      return bdk.Wallet(
        descriptor: external,
        changeDescriptor: internal,
        network: network,
        persister: dbPersister,
        lookahead: _lookahead,
      );
    }
  }

  static Future<bdk.Wallet> createPrivateWallet(WalletModel walletModel) async {
    if (walletModel is! PrivateBdkWalletModel) {
      throw ArgumentError('Wallet must be of type PrivateBdkWalletModel');
    }

    final network = walletModel.isTestnet
        ? bdk.Network.testnet
        : bdk.Network.bitcoin;
    final networkKind = walletModel.isTestnet
        ? bdk.NetworkKind.test
        : bdk.NetworkKind.main;

    final bdkMnemonic = bdk.Mnemonic.fromString(mnemonic: walletModel.mnemonic);
    final secretKey = bdk.DescriptorSecretKey(
      networkKind: networkKind,
      mnemonic: bdkMnemonic,
      password: walletModel.passphrase,
    );

    late final bdk.Descriptor external;
    late final bdk.Descriptor internal;

    if (walletModel.account == 0) {
      switch (walletModel.scriptType) {
        case ScriptType.bip84:
          external = bdk.Descriptor.newBip84(
            secretKey: secretKey,
            keychainKind: bdk.KeychainKind.external_,
            networkKind: networkKind,
          );
          internal = bdk.Descriptor.newBip84(
            secretKey: secretKey,
            keychainKind: bdk.KeychainKind.internal,
            networkKind: networkKind,
          );
        case ScriptType.bip49:
          external = bdk.Descriptor.newBip49(
            secretKey: secretKey,
            keychainKind: bdk.KeychainKind.external_,
            networkKind: networkKind,
          );
          internal = bdk.Descriptor.newBip49(
            secretKey: secretKey,
            keychainKind: bdk.KeychainKind.internal,
            networkKind: networkKind,
          );
        case ScriptType.bip44:
          external = bdk.Descriptor.newBip44(
            secretKey: secretKey,
            keychainKind: bdk.KeychainKind.external_,
            networkKind: networkKind,
          );
          internal = bdk.Descriptor.newBip44(
            secretKey: secretKey,
            keychainKind: bdk.KeychainKind.internal,
            networkKind: networkKind,
          );
      }
    } else {
      final path = bdk.DerivationPath(
        path:
            "m/${walletModel.scriptType.purpose}'/"
            "${walletModel.isTestnet ? 1 : 0}'/${walletModel.account}'",
      );
      final accountKey = secretKey.derive(path: path);
      try {
        external = bdk.Descriptor(
          descriptor: _singleSignatureDescriptor(
            walletModel.scriptType,
            '$accountKey/0/*',
          ),
          networkKind: networkKind,
        );
        internal = bdk.Descriptor(
          descriptor: _singleSignatureDescriptor(
            walletModel.scriptType,
            '$accountKey/1/*',
          ),
          networkKind: networkKind,
        );
      } finally {
        accountKey.dispose();
        path.dispose();
      }
    }

    // Get the database path
    final dbPath = await _getDbPath(walletModel.hexId);
    final dbFile = File(dbPath);

    try {
      final dbPersister = bdk.Persister.newSqlite(path: dbPath);

      // Use load if database exists, otherwise create new
      final wallet = await dbFile.exists()
          ? bdk.Wallet.load(
              descriptor: external,
              changeDescriptor: internal,
              persister: dbPersister,
              lookahead: _lookahead,
            )
          : bdk.Wallet(
              descriptor: external,
              changeDescriptor: internal,
              network: network,
              persister: dbPersister,
              lookahead: _lookahead,
            );

      return wallet;
    } catch (e) {
      // If there's any error (corrupted db, etc.), delete and recreate
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      final dbPersister = bdk.Persister.newSqlite(path: dbPath);
      return bdk.Wallet(
        descriptor: external,
        changeDescriptor: internal,
        network: network,
        persister: dbPersister,
        lookahead: _lookahead,
      );
    }
  }

  static String _singleSignatureDescriptor(ScriptType scriptType, String key) =>
      switch (scriptType) {
        ScriptType.bip44 => 'pkh($key)',
        ScriptType.bip49 => 'sh(wpkh($key))',
        ScriptType.bip84 => 'wpkh($key)',
      };

  /// Creates an in-memory wallet from arbitrary Bitcoin descriptors.
  ///
  /// Callers must never persist or log descriptors containing private keys.
  static bdk.Wallet createEphemeralDescriptorWallet({
    required String descriptor,
    required bool isTestnet,
  }) {
    final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;
    final networkKind = isTestnet ? bdk.NetworkKind.test : bdk.NetworkKind.main;
    final descriptors = _expandTwoPathDescriptor(
      descriptor: descriptor,
      networkKind: networkKind,
    );
    final external = bdk.Descriptor(
      descriptor: descriptors.external,
      networkKind: networkKind,
    );
    try {
      external.sanityCheck();
      final internal = bdk.Descriptor(
        descriptor: descriptors.internal,
        networkKind: networkKind,
      );
      try {
        internal.sanityCheck();
        final persister = bdk.Persister.newInMemory();
        try {
          return bdk.Wallet(
            descriptor: external,
            changeDescriptor: internal,
            network: network,
            persister: persister,
            lookahead: _lookahead,
          );
        } finally {
          persister.dispose();
        }
      } finally {
        internal.dispose();
      }
    } finally {
      external.dispose();
    }
  }

  static BdkTwoPathDescriptor parsePublicTwoPathDescriptor({
    required String descriptor,
    required bool isTestnet,
  }) {
    final network = isTestnet ? bdk.Network.testnet : bdk.Network.bitcoin;
    final networkKind = isTestnet ? bdk.NetworkKind.test : bdk.NetworkKind.main;
    final supplied = bdk.Descriptor(
      descriptor: descriptor.trim(),
      networkKind: networkKind,
    );
    try {
      supplied.sanityCheck();
    } finally {
      supplied.dispose();
    }
    final normalized = _normalizeTwoPathDescriptor(descriptor);
    final parsed = bdk.Descriptor(
      descriptor: normalized.descriptor,
      networkKind: networkKind,
    );
    try {
      parsed.sanityCheck();

      if (!parsed.isMultipath()) {
        throw const FormatException(
          'Descriptor must define receiving and change paths',
        );
      }
      if (!parsed.hasWildcard()) {
        throw const FormatException('Descriptor must be ranged');
      }
      if (parsed.toStringWithSecret() != parsed.toString()) {
        throw const FormatException('Private descriptors cannot be imported');
      }

      final singleDescriptors = parsed.toSingleDescriptors();
      try {
        if (singleDescriptors.length != 2) {
          throw const FormatException(
            'Descriptor must define exactly two wallet paths',
          );
        }

        final persister = bdk.Persister.newInMemory();
        bdk.Wallet? wallet;
        try {
          wallet = bdk.Wallet.createFromTwoPathDescriptor(
            twoPathDescriptor: parsed,
            network: network,
            persister: persister,
            lookahead: _lookahead,
          );
        } finally {
          wallet?.dispose();
          persister.dispose();
        }

        final externalDescriptor = singleDescriptors.first.toString();
        final keyAnalysis = _descriptorKeys(
          parsed.toString(),
          descriptorType: parsed.descType(),
        );
        return BdkTwoPathDescriptor(
          descriptor: parsed.toString(),
          externalDescriptor: externalDescriptor,
          internalDescriptor: singleDescriptors.last.toString(),
          scriptIdentity: _scriptIdentity(singleDescriptors),
          scriptType: switch (parsed.descType()) {
            bdk.DescriptorType.wpkh => ScriptType.bip84,
            bdk.DescriptorType.shWpkh => ScriptType.bip49,
            bdk.DescriptorType.pkh => ScriptType.bip44,
            _ => null,
          },
          keys: keyAnalysis.signingKeys,
          policyKeys: keyAnalysis.policyKeys,
          unspendablePolicyKeyIdentifiers:
              keyAnalysis.unspendablePolicyKeyIdentifiers,
          inferredChangePath: normalized.inferredChangePath,
        );
      } finally {
        for (final descriptor in singleDescriptors) {
          descriptor.dispose();
        }
      }
    } finally {
      parsed.dispose();
    }
  }

  static String _scriptIdentity(List<bdk.Descriptor> descriptors) {
    final identities = <String>[];
    for (final descriptor in descriptors) {
      final id = descriptor.descriptorId();
      try {
        identities.add(id.toString());
      } finally {
        id.dispose();
      }
    }
    identities.sort();
    return identities.join(':');
  }

  static String descriptorForPolicyAnalysis(String descriptor) =>
      descriptor.split('#').first.replaceAllMapped(
        RegExp(
          r'\[([0-9a-fA-F]{8})([^\]]*)\]'
          r'((?:xpub|tpub)[1-9A-HJ-NP-Za-km-z]+)',
        ),
        (match) {
          final xpub = match.group(3)!;
          final fingerprint = Bip32Derivation.getBip32Xpub(xpub).fingerprintHex;
          return '[$fingerprint${match.group(2)!}]$xpub';
        },
      );

  static ({
    List<BdkDescriptorKey> signingKeys,
    List<BdkDescriptorKey> policyKeys,
    Set<String> unspendablePolicyKeyIdentifiers,
  })
  _descriptorKeys(
    String descriptor, {
    required bdk.DescriptorType descriptorType,
  }) {
    final parsedKeys = <({BdkDescriptorKey key, String expression})>[];
    final taproot = descriptorType == bdk.DescriptorType.tr
        ? _taprootInternalKey(descriptor)
        : null;
    final unspendableIdentifiers = <String>{};
    var parsedFixedNumsInternalKey = false;

    for (final atom in _descriptorAtoms(descriptor)) {
      if (const {
        'sha256',
        'hash256',
        'ripemd160',
        'hash160',
      }.contains(atom.parent?.split(':').last)) {
        continue;
      }
      final candidate = atom.value;
      final bdk.DescriptorPublicKey descriptorKey;
      try {
        descriptorKey = bdk.DescriptorPublicKey.fromString(
          publicKey: candidate,
        );
      } on Exception {
        continue;
      }

      final String normalizedDescriptorKey;
      try {
        normalizedDescriptorKey = descriptorKey.toString();
      } finally {
        descriptorKey.dispose();
      }
      final originEnd = normalizedDescriptorKey.startsWith('[')
          ? normalizedDescriptorKey.indexOf(']')
          : -1;
      if (normalizedDescriptorKey.startsWith('[') && originEnd < 0) continue;
      final keyStart = originEnd + 1;
      final keyEnd = normalizedDescriptorKey.indexOf('/', keyStart);
      final xpub = normalizedDescriptorKey.substring(
        keyStart,
        keyEnd < 0 ? normalizedDescriptorKey.length : keyEnd,
      );
      final descriptorPath = keyEnd < 0
          ? ''
          : normalizedDescriptorKey.substring(keyEnd);

      if (!xpub.startsWith('xpub') && !xpub.startsWith('tpub')) {
        final isBip341NumsInternalKey =
            descriptorType == bdk.DescriptorType.tr &&
            !parsedFixedNumsInternalKey &&
            {
              _bip341NumsKey,
              _bip341NumsKey.substring(2),
            }.contains(xpub.toLowerCase()) &&
            candidate == taproot?.expression;
        if (isBip341NumsInternalKey) {
          parsedFixedNumsInternalKey = true;
          unspendableIdentifiers
            ..add(_bip341NumsKey)
            ..add(_bip341NumsKey.substring(2));
          continue;
        }
        throw const UnsupportedFixedPublicKeyDescriptorException();
      }
      final xpubFingerprint = Bip32Derivation.getBip32Xpub(xpub).fingerprintHex;

      var masterFingerprint = '';
      String? derivationPath;
      if (originEnd > 0) {
        final origin = normalizedDescriptorKey
            .substring(1, originEnd)
            .split('/');
        masterFingerprint = origin.first.toLowerCase();
        if (origin.length > 1) {
          derivationPath = 'm/${origin.skip(1).join('/')}';
        }
      }

      parsedKeys.add((
        expression: candidate,
        key: BdkDescriptorKey(
          masterFingerprint: masterFingerprint,
          xpubFingerprint: xpubFingerprint,
          xpub: xpub,
          derivationPath: derivationPath,
          descriptorPath: descriptorPath,
        ),
      ));
    }

    final unspendableInternalKey = _unspendableTaprootInternalKey(
      parsedKeys,
      taprootInternalKey: taproot?.expression,
    );
    if (unspendableInternalKey != null) {
      _validateUnspendableInternalKey(parsedKeys, unspendableInternalKey);
      unspendableIdentifiers.addAll({
        unspendableInternalKey.masterFingerprint.toLowerCase(),
        unspendableInternalKey.xpubFingerprint.toLowerCase(),
        unspendableInternalKey.xpub.toLowerCase(),
      });
    }
    if ((parsedFixedNumsInternalKey || unspendableInternalKey != null) &&
        taproot?.hasScriptTree != true) {
      throw const FormatException(
        'Unspendable Taproot internal keys require a script tree',
      );
    }

    List<BdkDescriptorKey> uniqueKeys({required bool includeUnspendable}) {
      final seen = <String>{};
      return List.unmodifiable([
        for (final parsed in parsedKeys)
          if ((includeUnspendable ||
                  !identical(parsed.key, unspendableInternalKey)) &&
              seen.add(
                '${parsed.key.masterFingerprint}:${parsed.key.derivationPath}:'
                '${parsed.key.xpub}:${parsed.key.descriptorPath}',
              ))
            parsed.key,
      ]);
    }

    return (
      signingKeys: uniqueKeys(includeUnspendable: false),
      policyKeys: uniqueKeys(includeUnspendable: true),
      unspendablePolicyKeyIdentifiers: Set.unmodifiable(
        unspendableIdentifiers.where((identifier) => identifier.isNotEmpty),
      ),
    );
  }

  static void _validateUnspendableInternalKey(
    List<({BdkDescriptorKey key, String expression})> parsedKeys,
    BdkDescriptorKey unspendableInternalKey,
  ) {
    final fingerprints = {
      unspendableInternalKey.masterFingerprint.toLowerCase(),
      unspendableInternalKey.xpubFingerprint.toLowerCase(),
    }..remove('');
    for (final parsed in parsedKeys) {
      final key = parsed.key;
      if (identical(key, unspendableInternalKey)) continue;
      if (key.xpub == unspendableInternalKey.xpub) {
        throw const FormatException(
          'Unspendable Taproot internal keys cannot be used in scripts',
        );
      }
      if (fingerprints.contains(key.masterFingerprint.toLowerCase()) ||
          fingerprints.contains(key.xpubFingerprint.toLowerCase())) {
        throw const FormatException(
          'Unspendable Taproot internal key fingerprint is ambiguous',
        );
      }
    }
  }

  static BdkDescriptorKey? _unspendableTaprootInternalKey(
    List<({BdkDescriptorKey key, String expression})> parsedKeys, {
    required String? taprootInternalKey,
  }) {
    if (taprootInternalKey == null) return null;
    final internalIndex = parsedKeys.indexWhere(
      (parsed) => parsed.expression == taprootInternalKey,
    );
    if (internalIndex < 0) return null;
    final internal = parsedKeys[internalIndex];

    final internalXpub = Bip32Derivation.getBip32Xpub(internal.key.xpub);
    return hex.encode(internalXpub.public).toLowerCase() == _bip341NumsKey
        ? internal.key
        : null;
  }

  static ({String expression, bool hasScriptTree})? _taprootInternalKey(
    String descriptor,
  ) {
    final withoutChecksum = descriptor.split('#').first.trim();
    final match = RegExp(r'^tr\s*\(').firstMatch(withoutChecksum);
    if (match == null) return null;
    final start = match.end;
    var nested = 0;
    for (var index = start; index < withoutChecksum.length; index++) {
      final character = withoutChecksum[index];
      if (character == '(' || character == '{') nested++;
      if (character == ')' || character == '}') {
        if (nested == 0) {
          return (
            expression: withoutChecksum.substring(start, index).trim(),
            hasScriptTree: false,
          );
        }
        nested--;
      }
      if (character == ',' && nested == 0) {
        return (
          expression: withoutChecksum.substring(start, index).trim(),
          hasScriptTree: true,
        );
      }
    }
    return null;
  }

  static Iterable<({String value, String? parent})> _descriptorAtoms(
    String descriptor,
  ) sync* {
    final withoutChecksum = descriptor.split('#').first;
    var start = 0;
    final parents = <String?>[];
    for (var index = 0; index < withoutChecksum.length; index++) {
      final delimiter = withoutChecksum[index];
      if (!'(),{}'.contains(delimiter)) continue;
      final atom = withoutChecksum.substring(start, index).trim();
      if (atom.isNotEmpty) {
        yield (value: atom, parent: parents.lastOrNull);
      }
      if (delimiter == '(') {
        parents.add(atom.isEmpty ? null : atom);
      } else if (delimiter == '{') {
        parents.add(null);
      } else if ((delimiter == ')' || delimiter == '}') && parents.isNotEmpty) {
        parents.removeLast();
      }
      start = index + 1;
    }
    final atom = withoutChecksum.substring(start).trim();
    if (atom.isNotEmpty) {
      yield (value: atom, parent: parents.lastOrNull);
    }
  }

  static ({String descriptor, bool inferredChangePath})
  _normalizeTwoPathDescriptor(String descriptor) {
    final withoutChecksum = descriptor.trim().split('#').first;
    if (withoutChecksum.contains('<')) {
      return (descriptor: withoutChecksum, inferredChangePath: false);
    }

    final wildcards = RegExp(r'/\*').allMatches(withoutChecksum).toList();
    final usesConventionalExternalPath =
        wildcards.isNotEmpty &&
        wildcards.every(
          (match) =>
              match.start >= 2 &&
              withoutChecksum.substring(match.start - 2, match.start) == '/0',
        );
    if (!usesConventionalExternalPath) {
      return (descriptor: withoutChecksum, inferredChangePath: false);
    }

    return (
      descriptor: withoutChecksum.replaceAll('/0/*', '/<0;1>/*'),
      inferredChangePath: true,
    );
  }

  static String combinePublicDescriptorPair({
    required String externalDescriptor,
    required String internalDescriptor,
    required bool isTestnet,
  }) {
    final parsed = parsePublicTwoPathDescriptor(
      descriptor: externalDescriptor,
      isTestnet: isTestnet,
    );
    final networkKind = isTestnet ? bdk.NetworkKind.test : bdk.NetworkKind.main;
    final normalizedInternalDescriptor = _normalizePublicSingleDescriptor(
      descriptor: internalDescriptor,
      networkKind: networkKind,
    );
    if (!parsed.inferredChangePath ||
        parsed.internalDescriptor != normalizedInternalDescriptor) {
      throw const FormatException(
        'Wallet descriptors do not form receive and change paths',
      );
    }
    return parsed.descriptor;
  }

  static ({String external, String internal}) _expandTwoPathDescriptor({
    required String descriptor,
    required bdk.NetworkKind networkKind,
  }) {
    final withoutChecksum = descriptor.split('#').first;
    if (withoutChecksum.contains('xprv') || withoutChecksum.contains('tprv')) {
      return _expandPrivateTwoPathDescriptor(
        descriptor: withoutChecksum,
        networkKind: networkKind,
      );
    }
    final multipath = bdk.Descriptor(
      descriptor: withoutChecksum,
      networkKind: networkKind,
    );
    try {
      multipath.sanityCheck();
      if (!multipath.isMultipath()) {
        throw const FormatException(
          'Descriptor must define receiving and change paths',
        );
      }
      final descriptors = multipath.toSingleDescriptors();
      try {
        if (descriptors.length != 2) {
          throw const FormatException(
            'Descriptor must define exactly two wallet paths',
          );
        }
        return (
          external: descriptors.first.toStringWithSecret(),
          internal: descriptors.last.toStringWithSecret(),
        );
      } finally {
        for (final descriptor in descriptors) {
          descriptor.dispose();
        }
      }
    } finally {
      multipath.dispose();
    }
  }

  static ({String external, String internal}) _expandPrivateTwoPathDescriptor({
    required String descriptor,
    required bdk.NetworkKind networkKind,
  }) {
    final multipath = RegExp(r'<([0-9]+);([0-9]+)>');
    if (!multipath.hasMatch(descriptor)) {
      throw const FormatException(
        'Descriptor must define receiving and change paths',
      );
    }

    String expand(int branch) =>
        descriptor.replaceAllMapped(multipath, (match) => match.group(branch)!);

    final external = bdk.Descriptor(
      descriptor: expand(1),
      networkKind: networkKind,
    );
    try {
      external.sanityCheck();
      final internal = bdk.Descriptor(
        descriptor: expand(2),
        networkKind: networkKind,
      );
      try {
        internal.sanityCheck();
        return (
          external: external.toStringWithSecret(),
          internal: internal.toStringWithSecret(),
        );
      } finally {
        internal.dispose();
      }
    } finally {
      external.dispose();
    }
  }

  static String _normalizePublicSingleDescriptor({
    required String descriptor,
    required bdk.NetworkKind networkKind,
  }) {
    final parsed = bdk.Descriptor(
      descriptor: descriptor.trim(),
      networkKind: networkKind,
    );
    try {
      parsed.sanityCheck();
      if (parsed.isMultipath() ||
          parsed.toStringWithSecret() != parsed.toString()) {
        throw const FormatException('Expected one public descriptor path');
      }
      return parsed.toString();
    } finally {
      parsed.dispose();
    }
  }

  /// Persists wallet changes to the database
  static Future<void> saveWallet(
    bdk.Wallet bdkWallet,
    String walletIdHex,
  ) async {
    final dbPath = await _getDbPath(walletIdHex);
    final persister = bdk.Persister.newSqlite(path: dbPath);
    bdkWallet.persist(persister: persister);
  }

  static Future<String> _getDbPath(String walletIdHex) async {
    final dir = await getApplicationDocumentsDirectory();
    // Add since bdk_dart might not migrate old bdk_flutter db we suffix the db name with `_bdk_dart` to avoid conflicts
    return '${dir.path}/${'${walletIdHex}_bdk_dart'}';
  }

  static Future<void> delete(WalletModel walletModel) async {
    final dbPath = await _getDbPath(walletModel.hexId);
    final dbFile = File(dbPath);

    if (!await dbFile.exists()) throw WalletError.notFound(walletModel.id);

    await dbFile.delete();
  }
}
