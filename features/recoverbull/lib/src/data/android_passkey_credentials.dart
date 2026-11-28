import 'dart:math';

import 'package:flutter/services.dart';
import 'package:primitives/primitives.dart';

import '../domain/entities/vault_passkey.dart';
import '../domain/passkey_credential_port.dart';
import '../domain/recoverbull_failure.dart';

/// The RP comes from the build, never from a vault.
final class AndroidPasskeyCredentials implements PasskeyCredentialPort {
  static const _channel = MethodChannel(
    'com.bullbitcoin.mobile/recoverbull_passkey',
  );
  final String rpId;

  const AndroidPasskeyCredentials(this.rpId);

  @override
  Future<Result<VaultPasskey, RecoverBullFailure>> create() async {
    try {
      final credential = await _channel.invokeMethod<Uint8List>('create');
      if (credential == null) {
        return const Err(VaultPasskeyUnavailableFailure());
      }
      final random = Random.secure();
      return Ok(
        VaultPasskey(
          rpId: rpId,
          credentialId: credential,
          prfSalt: List.generate(32, (_) => random.nextInt(256)),
        ),
      );
    } on PlatformException catch (error) {
      return Err(_failure(error));
    } on ArgumentError {
      return const Err(VaultPasskeyUnavailableFailure());
    } on Exception {
      return const Err(VaultPasskeyUnavailableFailure());
    }
  }

  @override
  Future<Result<Uint8List, RecoverBullFailure>> get(
    VaultPasskey passkey,
  ) async {
    if (passkey.rpId != rpId) return const Err(VaultInvalidFailure());
    try {
      final prf = await _channel.invokeMethod<Uint8List>('get', {
        'credentialId': Uint8List.fromList(passkey.credentialId),
        'salt': Uint8List.fromList(passkey.prfSalt),
      });
      if (prf == null) return const Err(VaultPasskeyUnavailableFailure());
      if (prf.length != 32) return const Err(VaultPasskeyUnavailableFailure());
      // Platform channel buffers may be read-only; callers own the copy.
      return Ok(Uint8List.fromList(prf));
    } on PlatformException catch (error) {
      return Err(_failure(error));
    } on Exception {
      return const Err(VaultPasskeyUnavailableFailure());
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _channel.invokeMethod<void>('cancel');
    } on Exception {
      // A torn-down channel already has no usable operation.
    }
  }

  static RecoverBullFailure _failure(PlatformException error) =>
      error.code == 'cancelled'
      ? const VaultCancelledFailure()
      : const VaultPasskeyUnavailableFailure();
}
