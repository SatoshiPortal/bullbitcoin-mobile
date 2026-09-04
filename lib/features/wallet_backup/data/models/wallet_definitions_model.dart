import 'dart:convert';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/data/datasources/bdk_facade.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_descriptor_key.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_signer.dart';

/// The definitions section: every wallet that is not recoverable from the seed
/// alone, with the descriptor and the signer roster needed to bring it back.
///
/// Version 2 replaced the single `signerDevice` of version 1 with a full
/// `signers` list so multi-signature and Miniscript descriptors round-trip
/// every key's signer kind and device. No version-1 document was ever
/// published, so version 1 is rejected, not decoded (decision 4).
final class WalletDefinitionsCodec {
  static const currentVersion = 2;
  static const _payloadKeys = {'version', 'definitions'};
  static const _definitionKeys = {
    'walletRef',
    'network',
    'descriptor',
    'signers',
    'birthdayUnix',
    'provenance',
  };
  static const _signerKeys = {'id', 'signer', 'signerDevice', 'descriptorKeys'};
  static const _keyKeys = {
    'id',
    'masterFingerprint',
    'xpubFingerprint',
    'xpub',
    'derivationPath',
    'descriptorPath',
  };

  /// Canonicalizes a descriptor for the wire. Defaults to the same parser the
  /// wallet import path uses, so a stored and a backed-up descriptor never
  /// differ by notation alone.
  final String Function(String descriptor, Network network) canonicalize;

  const WalletDefinitionsCodec({this.canonicalize = _bdkCanonicalDescriptor});

  String encode(List<WalletDefinition> definitions) {
    final models = definitions.map(_canonicalModel).toList(growable: false)
      ..sort(WalletDefinitionModel.compare);
    _requireUnique(models);
    return jsonEncode({
      'version': currentVersion,
      'definitions': [for (final model in models) model.toJson()],
    });
  }

  List<WalletDefinition> decode(String payload) {
    final Object? decoded;
    try {
      decoded = jsonDecode(payload);
    } on FormatException {
      throw const FormatException('Wallet definitions must be valid JSON');
    }
    final object = _object(decoded, 'wallet definitions');
    _exactKeys(object, _payloadKeys, 'wallet definitions');
    if (object['version'] != currentVersion) {
      throw const FormatException('Unsupported wallet definitions version');
    }
    final values = object['definitions'];
    if (values is! List) {
      throw const FormatException('Wallet definitions must be a list');
    }
    final models = values
        .map(
          (value) => WalletDefinitionModel.fromJson(
            _object(value, 'wallet definition'),
          ),
        )
        .toList(growable: false);
    final canonical =
        models
            .map((model) => _canonicalModel(model.toEntity()))
            .toList(growable: false)
          ..sort(WalletDefinitionModel.compare);
    _requireUnique(canonical);
    return List.unmodifiable(canonical.map((model) => model.toEntity()));
  }

  WalletDefinitionModel _canonicalModel(WalletDefinition definition) {
    if (!definition.provenance.backedUpAsDefinition) {
      throw const FormatException(
        'Seed-recoverable wallets belong in the recovery manifest',
      );
    }
    return WalletDefinitionModel.fromEntity(
      WalletDefinition(
        walletRef: definition.walletRef,
        network: definition.network,
        descriptor: canonicalize(definition.descriptor, definition.network),
        signers: definition.signers,
        birthday: definition.birthday,
        provenance: definition.provenance,
      ),
    );
  }
}

String _bdkCanonicalDescriptor(String descriptor, Network network) {
  if (!network.isBitcoin) {
    throw const FormatException('Only Bitcoin descriptors are supported');
  }
  try {
    final parsed = BdkFacade.parsePublicTwoPathDescriptor(
      descriptor: descriptor,
      isTestnet: network.isTestnet,
    );
    // The parser fills in a change path for a receive-only descriptor; a
    // backup must carry both paths explicitly.
    if (parsed.inferredChangePath) {
      throw const FormatException('Combined descriptor required');
    }
    return parsed.descriptor;
  } on FormatException {
    rethrow;
  } on Exception {
    throw const FormatException('Invalid public wallet descriptor');
  }
}

final class WalletDefinitionModel {
  final String walletRef;
  final String network;
  final String descriptor;
  final List<WalletDefinitionSignerModel> signers;
  final int? birthdayUnix;
  final String provenance;

  const WalletDefinitionModel({
    required this.walletRef,
    required this.network,
    required this.descriptor,
    required this.signers,
    required this.birthdayUnix,
    required this.provenance,
  });

