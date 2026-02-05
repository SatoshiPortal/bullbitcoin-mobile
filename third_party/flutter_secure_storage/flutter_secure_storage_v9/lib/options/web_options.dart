part of '../flutter_secure_storage_v9.dart';

/// Specific options for web platform.
class WebOptions extends Options {
  const WebOptions({
    this.dbName = 'FlutterEncryptedStorage',
    this.publicKey = 'FlutterSecureStorageV9',
    this.wrapKey = '',
    this.wrapKeyIv = '',
  });

  static const WebOptions defaultOptions = WebOptions();

  final String dbName;
  final String publicKey;
  final String wrapKey;
  final String wrapKeyIv;

  @override
  Map<String, String> toMap() => <String, String>{
        'dbName': dbName,
        'publicKey': publicKey,
        'wrapKey': wrapKey,
        'wrapKeyIv': wrapKeyIv,
      };
}
