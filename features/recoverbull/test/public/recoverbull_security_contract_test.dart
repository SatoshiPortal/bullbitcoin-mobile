import 'dart:io';

import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bull_recoverbull/src/presentation/bloc.dart';
import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bull_tor/tor.dart';
import '../support/log_sink.dart';

class _Settings extends Mock implements RecoverBullSettingsPort {}

class _Wallets extends Mock implements RecoverBullWalletRepository {}

class _Seeds extends Mock implements RecoverBullSeedPort {}

class _Defaults extends Mock implements RecoverBullDefaultWalletsPort {}

class _Tor extends Mock implements Tor {}

class _EmbeddedTor extends Mock implements EmbeddedTor {}

class _Watcher extends Mock implements WatchTorConnectionUsecase {}

void main() {
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
    final shellLog = TestLogSink.recording();
    final sink = shellLog.scoped('recoverbull');
    const invalidBackup = '{not-valid-json-password-secret';
    const password = 'password-secret';
    final feature = await RecoverBullFeature.create(
      config: RecoverBullConfig(databasePath: '${directory.path}/state.sqlite'),
      wallets: _Wallets(),
      seeds: _Seeds(),
      defaultWallets: _Defaults(),
      settings: _Settings(),
      tor: tor,
      log: sink,
    );

    final result = await feature.recoverBackup(
      encryptedBackup: invalidBackup,
      password: password,
    );
    expect(result.restored, isFalse);
    final entry = sink.entries.singleWhere(
      (entry) => entry.message == 'recoverbull.recover_backup.invalid_vault',
    );
    expect(entry.level, 'error');
    expect(entry.scope, '[recoverbull]');
    expect(entry.error.toString(), 'Invalid encrypted backup format');
    expect(entry.trace, isNotNull);
    expect(entry.message, isNot(contains(invalidBackup)));
    expect(entry.message, isNot(contains(password)));
    expect(entry.error.toString(), isNot(contains(invalidBackup)));
    expect(entry.error.toString(), isNot(contains(password)));
    await feature.lifecycle.dispose();
  });
}
