import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/src/data/boundary.dart';
import 'package:secrets/src/data/fss_datasource.dart';
import 'package:secrets/src/domain/domain.dart';

/// Owns the application PIN without returning its stored value.
final class AppUnlockCredentialRepositoryImpl
    implements AppUnlockCredentialRepository {
  final _source = FlutterSecureStorageDatasource();

  @internal
  AppUnlockCredentialRepositoryImpl();

  @override
  Future<Result<bool, SecretFailure>> exists() => boundary(
    () async => await _source.fetchPin() != null,
    orElse: FetchSecretFailure.new,
  );

  @override
  Future<Result<void, SecretFailure>> set(String value) =>
      boundary(() => _source.storePin(value), orElse: StoreSecretFailure.new);

  @override
  Future<Result<bool, SecretFailure>> verify(String candidate) async {
    final read = await boundary(
      _source.fetchPin,
      orElse: FetchSecretFailure.new,
    );
    return switch (read) {
      Err(:final failure) => Err(failure),
      Ok(value: null) => const Err(SecretNotFoundFailure()),
      Ok(:final value) => Ok(value == candidate),
    };
  }

  @override
  Future<Result<void, SecretFailure>> delete() =>
      boundary(_source.deletePin, orElse: TrashSecretFailure.new);
}
