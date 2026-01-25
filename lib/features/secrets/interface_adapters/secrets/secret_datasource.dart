import 'package:bb_mobile/features/secrets/interface_adapters/secrets/secret_model.dart';

abstract interface class SecretDatasource {
  Future<void> store({
    required String fingerprint,
    required SecretModel secret,
  });

  Future<SecretModel?> get(String fingerprint);

  Future<bool> exists(String fingerprint);

  Future<Map<String, SecretModel>> getAll();

  Future<void> delete(String fingerprint);
}