  factory WalletDefinitionModel.fromEntity(WalletDefinition definition) =>
      WalletDefinitionModel(
        walletRef: definition.walletRef,
        network: definition.network.name,
        descriptor: definition.descriptor,
        signers: [
          for (final signer in definition.signers)
            WalletDefinitionSignerModel.fromEntity(signer),
        ],
        birthdayUnix: definition.birthday == null
            ? null
            : definition.birthday!.toUtc().millisecondsSinceEpoch ~/ 1000,
        provenance: definition.provenance.name,
      );

  factory WalletDefinitionModel.fromJson(Map<String, Object?> json) {
    _exactKeys(
      json,
      WalletDefinitionsCodec._definitionKeys,
      'wallet definition',
    );
    final birthday = json['birthdayUnix'];
    if (birthday != null &&
        (birthday is! int || birthday < 0 || birthday > 253402300799)) {
      throw const FormatException('Invalid wallet birthday');
    }
    final networkName = _string(json, 'network');
    final network = Network.values
        .where((value) => value.name == networkName)
        .firstOrNull;
    final provenanceName = _string(json, 'provenance');
    final provenance = WalletProvenance.values
        .where((value) => value.name == provenanceName)
        .firstOrNull;
    final walletRef = _string(json, 'walletRef').trim();
    final descriptor = _string(json, 'descriptor').trim();
    final signers = json['signers'];
    if (network == null ||
        provenance == null ||
        walletRef.isEmpty ||
        descriptor.isEmpty ||
        descriptor.length > WalletDefinition.maxDescriptorLength ||
        signers is! List) {
      throw const FormatException('Invalid wallet definition');
    }
    final definition = WalletDefinition(
      walletRef: walletRef,
      network: network,
      descriptor: descriptor,
      signers: [
        for (final value in signers)
          WalletDefinitionSignerModel.fromJson(
            _object(value, 'wallet definition signer'),
          ).toEntity(),
      ],
      birthday: birthday is int
          ? DateTime.fromMillisecondsSinceEpoch(birthday * 1000, isUtc: true)
          : null,
      provenance: provenance,
    );
    return WalletDefinitionModel.fromEntity(definition);
  }

  WalletDefinition toEntity() => WalletDefinition(
    walletRef: walletRef,
    network: Network.values.firstWhere((value) => value.name == network),
    descriptor: descriptor,
    signers: [for (final signer in signers) signer.toEntity()],
    birthday: birthdayUnix == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            birthdayUnix! * 1000,
            isUtc: true,
          ),
    provenance: WalletProvenance.values.firstWhere(
      (value) => value.name == provenance,
    ),
  );

  Map<String, Object?> toJson() => {
    'walletRef': walletRef,
    'network': network,
    'descriptor': descriptor,
    'signers': [for (final signer in signers) signer.toJson()],
    'birthdayUnix': birthdayUnix,
    'provenance': provenance,
  };

  static int compare(WalletDefinitionModel left, WalletDefinitionModel right) {
    final descriptor = left.descriptor.compareTo(right.descriptor);
    return descriptor != 0
        ? descriptor
        : left.walletRef.compareTo(right.walletRef);
  }
}

/// One signer of a definition: who holds the keys and which descriptor keys
/// are theirs. Key ids follow descriptor order, so they re-attach to the same
/// keys when the descriptor is parsed again on restore.
final class WalletDefinitionSignerModel {
  final String id;
  final String signer;
  final String? signerDevice;
  final List<WalletDefinitionKeyModel> descriptorKeys;

  const WalletDefinitionSignerModel({
    required this.id,
    required this.signer,
    required this.signerDevice,
    required this.descriptorKeys,
  });

  factory WalletDefinitionSignerModel.fromEntity(WalletSigner signer) =>
      WalletDefinitionSignerModel(
        id: signer.id,
        signer: signer.signer.name,
        signerDevice: signer.signerDevice?.name,
        descriptorKeys: [
          for (final key in signer.descriptorKeys)
            WalletDefinitionKeyModel.fromEntity(key),
        ],
      );

