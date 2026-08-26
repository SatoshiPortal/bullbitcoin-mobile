import 'dart:io';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/domain/entity/decrypted_vault.dart';
import 'package:bull_recoverbull/src/support/logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';

class _Logger implements RecoverBullLogger {
  @override
  void fine(String message, {Object? error, StackTrace? trace}) {}

  @override
  void info(String message, {Object? error, StackTrace? trace}) {}

  @override
  void error(String code, {Object? error, StackTrace? trace}) {}

  @override
  void warning(String message, {Object? error, StackTrace? trace}) {}
}

final class _CapturingLogger implements RecoverBullLogger {
  final List<String> fineMessages = [];
  final List<String> infoMessages = [];
  String? warningMessage;
  Object? warningError;
  StackTrace? warningTrace;
  String? errorMessage;
  Object? errorObject;
  StackTrace? errorTrace;

  @override
  void fine(String message, {Object? error, StackTrace? trace}) {
    fineMessages.add(message);
  }

  @override
  void info(String message, {Object? error, StackTrace? trace}) {
    infoMessages.add(message);
  }

  @override
  void error(String code, {Object? error, StackTrace? trace}) {
    errorMessage = code;
    errorObject = error;
    errorTrace = trace;
  }

  @override
  void warning(String message, {Object? error, StackTrace? trace}) {
    warningMessage = message;
    warningError = error;
    warningTrace = trace;
  }
}

class _Settings extends Mock implements RecoverBullSettingsPort {}

class _Wallets extends Mock implements RecoverBullWalletRepositoryPort {}

class _Seeds extends Mock implements RecoverBullSeedPort {}

class _Defaults extends Mock implements RecoverBullDefaultWalletsPort {}

class _Tor extends Mock implements Tor {}

class _EmbeddedTor extends Mock implements EmbeddedTor {}

class _Watcher extends Mock implements WatchTorConnectionUsecase {}

void main() {
  test('forwards RecoverBull log context without losing diagnostics', () {
    final delegate = _CapturingLogger();
    final recoverBullLog = RecoverBullLog()..configure(delegate);
    final error = StateError('original exception');
    final trace = StackTrace.current;

    recoverBullLog.fine('fine message');
    recoverBullLog.info('info message');
    recoverBullLog.warning('warning message', error: error, trace: trace);
    recoverBullLog.severe(
      message: 'severe message',
      error: error,
      trace: trace,
    );

    expect(delegate.fineMessages, ['fine message']);
    expect(delegate.infoMessages, ['info message']);
    expect(delegate.warningMessage, 'warning message');
    expect(delegate.warningError, same(error));
    expect(delegate.warningTrace, same(trace));
    expect(delegate.errorMessage, 'severe message');
    expect(delegate.errorObject, same(error));
    expect(delegate.errorTrace, same(trace));
  });

  test('secret-bearing state, events, and decrypted vaults redact secrets', () {
    const password = 'password-secret';
    const vaultKey = 'vault-key-secret';
    const mnemonic = 'mnemonic-secret';
    final state = RecoverBullState(
      flow: RecoverBullFlow.viewVaultKey,
      vaultKey: vaultKey,
      vaultPassword: password,
      decryptedVault: DecryptedVault(mnemonic: [mnemonic]),
    );
    final event = OnVaultPasswordSet(password: password);
    final decryptEvent = OnVaultDecryption(vaultKey: vaultKey);

    for (final representation in [
      state.toString(),
      event.toString(),
      decryptEvent.toString(),
      state.decryptedVault.toString(),
    ]) {
      expect(representation, isNot(contains(password)));
      expect(representation, isNot(contains(vaultKey)));
      expect(representation, isNot(contains(mnemonic)));
    }
  });

  test('invalid encrypted JSON returns a failed recovery result', () async {
    final directory = await Directory.systemTemp.createTemp(
      'recoverbull-invalid-json-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final tor = _Tor();
    final embedded = _EmbeddedTor();
    when(() => tor.embedded).thenReturn(embedded);
    when(() => embedded.watcher).thenReturn(_Watcher());
    final feature = await RecoverBullFeature.create(
      config: RecoverBullConfig(databasePath: '${directory.path}/state.sqlite'),
      wallets: _Wallets(),
      seeds: _Seeds(),
      defaultWallets: _Defaults(),
      settings: _Settings(),
      tor: tor,
      logger: _Logger(),
    );

    final result = await feature.recoverBackup(
      encryptedBackup: '{not-valid-json',
      password: 'password-secret',
    );
    expect(result.restored, isFalse);
    await feature.lifecycle.dispose();
  });
}
