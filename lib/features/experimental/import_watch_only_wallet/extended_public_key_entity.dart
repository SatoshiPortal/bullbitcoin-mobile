import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';

class ExtendedPublicKeyEntity {
  final String key;
  final ScriptType type;
  final String label;

  const ExtendedPublicKeyEntity({
    required this.key,
    required this.type,
    this.label = '',
  });

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