  factory WalletDefinitionSignerModel.fromJson(Map<String, Object?> json) {
    _exactKeys(json, WalletDefinitionsCodec._signerKeys, 'definition signer');
    final id = _string(json, 'id').trim();
    final signerName = _string(json, 'signer');
    final signer = SignerEntity.values
        .where((value) => value.name == signerName)
        .firstOrNull;
    final deviceName = _nullableString(json, 'signerDevice');
    final device = deviceName == null
        ? null
        : SignerDeviceEntity.values
              .where((value) => value.name == deviceName)
              .firstOrNull;
    final keys = json['descriptorKeys'];
    if (id.isEmpty ||
        signer == null ||
        (deviceName != null && device == null) ||
        keys is! List ||
        keys.isEmpty) {
      throw const FormatException('Invalid wallet definition signer');
    }
    return WalletDefinitionSignerModel(
      id: id,
      signer: signer.name,
      signerDevice: device?.name,
      descriptorKeys: [
        for (final value in keys)
          WalletDefinitionKeyModel.fromJson(
            _object(value, 'definition key'),
            signerId: id,
          ),
      ],
    );
  }

  WalletSigner toEntity() => WalletSigner(
    id: id,
    signer: SignerEntity.values.firstWhere((value) => value.name == signer),
    signerDevice: signerDevice == null
        ? null
        : SignerDeviceEntity.values.firstWhere(
            (value) => value.name == signerDevice,
          ),
    descriptorKeys: [for (final key in descriptorKeys) key.toEntity(id)],
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'signer': signer,
    'signerDevice': signerDevice,
    'descriptorKeys': [for (final key in descriptorKeys) key.toJson()],
  };
}

final class WalletDefinitionKeyModel {
  final String id;
  final String masterFingerprint;
  final String xpubFingerprint;
  final String xpub;
  final String? derivationPath;
  final String descriptorPath;

  const WalletDefinitionKeyModel({
    required this.id,
    required this.masterFingerprint,
    required this.xpubFingerprint,
    required this.xpub,
    required this.derivationPath,
    required this.descriptorPath,
  });

  factory WalletDefinitionKeyModel.fromEntity(WalletDescriptorKey key) =>
      WalletDefinitionKeyModel(
        id: key.id,
        masterFingerprint: key.masterFingerprint,
        xpubFingerprint: key.xpubFingerprint,
        xpub: key.xpub,
        derivationPath: key.derivationPath,
        descriptorPath: key.descriptorPath,
      );

  factory WalletDefinitionKeyModel.fromJson(
    Map<String, Object?> json, {
    required String signerId,
  }) {
    _exactKeys(json, WalletDefinitionsCodec._keyKeys, 'definition key');
    final id = _string(json, 'id').trim();
    final xpub = _string(json, 'xpub').trim();
    if (id.isEmpty || xpub.isEmpty) {
      throw const FormatException('Invalid wallet definition key');
    }
    return WalletDefinitionKeyModel(
      id: id,
      masterFingerprint: _string(json, 'masterFingerprint'),
      xpubFingerprint: _string(json, 'xpubFingerprint'),
      xpub: xpub,
      derivationPath: _nullableString(json, 'derivationPath'),
      descriptorPath: _string(json, 'descriptorPath'),
    );
  }

  WalletDescriptorKey toEntity(String signerId) => WalletDescriptorKey(
    id: id,
    signerId: signerId,
    masterFingerprint: masterFingerprint,
    xpubFingerprint: xpubFingerprint,
    xpub: xpub,
    derivationPath: derivationPath,
    descriptorPath: descriptorPath,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'masterFingerprint': masterFingerprint,
    'xpubFingerprint': xpubFingerprint,
    'xpub': xpub,
    'derivationPath': derivationPath,
    'descriptorPath': descriptorPath,
  };
}

Map<String, Object?> _object(Object? value, String description) {
  if (value is! Map) throw FormatException('$description must be an object');
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw FormatException('$description keys must be strings');
    }
    result[entry.key as String] = entry.value;
  }
  return result;
}

void _exactKeys(
  Map<String, Object?> value,
  Set<String> expected,
  String description,
) {
  if (value.length != expected.length || !value.keys.every(expected.contains)) {
    throw FormatException('$description contains missing or unknown fields');
  }
}

String _string(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value is String) return value;
  throw FormatException('$key must be a string');
}

String? _nullableString(Map<String, Object?> json, String key) {
  final value = json[key];
  if (value == null || value is String) return value as String?;
  throw FormatException('$key must be a string or null');
}

void _requireUnique(List<WalletDefinitionModel> models) {
  final identities = <String>{};
  final walletRefs = <String>{};
  for (final model in models) {
    if (!walletRefs.add(model.walletRef) ||
        !identities.add('${model.network}\u0000${model.descriptor}')) {
      throw const FormatException('Duplicate wallet definition');
    }
  }
}
