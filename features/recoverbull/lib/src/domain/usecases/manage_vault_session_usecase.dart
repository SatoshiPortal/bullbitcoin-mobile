import 'dart:async';

import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart' show VaultKey;

import '../entities/backup_settings.dart';
import '../entities/encrypted_vault.dart';
import '../entities/vault_completion.dart';
import '../entities/vault_provider.dart';
import '../entities/vault_passkey.dart';
import '../passkey_credential_port.dart';
import '../passkey_password_port.dart';
import '../recoverbull_failure.dart';
import '../repositories/backup_metadata_repository.dart';
import '../repositories/key_server_repository.dart';
import 'complete_vault_usecase.dart';
import 'create_and_store_vault_usecase.dart';
import 'fetch_vault_key_usecase.dart';
import 'open_key_server_usecase.dart';

/// Owns exactly one flow session. Retry probes it; new route closes only it.
/// No listener, initialization or readiness event acquires a route implicitly.
final class ManageVaultSessionUsecase {
  final BackupMetadataRepository _metadata;
  final OpenKeyServerUsecase _open;
  final FetchVaultKeyUsecase _fetch;
  final CreateAndStoreVaultUsecase _create;
  final CompleteVaultUsecase _complete;
  final PasskeyCredentialPort? passkeys;
  final PasskeyPasswordPort? passkeyPasswords;
  KeyServerRepository? _server;
  BackupSettings? _settings;
  Completer<void>? _active;
  bool _closed = false;
  Future<void>? _closing;

  ManageVaultSessionUsecase(
    this._metadata,
    this._open,
    this._fetch,
    this._create,
    this._complete, {
    this.passkeys,
    this.passkeyPasswords,
  });

  bool get hasPendingProviderSave => _create.hasPendingProviderSave;
  bool get passkeysAvailable => passkeys != null && passkeyPasswords != null;

  /// [restartTor] restarts a Tor bootstrap that failed or stalled, as Retry
  /// does when Tor is not ready; [viaSnowflake] restarts it through Snowflake.
  /// New route only replaces this flow's circuit. [onProbe] receives when the
  /// key-server probe will give up, once Tor has delivered a route.
  Future<Result<void, RecoverBullFailure>> connect({
    bool newRoute = false,
    bool restartTor = false,
    bool viaSnowflake = false,
    void Function(DateTime deadline)? onProbe,
  }) => _run(
    (server, _) {
      onProbe?.call(DateTime.now().add(server.operationTimeout));
      return server.probe();
    },
    newRoute: newRoute || restartTor || viaSnowflake,
    restartTor: restartTor || viaSnowflake,
    viaSnowflake: viaSnowflake,
  );

  Future<Result<VaultCompletion, RecoverBullFailure>> create({
    required VaultProvider provider,
    required String password,
    bool passphraseWarningAccepted = false,
  }) {
    if (hasPendingProviderSave) {
      return Future.value(const Err(VaultContextChangedFailure()));
    }
    return _run(
      (server, settings) => _create.execute(
        settings: settings,
        server: server,
        provider: provider,
        password: password,
        passphraseWarningAccepted: passphraseWarningAccepted,
      ),
    );
  }

  Future<Result<VaultPasskey, RecoverBullFailure>> createPasskey() async {
    final passkeys = this.passkeys;
    if (_closed || passkeys == null) return const Err(VaultCancelledFailure());
    final result = await passkeys.create();
    return _closed ? const Err(VaultCancelledFailure()) : result;
  }

  Future<Result<VaultCompletion, RecoverBullFailure>> createWithPasskey({
    required VaultProvider provider,
    required VaultPasskey passkey,
    bool passphraseWarningAccepted = false,
  }) {
    final passkeys = this.passkeys;
    final passwords = passkeyPasswords;
    if (passkeys == null || passwords == null || hasPendingProviderSave) {
      return Future.value(const Err(VaultContextChangedFailure()));
    }
    return _run(
      (server, settings) => _create.executePasskey(
        settings: settings,
        server: server,
        provider: provider,
        passkey: passkey,
        secrets: passkeys,
        passwords: passwords,
        passphraseWarningAccepted: passphraseWarningAccepted,
      ),
    );
  }

  Future<Result<VaultCompletion, RecoverBullFailure>> verifyPasskey({
    required EncryptedVault vault,
    required BitcoinNetwork? recoveryNetwork,
    String passphrase = '',
    bool allowUnverified = false,
  }) {
    final passkeys = this.passkeys;
    final passwords = passkeyPasswords;
    final metadata = vault.passkey;
    if (passkeys == null || passwords == null || metadata == null) {
      return Future.value(const Err(VaultInvalidFailure()));
    }
    return _run((server, settings) async {
      switch (await passkeys.get(metadata)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(value: final prf):
          try {
            if (_closed) return const Err(VaultCancelledFailure());
            if (prf.length != 32) {
              return const Err(VaultPasskeyUnavailableFailure());
            }
            final password = passwords.derive(prf, vault);
            prf.fillRange(0, prf.length, 0);
            if (!await _current(settings)) {
              return const Err(VaultContextChangedFailure());
            }
            if (_closed) return const Err(VaultCancelledFailure());
            final fetched = await _fetch.execute(
              settings: settings,
              server: server,
              vault: vault,
              password: password,
            );
            if (_closed) return const Err(VaultCancelledFailure());
            if (!await _current(settings)) {
              return const Err(VaultContextChangedFailure());
            }
            switch (fetched) {
              case Err(:final failure):
                return Err(failure);
              case Ok(:final value):
                return await _complete.execute(
                  vault: vault,
                  key: value.key,
                  recoveryNetwork: recoveryNetwork,
                  cancelled: () => _closed,
                  capturedSettings: settings,
                  passphrase: passphrase,
                  allowUnverified: allowUnverified,
                );
            }
          } finally {
            prf.fillRange(0, prf.length, 0);
          }
      }
    });
  }

