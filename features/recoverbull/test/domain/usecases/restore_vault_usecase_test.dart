import 'package:bull_recoverbull/src/domain/entities/decrypted_vault.dart';
import 'package:bull_recoverbull/src/domain/entities/recoverbull_wallet.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_default_wallets_port.dart';
import 'package:bull_recoverbull/src/domain/recoverbull_failure.dart';
import 'package:bull_recoverbull/src/domain/usecases/restore_vault_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../support/log_sink.dart';

class _Port implements RecoverBullDefaultWalletsPort {
  final Object? error;
  List<String>? received;

  _Port({this.error});

  @override
  Future<List<RecoverBullWallet>> execute({
    required List<String> mnemonicWords,
  }) async {
    received = mnemonicWords;
    if (error != null) throw error!;
    return const [];
  }
}

void main() {
  final words = [...List.filled(11, 'zoo'), 'wrong'];
  final vault = DecryptedVault(mnemonic: words);

  test('returns Ok and hands the mnemonic words to the port', () async {
    final port = _Port();
    final log = TestLogSink.recording();

    final result = await RestoreVaultUsecase(
      log: log,
      createDefaultWalletsUsecase: port,
    ).execute(decryptedVault: vault);

    expect(result, isA<Ok<Null, RecoverBullFailure>>());
    expect(port.received, words);
    expect(log.entries.where((e) => e.level == 'error'), isEmpty);
  });

  test('maps a port exception to a sanitized failure without leaking '
      'secrets into the logs', () async {
    final port = _Port(error: StateError('boom ${words.join(' ')} sk-secret'));
    final log = TestLogSink.recording();

    final result = await RestoreVaultUsecase(
      log: log,
      createDefaultWalletsUsecase: port,
    ).execute(decryptedVault: vault);

    expect(result, isA<Err<Null, RecoverBullFailure>>());
    final failure = (result as Err<Null, RecoverBullFailure>).failure;
    expect(failure, isA<RecoverBullUnexpectedFailure>());
    expect(failure.toString(), isNot(contains('zoo')));
    expect(failure.toString(), isNot(contains('sk-secret')));

    expect(log.entries, isNotEmpty);
    for (final entry in log.entries) {
      final text = '${entry.message} ${entry.error}';
      expect(text, isNot(contains('zoo')));
      expect(text, isNot(contains('wrong')));
      expect(text, isNot(contains('sk-secret')));
    }
  });

  test(
    'returns Err without calling the port for an invalid mnemonic',
    () async {
      final port = _Port();

      final result = await RestoreVaultUsecase(
        log: TestLogSink.recording(),
        createDefaultWalletsUsecase: port,
      ).execute(decryptedVault: DecryptedVault(mnemonic: const ['zoo']));

      expect(result, isA<Err<Null, RecoverBullFailure>>());
      expect(port.received, isNull);
    },
  );
}
