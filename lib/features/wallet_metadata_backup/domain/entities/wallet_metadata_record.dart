import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_json.dart';
import 'package:bb_mobile/features/wallet_metadata_backup/domain/wallet_metadata_backup_limits.dart';

final class WalletMetadataRecord implements Comparable<WalletMetadataRecord> {
  final String type;
  final int version;
  final Map<String, Object?> scope;
  final String recordId;
  final Map<String, Object?> payload;

  factory WalletMetadataRecord({
    required String type,
    required int version,
    required Map<String, Object?> scope,
    required String recordId,
    required Map<String, Object?> payload,
  }) {
    if (version <= 0 || version > WalletMetadataBackupLimits.maxSignedInt64) {
      throw ArgumentError.value(version, 'version', 'must be a positive int64');
    }
    return WalletMetadataRecord._(
      type: walletMetadataValidateString(type, name: 'type', allowEmpty: false),
      version: version,
      scope: walletMetadataFreezeJsonObject(scope),
      recordId: walletMetadataValidateString(
        recordId,
        name: 'recordId',
        allowEmpty: false,
      ),
      payload: walletMetadataFreezeJsonObject(payload),
    );
  }

  const WalletMetadataRecord._({
    required this.type,
    required this.version,
    required this.scope,
    required this.recordId,
    required this.payload,
  });

  String get identity =>
      walletMetadataCanonicalJsonEncode([type, version, scope, recordId]);

  String get _canonicalScope => walletMetadataCanonicalJsonEncode(scope);

  @override
  int compareTo(WalletMetadataRecord other) {
    final typeOrder = type.compareTo(other.type);
    if (typeOrder != 0) return typeOrder;
    final versionOrder = version.compareTo(other.version);
    if (versionOrder != 0) return versionOrder;
    final scopeOrder = _canonicalScope.compareTo(other._canonicalScope);
    if (scopeOrder != 0) return scopeOrder;
    return recordId.compareTo(other.recordId);
  }
}
