// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'backup.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$BackupImpl _$$BackupImplFromJson(Map<String, dynamic> json) => _$BackupImpl(
      version: (json['version'] as num?)?.toInt() ?? 1,
      mnemonic: (json['mnemonic'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      passphrases: (json['passphrases'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
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
      'mnemonic': instance.mnemonic,
      'passphrases': instance.passphrases,
      'labels': instance.labels,
      'descriptors': instance.descriptors,
    };
