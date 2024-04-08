// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seed.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$SeedImpl _$$SeedImplFromJson(Map<String, dynamic> json) => _$SeedImpl(
      mnemonic: json['mnemonic'] as String? ?? '',
      mnemonicFingerprint: json['mnemonicFingerprint'] as String? ?? '',
      network: $enumDecode(_$BBNetworkEnumMap, json['network']),
      passphrases: (json['passphrases'] as List<dynamic>)
          .map((e) => Passphrase.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$SeedImplToJson(_$SeedImpl instance) =>
    <String, dynamic>{
      'mnemonic': instance.mnemonic,
      'mnemonicFingerprint': instance.mnemonicFingerprint,
      'network': _$BBNetworkEnumMap[instance.network]!,
      'passphrases': instance.passphrases,
    };

const _$BBNetworkEnumMap = {
  BBNetwork.Testnet: 'Testnet',
  BBNetwork.Mainnet: 'Mainnet',
};

_$PassphraseImpl _$$PassphraseImplFromJson(Map<String, dynamic> json) =>
    _$PassphraseImpl(
      passphrase: json['passphrase'] as String? ?? '',
      sourceFingerprint: json['sourceFingerprint'] as String,
    );

Map<String, dynamic> _$$PassphraseImplToJson(_$PassphraseImpl instance) =>
    <String, dynamic>{
      'passphrase': instance.passphrase,
      'sourceFingerprint': instance.sourceFingerprint,
    };
