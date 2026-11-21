import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:swaps/swaps.dart' as swaps;

/// Bridges typed keychain failures to the engine's exception-based port.
/// The engine stays pure Dart; secrets owns and checks the fixed namespace.
class SecureSecretStore implements swaps.SecretStore {
  final SwapKeychain _keychain;
  SecureSecretStore(this._keychain);

  T _value<T>(Result<T, SecretFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw Exception(
      'Swap keychain: ${failure.runtimeType}',
    ),
  };

  @override
  Future<void> write(String key, String value) async =>
      _value(await _keychain.write(key, value));
  @override
  Future<String?> read(String key) async => _value(await _keychain.read(key));
  @override
  Future<void> delete(String key) async => _value(await _keychain.delete(key));
}
