import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/domain/domain.dart';

/// Storage contract for the application unlock credential, never its raw value.
abstract interface class AppUnlockCredentialRepository {
  @useResult
  Future<Result<bool, SecretFailure>> exists();
  @useResult
  Future<Result<void, SecretFailure>> set(String value);
  @useResult
  Future<Result<bool, SecretFailure>> verify(String candidate);
  @useResult
  Future<Result<void, SecretFailure>> delete();
}
