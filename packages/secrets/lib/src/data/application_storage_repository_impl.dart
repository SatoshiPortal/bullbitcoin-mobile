import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/boundary.dart';
import 'package:secrets/src/data/fss_datasource.dart';
import 'package:secrets/src/domain/domain.dart';

/// Compatibility storage for application data, excluding custody-owned keys.
final class ApplicationStorageRepositoryImpl
    implements ApplicationStorageRepository {
  final _source = FlutterSecureStorageDatasource();

  @internal
  ApplicationStorageRepositoryImpl();

  @override
  Future<Result<String?, SecretFailure>> read(String key) => boundary(
    () => _source.readApplicationValue(key),
    orElse: FetchSecretFailure.new,
  );
  @override
  Future<Result<void, SecretFailure>> write(String key, String value) =>
      boundary(
        () => _source.writeApplicationValue(key, value),
        orElse: StoreSecretFailure.new,
      );
  @override
  Future<Result<void, SecretFailure>> delete(String key) => boundary(
    () => _source.deleteApplicationValue(key),
    orElse: TrashSecretFailure.new,
  );
  @override
  Future<Result<bool, SecretFailure>> contains(String key) => boundary(
    () => _source.containsApplicationValue(key),
    orElse: FetchSecretFailure.new,
  );
  @override
  Future<Result<Map<String, String>, SecretFailure>> readAll() =>
      boundary(_source.readApplicationValues, orElse: FetchSecretFailure.new);
}
