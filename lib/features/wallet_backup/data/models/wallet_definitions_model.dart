import 'dart:convert';

import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_definition.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_provenance.dart';
import 'package:bull_sdk/bdk.dart' as bdk;

final class WalletDefinitionsCodec {
  static const currentVersion = 1;
  static const _payloadKeys = {'version', 'definitions'};
  static const _definitionKeys = {
    'walletRef',
    'network',
    'receiveDescriptor',
    'changeDescriptor',
    'masterFingerprint',
    'signerDevice',
    'birthdayUnix',
    'provenance',
    'seedPassphraseUsed',
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
    if (!_sameOrder(models, canonical) ||
        jsonEncode({
              'version': currentVersion,
              'definitions': [for (final model in canonical) model.toJson()],
            }) !=
            payload) {
      throw const FormatException('Wallet definitions must be canonical');
    }
    return List.unmodifiable(canonical.map((model) => model.toEntity()));
  }

  WalletDefinitionModel _canonicalModel(WalletDefinition definition) {
    final receive = _publicDescriptor(
      definition.receiveDescriptor,
      definition.network,
    );
    final change = definition.changeDescriptor == null
        ? null
        : _publicDescriptor(definition.changeDescriptor!, definition.network);
    return WalletDefinitionModel.fromEntity(
      WalletDefinition(
        walletRef: definition.walletRef,
        network: definition.network,
        receiveDescriptor: receive,
        changeDescriptor: change,
        masterFingerprint: definition.masterFingerprint,
        signerDevice: definition.signerDevice,
        birthday: definition.birthday,
        provenance: definition.provenance,
        seedPassphraseUsed: definition.seedPassphraseUsed,
      ),
    );
  }

  String _publicDescriptor(String value, Network network) {
    if (!network.isBitcoin) {
      throw const FormatException('Only Bitcoin descriptors are supported');
    }
    try {
      final descriptor = bdk.Descriptor(
        descriptor: value,
        networkKind: network.isTestnet
            ? bdk.NetworkKind.test
            : bdk.NetworkKind.main,
      );
      descriptor.sanityCheck();
      final public = descriptor.toString();
      if (descriptor.toStringWithSecret() != public) {
        throw const FormatException('Private wallet descriptor rejected');
      }
      return public;
    } on FormatException {
      rethrow;
    } on Exception {
      throw const FormatException('Invalid public wallet descriptor');
    }
  }
}

final class WalletDefinitionModel {
  final String walletRef;
  final String network;
  final String receiveDescriptor;
  final String? changeDescriptor;
  final String? masterFingerprint;
  final String? signerDevice;
  final int? birthdayUnix;
  final String provenance;
  final bool? seedPassphraseUsed;

  const WalletDefinitionModel({
    required this.walletRef,
    required this.network,
    required this.receiveDescriptor,
    required this.changeDescriptor,
    required this.masterFingerprint,
    required this.signerDevice,
    required this.birthdayUnix,
    required this.provenance,
    required this.seedPassphraseUsed,
  });

  factory WalletDefinitionModel.fromEntity(WalletDefinition definition) =>
      WalletDefinitionModel(
        walletRef: definition.walletRef,
        network: definition.network.name,
        receiveDescriptor: definition.receiveDescriptor,
        changeDescriptor: definition.changeDescriptor,
        masterFingerprint: definition.masterFingerprint,
        signerDevice: definition.signerDevice?.name,
        birthdayUnix: definition.birthday == null
            ? null
            : definition.birthday!.toUtc().millisecondsSinceEpoch ~/ 1000,
        provenance: definition.provenance.name,
        seedPassphraseUsed: definition.seedPassphraseUsed,
      );

  factory WalletDefinitionModel.fromJson(Map<String, Object?> json) {
    _exactKeys(json, WalletDefinitionsCodec._definitionKeys, 'definition');
    final birthday = json['birthdayUnix'];
    if (birthday != null && (birthday is! int || birthday < 0)) {
      throw const FormatException('Invalid wallet birthday');
    }
    final passphraseUsed = json['seedPassphraseUsed'];
    if (passphraseUsed != null && passphraseUsed is! bool) {
      throw const FormatException('Invalid seed passphrase state');
    }
    try {
      final network = Network.values.firstWhere(
        (value) => value.name == json['network'],
      );
      final deviceName = json['signerDevice'];
      final device = deviceName == null
          ? null
          : SignerDeviceEntity.values.firstWhere(
              (value) => value.name == deviceName,
            );
      final provenance = WalletProvenance.values.firstWhere(
        (value) => value.name == json['provenance'],
      );
      final definition = WalletDefinition(
        walletRef: _string(json, 'walletRef'),
        network: network,
        receiveDescriptor: _string(json, 'receiveDescriptor'),
        changeDescriptor: _nullableString(json, 'changeDescriptor'),
        masterFingerprint: _nullableString(json, 'masterFingerprint'),
        signerDevice: device,
        birthday: birthday is int
            ? DateTime.fromMillisecondsSinceEpoch(birthday * 1000, isUtc: true)
            : null,
        provenance: provenance,
        seedPassphraseUsed: passphraseUsed as bool?,
      );
      return WalletDefinitionModel.fromEntity(definition);
    } on ArgumentError {
      throw const FormatException('Invalid wallet definition');
    } on StateError {
      throw const FormatException('Invalid wallet definition enum');
    }
  }

  WalletDefinition toEntity() => WalletDefinition(
    walletRef: walletRef,
    network: Network.values.firstWhere((value) => value.name == network),
    receiveDescriptor: receiveDescriptor,
    changeDescriptor: changeDescriptor,
    masterFingerprint: masterFingerprint,
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
    seedPassphraseUsed: seedPassphraseUsed,
  );

  Map<String, Object?> toJson() => {
    'walletRef': walletRef,
    'network': network,
    'receiveDescriptor': receiveDescriptor,
    'changeDescriptor': changeDescriptor,
    'masterFingerprint': masterFingerprint,
    'signerDevice': signerDevice,
    'birthdayUnix': birthdayUnix,
    'provenance': provenance,
    'seedPassphraseUsed': seedPassphraseUsed,
  };

  static int compare(WalletDefinitionModel left, WalletDefinitionModel right) {
    final receive = left.receiveDescriptor.compareTo(right.receiveDescriptor);
    if (receive != 0) return receive;
    final change = (left.changeDescriptor ?? '').compareTo(
      right.changeDescriptor ?? '',
    );
    return change != 0 ? change : left.walletRef.compareTo(right.walletRef);
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
  for (final model in models) {
    if (!identities.add(
      '${model.network}\u0000${model.receiveDescriptor}\u0000${model.changeDescriptor ?? ''}',
    )) {
      throw const FormatException('Duplicate wallet definition');
    }
  }
}

bool _sameOrder(
  List<WalletDefinitionModel> left,
  List<WalletDefinitionModel> right,
) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index].walletRef != right[index].walletRef ||
        left[index].receiveDescriptor != right[index].receiveDescriptor ||
        left[index].changeDescriptor != right[index].changeDescriptor) {
      return false;
    }
  }
  return true;
}
