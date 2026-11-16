part of 'bitcoin_policy_codec.dart';

const _bip341NumsKey =
    '0250929b74c1a04954b78b4b6035e97a5e078a5a0f28ec96d547bfee9ace803ac0';

class _DescriptorCodec {
  static const _lookahead = 25;

  /// Creates an in-memory wallet from public Bitcoin descriptors.
  static bdk.Wallet createEphemeralDescriptorWallet({
    required String descriptor,
    required BitcoinNetwork network,
  }) {
    final networkKind = network == BitcoinNetwork.mainnet
        ? bdk.NetworkKind.main
        : bdk.NetworkKind.test;
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
            network: _nativePolicyNetwork(network),
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

  static ParsedBitcoinDescriptor parsePublicTwoPathDescriptor({
    required String descriptor,
    required BitcoinNetwork network,
  }) {
    final networkKind = network == BitcoinNetwork.mainnet
        ? bdk.NetworkKind.main
        : bdk.NetworkKind.test;
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
            network: _nativePolicyNetwork(network),
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
        return ParsedBitcoinDescriptor(
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
          final fingerprint = publicAccountKey(xpub).fingerprint
              .map((b) => b.toRadixString(16).padLeft(2, '0'))
              .join();
          return '[$fingerprint${match.group(2)!}]$xpub';
        },
      );

  static ({
    List<BitcoinDescriptorKey> signingKeys,
    List<BitcoinDescriptorKey> policyKeys,
    Set<String> unspendablePolicyKeyIdentifiers,
  })
  _descriptorKeys(
    String descriptor, {
    required bdk.DescriptorType descriptorType,
  }) {
    final parsedKeys = <({BitcoinDescriptorKey key, String expression})>[];
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
      final xpubFingerprint = publicAccountKey(xpub).fingerprint
          .map((b) => b.toRadixString(16).padLeft(2, '0'))
          .join();

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
        key: BitcoinDescriptorKey(
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

    List<BitcoinDescriptorKey> uniqueKeys({required bool includeUnspendable}) {
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
    List<({BitcoinDescriptorKey key, String expression})> parsedKeys,
    BitcoinDescriptorKey unspendableInternalKey,
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

  static BitcoinDescriptorKey? _unspendableTaprootInternalKey(
    List<({BitcoinDescriptorKey key, String expression})> parsedKeys, {
    required String? taprootInternalKey,
  }) {
    if (taprootInternalKey == null) return null;
    final internalIndex = parsedKeys.indexWhere(
      (parsed) => parsed.expression == taprootInternalKey,
    );
    if (internalIndex < 0) return null;
    final internal = parsedKeys[internalIndex];

    final internalXpub = publicAccountKey(internal.key.xpub);
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
    required BitcoinNetwork network,
  }) {
    final parsed = parsePublicTwoPathDescriptor(
      descriptor: externalDescriptor,
      network: network,
    );
    final networkKind = network == BitcoinNetwork.mainnet
        ? bdk.NetworkKind.main
        : bdk.NetworkKind.test;
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
}

bdk.Network _nativePolicyNetwork(BitcoinNetwork network) => switch (network) {
  BitcoinNetwork.mainnet => bdk.Network.bitcoin,
  BitcoinNetwork.testnet => bdk.Network.testnet,
  BitcoinNetwork.regtest => bdk.Network.regtest,
  BitcoinNetwork.signet => throw const FormatException(
    'Unsupported Bitcoin network',
  ),
};
