import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/bitcoin_descriptor_port.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:satoshifier/satoshifier.dart' as satoshifier;

class WatchOnlyInputParser {
  final BitcoinDescriptorPort _descriptorPort;

  WatchOnlyInputParser(this._descriptorPort);

  Future<WatchOnlyWalletEntity?> parseXpub(
    String input, {
    SignerDeviceEntity? signerDevice,
  }) async {
    final parsedInput = _parseXpubInput(input);
    final parsed = await satoshifier.WatchOnlyXpubParser.tryParse(
      parsedInput.key,
    );
    if (parsed is! satoshifier.WatchOnlyXpub) return null;
    if (signerDevice != null && parsedInput.derivationPath == null) {
      throw const SignerOriginRequiredException();
    }

    final extendedPubkey = parsed.extendedPubkey;
    final network = Network.fromName(extendedPubkey.network.name);
    final encodedScriptType = ScriptType.fromName(
      extendedPubkey.derivation.name,
    );
    final scriptType = _resolveXpubScriptType(
      parsedInput,
      encodedScriptType: encodedScriptType,
      network: network,
    );
    if (signerDevice != null) {
      _validateHardwareAccountXpub(
        parsedInput,
        canonicalXpub: extendedPubkey.xpub,
      );
    }

    return WatchOnlyWalletEntity.xpub(
      extendedPublicKey: extendedPubkey.pubBase58,
      canonicalXpub: extendedPubkey.xpub,
      network: network,
      scriptType: scriptType,
      masterFingerprint: parsedInput.masterFingerprint,
      derivationPath: parsedInput.derivationPath,
      signer: signerDevice == null ? SignerEntity.none : SignerEntity.remote,
      signerDevice: signerDevice,
    );
  }

  ParsedWatchOnlyDescriptor parseDescriptor(
    String descriptor, {
    required Network preferredNetwork,
  }) {
    ParsedWatchOnlyDescriptor parse(Network network) {
      final parsed = _descriptorPort.parseBitcoinDescriptor(
        descriptor: descriptor,
        network: network,
      );
      return (
        descriptor: parsed.descriptor,
        network: network,
        scriptType: parsed.scriptType,
        descriptorKeys: parsed.descriptorKeys,
        inferredChangePath: parsed.inferredChangePath,
      );
    }

    try {
      return parse(preferredNetwork);
    } on UnsupportedFixedPublicKeyDescriptorException {
      rethrow;
    } on Exception catch (error, stackTrace) {
      final otherNetwork = preferredNetwork.isTestnet
          ? Network.bitcoinMainnet
          : Network.bitcoinTestnet;
      try {
        return parse(otherNetwork);
      } on UnsupportedFixedPublicKeyDescriptorException {
        rethrow;
      } on Exception {
        Error.throwWithStackTrace(error, stackTrace);
      }
    }
  }

  List<List<WalletDescriptorKey>> groupDescriptorKeys(
    List<WalletDescriptorKey> keys,
  ) {
    final groups = <List<WalletDescriptorKey>>[];
    for (final key in keys) {
      final matchingGroups = <int>[
        for (final (index, group) in groups.indexed)
          if (group.any((groupedKey) => _sameSigner(groupedKey, key))) index,
      ];
      if (matchingGroups.isEmpty) {
        groups.add([key]);
        continue;
      }

      final target = groups[matchingGroups.first]..add(key);
      for (final index in matchingGroups.skip(1).toList().reversed) {
        target.addAll(groups.removeAt(index));
      }
    }
    return groups;
  }

  bool requiresExplicitHardwareSigner(
    List<WalletDescriptorKey> keys, {
    required ParsedWatchOnlyDescriptor descriptor,
    required SignerDeviceEntity? signerDevice,
  }) {
    if (signerDevice == null || keys.length != 1) return false;
    final type = descriptor.scriptType;
    final key = keys.single;
    final account = type?.standardAccount(
      key.derivationPath,
      descriptor.network,
    );
    return account != null &&
        account > 0 &&
        key.descriptorPath == standardSingleSignatureDescriptorPath;
  }

