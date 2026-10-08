import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/domain.dart';

/// Compatibility contract for secure application key-value entries.
abstract interface class ApplicationStorageRepository {
  @useResult
  Future<Result<String?, SecretFailure>> read(String key);
  @useResult
  Future<Result<void, SecretFailure>> write(String key, String value);
  @useResult
  Future<Result<void, SecretFailure>> delete(String key);
  @useResult
  Future<Result<bool, SecretFailure>> contains(String key);
  @useResult
  Future<Result<Map<String, String>, SecretFailure>> readAll();
}
