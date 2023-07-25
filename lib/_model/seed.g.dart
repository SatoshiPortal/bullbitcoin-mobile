// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seed.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$_Seed _$$_SeedFromJson(Map<String, dynamic> json) => _$_Seed(
      mnemonic: json['mnemonic'] as String? ?? '',
      mnemonicFingerprint: json['mnemonicFingerprint'] as String? ?? '',
      network: $enumDecode(_$BBNetworkEnumMap, json['network']),
      passphrases: (json['passphrases'] as List<dynamic>)
          .map((e) => Passphrase.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$_SeedToJson(_$_Seed instance) => <String, dynamic>{
      'mnemonic': instance.mnemonic,
      'mnemonicFingerprint': instance.mnemonicFingerprint,
      'network': _$BBNetworkEnumMap[instance.network]!,
      'passphrases': instance.passphrases,
    };

const _$BBNetworkEnumMap = {
  BBNetwork.Testnet: 'Testnet',
  BBNetwork.Mainnet: 'Mainnet',
};

_$_Passphrase _$$_PassphraseFromJson(Map<String, dynamic> json) =>
    _$_Passphrase(
      passphrase: json['passphrase'] as String? ?? '',
      sourceFingerprint: json['sourceFingerprint'] as String,
    );

Map<String, dynamic> _$$_PassphraseToJson(_$_Passphrase instance) =>
    <String, dynamic>{
      'passphrase': instance.passphrase,
      'sourceFingerprint': instance.sourceFingerprint,
    };
