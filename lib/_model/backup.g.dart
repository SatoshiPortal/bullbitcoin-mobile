// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BackupImpl _$$BackupImplFromJson(Map<String, dynamic> json) => _$BackupImpl(
      version: (json['version'] as num?)?.toInt() ?? 1,
      name: json['name'] as String? ?? '',
      layer: json['layer'] as String? ?? '',
      network: json['network'] as String? ?? '',
      script: json['script'] as String? ?? '',
      type: json['type'] as String? ?? '',
      mnemonic: (json['mnemonic'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      passphrase: json['passphrase'] as String? ?? '',
      labels: (json['labels'] as List<dynamic>?)
              ?.map((e) => Bip329Label.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <Bip329Label>[],
      descriptors: (json['descriptors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
    );

Map<String, dynamic> _$$BackupImplToJson(_$BackupImpl instance) =>
    <String, dynamic>{
      'version': instance.version,
      'name': instance.name,
      'layer': instance.layer,
      'network': instance.network,
      'script': instance.script,
      'type': instance.type,
      'mnemonic': instance.mnemonic,
      'passphrase': instance.passphrase,
      'labels': instance.labels,
      'descriptors': instance.descriptors,
    };