  _XpubInput _parseXpubInput(String input) {
    if (!input.startsWith('[')) {
      return (
        key: input,
        masterFingerprint: null,
        derivationPath: null,
        originScriptType: null,
        originCoinType: null,
        pathComponents: null,
      );
    }

    final originEnd = input.indexOf(']');
    if (originEnd < 0) throw const FormatException('Invalid key origin');
    final origin = input.substring(1, originEnd).split('/');
    if (!RegExp(r'^[0-9a-fA-F]{8}$').hasMatch(origin.first)) {
      throw const FormatException('Invalid key fingerprint');
    }

    final pathComponents = <({int index, bool hardened})>[];
    for (final component in origin.skip(1)) {
      final match = RegExp(r"^(\d+)(?:['h])?$").firstMatch(component);
      final index = match == null ? null : int.tryParse(match.group(1)!);
      if (index == null || index >= 0x80000000) {
        throw const FormatException('Invalid key origin path');
      }
      pathComponents.add((
        index: index,
        hardened: component.endsWith("'") || component.endsWith('h'),
      ));
    }

    ScriptType? originScriptType;
    int? originCoinType;
    if (pathComponents.isNotEmpty) {
      if (pathComponents.length < 2 ||
          !pathComponents[0].hardened ||
          !pathComponents[1].hardened) {
        throw const FormatException('Invalid account key origin');
      }
      originScriptType = switch (pathComponents[0].index) {
        44 => ScriptType.bip44,
        49 => ScriptType.bip49,
        84 => ScriptType.bip84,
        _ => throw const FormatException('Unsupported account purpose'),
      };
      originCoinType = pathComponents[1].index;
    }

    return (
      key: input.substring(originEnd + 1),
      masterFingerprint: origin.first.toLowerCase(),
      derivationPath: origin.length == 1
          ? null
          : 'm/${origin.skip(1).join('/')}',
      originScriptType: originScriptType,
      originCoinType: originCoinType,
      pathComponents: pathComponents,
    );
  }

  ScriptType _resolveXpubScriptType(
    _XpubInput input, {
    required ScriptType encodedScriptType,
    required Network network,
  }) {
    final originScriptType = input.originScriptType;
    if (originScriptType == null) return encodedScriptType;
    if (input.originCoinType != network.coinType) {
      throw const FormatException('Account origin network mismatch');
    }

    final prefix = input.key.substring(0, 4);
    final isStandardPrefix = prefix == 'xpub' || prefix == 'tpub';
    if (!isStandardPrefix && originScriptType != encodedScriptType) {
      throw const FormatException('Account origin purpose mismatch');
    }
    return originScriptType;
  }

  void _validateHardwareAccountXpub(
    _XpubInput input, {
    required String canonicalXpub,
  }) {
    final pathComponents = input.pathComponents;
    if (pathComponents == null ||
        pathComponents.length != 3 ||
        pathComponents.any((component) => !component.hardened)) {
      throw const FormatException('Invalid hardware account origin');
    }

    final account = pathComponents.last.index;
    final xpub = Bip32Derivation.getBip32Xpub(canonicalXpub);
    if (xpub.depth != 3 || xpub.index != account + 0x80000000) {
      throw const FormatException('Hardware account origin does not match key');
    }
  }

  bool _sameSigner(WalletDescriptorKey first, WalletDescriptorKey second) {
    if (first.xpub == second.xpub) return true;
    return first.masterFingerprint.isNotEmpty &&
        second.masterFingerprint.isNotEmpty &&
        first.masterFingerprint.toLowerCase() ==
            second.masterFingerprint.toLowerCase();
  }
}

class SignerOriginRequiredException implements Exception {
  const SignerOriginRequiredException();
}

typedef ParsedWatchOnlyDescriptor = ({
  String descriptor,
  Network network,
  ScriptType? scriptType,
  List<WalletDescriptorKey> descriptorKeys,
  bool inferredChangePath,
});

typedef _XpubInput = ({
  String key,
  String? masterFingerprint,
  String? derivationPath,
  ScriptType? originScriptType,
  int? originCoinType,
  List<({int index, bool hardened})>? pathComponents,
});
