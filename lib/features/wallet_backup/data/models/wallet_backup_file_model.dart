final class WalletBackupFileModel {
  static const fileKind = 'bullbitcoin-data-backup-file';
  final String kind;
  final int version;
  final String format;
  final int createdAt;
  final String publicKey;
  final String signature;
  final Object payload;

  const WalletBackupFileModel({
    this.kind = fileKind,
    this.version = 1,
    required this.format,
    required this.createdAt,
    required this.publicKey,
    required this.signature,
    required this.payload,
  });

  factory WalletBackupFileModel.fromJson(Map<String, dynamic> json) {
    const fields = {
      'kind',
      'version',
      'format',
      'createdAt',
      'publicKey',
      'signature',
      'payload',
    };
    if (json.length != fields.length ||
        !json.keys.every(fields.contains) ||
        json['kind'] is! String ||
        json['version'] is! int ||
        json['format'] is! String ||
        json['createdAt'] is! int ||
        json['publicKey'] is! String ||
        json['signature'] is! String ||
        json['payload'] == null) {
      throw const FormatException('Invalid data backup file envelope');
    }
    return WalletBackupFileModel(
      kind: json['kind'] as String,
      version: json['version'] as int,
      format: json['format'] as String,
      createdAt: json['createdAt'] as int,
      publicKey: json['publicKey'] as String,
      signature: json['signature'] as String,
      payload: json['payload'] as Object,
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind,
    'version': version,
    'format': format,
    'createdAt': createdAt,
    'publicKey': publicKey,
    'signature': signature,
    'payload': payload,
  };
}
