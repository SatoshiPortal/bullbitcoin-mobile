import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'extended_public_key_entity.freezed.dart';

@freezed
abstract class ExtendedPublicKeyEntity with _$ExtendedPublicKeyEntity {
  const factory ExtendedPublicKeyEntity({
    required String key,
    required ScriptType type,
    @Default('') String label,
  }) = _ExtendedPublicKeyEntity;

  factory ExtendedPublicKeyEntity.from(
    String extendedPublicKey, {
    String label = '',
  }) {
    final type = ScriptType.fromExtendedPublicKey(extendedPublicKey);
    return ExtendedPublicKeyEntity(
      key: extendedPublicKey,
      type: type,
      label: label,
    );
  }
}