  /// Without [provider], the vault goes where the user first chose.
  Future<Result<VaultCompletion, RecoverBullFailure>> retryProviderSave([
    VaultProvider? provider,
  ]) async {
    if (_closed) return const Err(VaultCancelledFailure());
    if (_active != null) return const Err(VaultContextChangedFailure());
    final active = Completer<void>();
    _active = active;
    try {
      // Saving an already sealed vault needs neither consent nor a Tor route.
      return await _create.retryProviderSave(provider);
    } finally {
      _active = null;
      active.complete();
    }
  }

  /// Drops the sealed vault waiting for its provider write, so a new password can be chosen.
  bool abandonPendingProviderSave() =>
      _active == null && _create.abandonPendingProviderSave();

  Future<Result<VaultCompletion, RecoverBullFailure>> verify({
    required EncryptedVault vault,
    required String password,
    required BitcoinNetwork? recoveryNetwork,
    String passphrase = '',
    bool allowUnverified = false,
  }) => _run((server, settings) async {
    final fetched = await _fetch.execute(
      settings: settings,
      server: server,
      vault: vault,
      password: password,
    );
    if (_closed) return const Err(VaultCancelledFailure());
    if (!await _current(settings)) {
      return const Err(VaultContextChangedFailure());
    }
    switch (fetched) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        return _complete.execute(
          vault: vault,
          key: value.key,
          recoveryNetwork: recoveryNetwork,
          cancelled: () => _closed,
          capturedSettings: settings,
          passphrase: passphrase,
          allowUnverified: allowUnverified,
        );
    }
  });

  /// The screen retains this operation-scoped key and its settings only while
  /// protected. Retrying the passphrase never fetches the server key again.
  Future<Result<({VaultKey key, BackupSettings settings}), RecoverBullFailure>>
  verificationKey({required EncryptedVault vault, required String password}) =>
      _run((server, settings) async {
        final fetched = await _fetch.execute(
          settings: settings,
          server: server,
          vault: vault,
          password: password,
        );
        if (_closed) return const Err(VaultCancelledFailure());
        if (!await _current(settings)) {
          return const Err(VaultContextChangedFailure());
        }
        return fetched.map((value) => (key: value.key, settings: settings));
      });

  Future<Result<VaultKey, RecoverBullFailure>> reveal({
    required EncryptedVault vault,
    required String password,
  }) => _run((server, settings) async {
    final fetched = await _fetch.execute(
      settings: settings,
      server: server,
      vault: vault,
      password: password,
    );
    if (_closed) return const Err(VaultCancelledFailure());
    if (!await _current(settings)) {
      return const Err(VaultContextChangedFailure());
    }
    if (_closed) return const Err(VaultCancelledFailure());
    return fetched.map((value) => value.key);
  });

  Future<bool> _current(BackupSettings expected) async =>
      switch (await _metadata.settings()) {
        Ok(:final value) =>
          value.permissionGranted &&
              value.server == expected.server &&
              value.sameGeneration(expected),
        Err() => false,
      };

  Future<Result<T, RecoverBullFailure>> _run<T>(
    Future<Result<T, RecoverBullFailure>> Function(
      KeyServerRepository server,
      BackupSettings settings,
    )
    action, {
    bool newRoute = false,
    bool restartTor = false,
    bool viaSnowflake = false,
  }) async {
    if (_closed) return const Err(VaultCancelledFailure());
    if (_active != null) return const Err(VaultContextChangedFailure());
    final active = Completer<void>();
    _active = active;
    try {
      final BackupSettings settings;
      switch (await _metadata.settings()) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          settings = value;
      }
      if (!settings.permissionGranted) {
        return const Err(VaultContextChangedFailure());
      }
      if (_closed) return const Err(VaultCancelledFailure());
      var server = _server;
      if (server != null &&
          (newRoute ||
              _settings?.server != settings.server ||
              !(_settings?.sameGeneration(settings) ?? false))) {
        _server = null;
        await server.close();
        server = null;
      }
      if (_closed) return const Err(VaultCancelledFailure());
      if (server == null) {
        switch (await _open.execute(
          expected: settings,
          restartEmbedded: restartTor,
          viaSnowflake: viaSnowflake,
        )) {
          case Err(:final failure):
            return Err(failure);
          case Ok(:final value):
            server = value;
            _server = value;
            _settings = settings;
        }
      }
      if (_closed) return const Err(VaultCancelledFailure());
      final result = await action(server, settings);
      // A dead local Tor session never recovers: the next action opens a new one.
      if (result
          case Err(
            failure: KeyServerFailure(
              cause: KeyServerUnreachableCause.proxyGone,
            ),
          )
          when identical(_server, server)) {
        _server = null;
        await server.close();
      }
      return result;
    } finally {
      _active = null;
      active.complete();
    }
  }

  Future<void> close() {
    _closed = true;
    _create.close();
    return _closing ??= _close();
  }

  Future<void> _close() async {
    await passkeys?.cancel();
    await _active?.future;
    final server = _server;
    _server = null;
    _settings = null;
    await server?.close();
  }
}
