import 'dart:convert';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/descriptor_derivation.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';

final class WalletDefinitionsCodec {
  static const currentVersion = 1;
  static const _payloadKeys = {'version', 'definitions'};
  static const _definitionKeys = {
    'walletRef',
    'network',
    'descriptor',
    'signerDevice',
    'birthdayUnix',
    'provenance',
  };
  const WalletDefinitionsCodec();

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
    if (definition.provenance != WalletProvenance.watchOnly &&
        definition.provenance != WalletProvenance.externalSigner) {
      throw const FormatException(
        'Seed-recoverable wallets belong in the recovery manifest',
      );
    }
    final descriptor =
        DescriptorDerivation.canonicalCombinedPublicBitcoinDescriptor(
          definition.descriptor,
          definition.network,
        );
    return WalletDefinitionModel.fromEntity(
      WalletDefinition(
        walletRef: definition.walletRef,
        network: definition.network,
        descriptor: descriptor,
        signerDevice: definition.signerDevice,
        birthday: definition.birthday,
        provenance: definition.provenance,
      ),
    );
  }
}

final class WalletDefinitionModel {
  final String walletRef;
  final String network;
  final String descriptor;
  final String? signerDevice;
  final int? birthdayUnix;
  final String provenance;

  const WalletDefinitionModel({
    required this.walletRef,
    required this.network,
    required this.descriptor,
    required this.signerDevice,
    required this.birthdayUnix,
    required this.provenance,
  });

  factory WalletDefinitionModel.fromEntity(WalletDefinition definition) =>
      WalletDefinitionModel(
        walletRef: definition.walletRef,
        network: definition.network.name,
        descriptor: definition.descriptor,
        signerDevice: definition.signerDevice?.name,
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
    final deviceName = _nullableString(json, 'signerDevice');
    final device = deviceName == null
        ? null
        : SignerDeviceEntity.values
              .where((value) => value.name == deviceName)
              .firstOrNull;
    final provenanceName = _string(json, 'provenance');
    final provenance = WalletProvenance.values
        .where((value) => value.name == provenanceName)
        .firstOrNull;
    final walletRef = _string(json, 'walletRef').trim();
    final descriptor = _string(json, 'descriptor').trim();
    if (network == null ||
        (deviceName != null && device == null) ||
        provenance == null ||
        walletRef.isEmpty ||
        descriptor.isEmpty ||
        descriptor.length > WalletDefinition.maxDescriptorLength) {
      throw const FormatException('Invalid wallet definition');
    }
    final definition = WalletDefinition(
      walletRef: walletRef,
      network: network,
      descriptor: descriptor,
      signerDevice: device,
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
    signerDevice: signerDevice == null
        ? null
        : SignerDeviceEntity.values.firstWhere(
            (value) => value.name == signerDevice,
          ),
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
    'signerDevice': signerDevice,
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
