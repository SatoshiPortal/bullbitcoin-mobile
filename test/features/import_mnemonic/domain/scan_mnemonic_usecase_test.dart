import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/scan_mnemonic_usecase.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_wallet_status_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' as bip39;
import 'package:flutter_test/flutter_test.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show Err, Ok;
import 'package:bb_mobile/features/wallet/domain/wallet.dart' show ScriptType;

class _MockCheckWalletStatusUsecase extends Mock
    implements CheckWalletStatusUsecase {}

void main() {
  late _MockCheckWalletStatusUsecase checkWalletStatus;
  late ScanMnemonicUsecase usecase;

  setUpAll(() {
    registerFallbackValue(bip39.Language.english);
    registerFallbackValue(<ScriptType>{});
  });

  setUp(() {
    checkWalletStatus = _MockCheckWalletStatusUsecase();
    usecase = ScanMnemonicUsecase(checkWalletStatus: checkWalletStatus);
  });

  void derivation(
    Future<Map<ScriptType, Future<({BigInt satoshis, int transactions})>>>
    Function()
    answer,
  ) => when(
    () => checkWalletStatus(
      words: any(named: 'words'),
      language: any(named: 'language'),
      passphrase: any(named: 'passphrase'),
      scriptTypes: any(named: 'scriptTypes'),
    ),
  ).thenAnswer((_) => answer());

  Map<ScriptType, Future<Object>> run(Set<ScriptType> scriptTypes) =>
      usecase.execute(
        words: const ['abandon', 'about'],
        language: bip39.Language.english,
        passphrase: 'TREZOR',
        scriptTypes: scriptTypes,
      );

  test('a completed scan is Ok with its balance and history', () async {
    derivation(
      () async => {
        ScriptType.bip84: Future.value((
          satoshis: BigInt.from(1000),
          transactions: 3,
        )),
      },
    );

    final scan = await run({ScriptType.bip84})[ScriptType.bip84];

    expect(
      scan,
      isA<Ok<MnemonicScan, ImportMnemonicScanFailure>>().having(
        (ok) => ok.value,
        'value',
        (satoshis: BigInt.from(1000), transactions: 3),
      ),
    );
  });

  final attempt = ElectrumServerAttempt(
    url: 'ssl://electrum.example:50002',
    isCustom: false,
    error: Exception('connection refused'),
  );
  final timedOut = ElectrumServerAttempt(
    url: 'ssl://electrum.example:50002',
    isCustom: false,
    error: TimeoutException('no answer'),
  );

  for (final (name, error, failure)
      in <(String, Object, TypeMatcher<ImportMnemonicScanFailure>)>[
        (
          'every server failing',
          AllElectrumServersFailedException([attempt, timedOut]),
          isA<ImportMnemonicScanServerUnavailableFailure>(),
        ),
        (
          'no server configured',
          NoElectrumServersConfiguredException(
            ElectrumServerNetwork.bitcoinMainnet,
          ),
          isA<ImportMnemonicScanServerUnavailableFailure>(),
        ),
        (
          'every server timing out',
          AllElectrumServersFailedException([timedOut]),
          isA<ImportMnemonicScanTimeoutFailure>(),
        ),
        (
          'a timeout',
          TimeoutException('no answer'),
          isA<ImportMnemonicScanTimeoutFailure>(),
        ),
        (
          'an unknown error',
          StateError('secret detail'),
          isA<ImportMnemonicScanUnexpectedFailure>().having(
            (f) => f.logMessage,
            'logMessage',
            'StateError',
          ),
        ),
      ]) {
    test('maps $name to its failure', () async {
      derivation(
        () async => {
          // Handled like CheckWalletStatusUsecase does, until the scan listens.
          ScriptType.bip84: Future<({BigInt satoshis, int transactions})>.error(
            error,
          )..ignore(),
        },
      );

      final scan = await run({ScriptType.bip84})[ScriptType.bip84];

      expect(
        scan,
        isA<Err<Object, ImportMnemonicScanFailure>>().having(
          (err) => err.failure,
          'failure',
          failure,
        ),
      );
    });
  }

  for (final (error, code) in <(Object, String)>[
    (AllElectrumServersFailedException([attempt]), 'server_unavailable'),
    (TimeoutException('no answer'), 'timeout'),
    (CheckWalletStatusInvalidMnemonicException(), 'invalid_mnemonic'),
    (CheckWalletStatusException('settings'), 'unexpected'),
  ]) {
    test('does not duplicate the scan owner for $code', () async {
      final directory = await Directory.systemTemp.createTemp('scan-logs-');
      log = Logger.replace(directory: directory);
      addTearDown(() async {
        await log.flush();
        await directory.delete(recursive: true);
      });
      derivation(() => Future.error(error));

      await run({ScriptType.bip84})[ScriptType.bip84];
      await log.flush();

      final messages = (await log.readLogs()).map(
        (line) => line.split('\t')[2],
      );
      expect(messages, isEmpty);
    });
  }

  test('a failed derivation fails every script type, typed', () async {
    derivation(() => Future.error(CheckWalletStatusInvalidMnemonicException()));

    final scans = run({ScriptType.bip84, ScriptType.bip49, ScriptType.bip44});

    expect(scans.keys, {ScriptType.bip84, ScriptType.bip49, ScriptType.bip44});
    for (final scan in scans.values) {
      expect(
        await scan,
        isA<Err<Object, ImportMnemonicScanFailure>>().having(
          (err) => err.failure,
          'failure',
          isA<ImportMnemonicScanInvalidMnemonicFailure>(),
        ),
      );
    }
  });

  test('another derivation failure is unexpected', () async {
    derivation(() => Future.error(CheckWalletStatusException('settings')));

    final scan = await run({ScriptType.bip49})[ScriptType.bip49];

    expect(
      scan,
      isA<Err<Object, ImportMnemonicScanFailure>>().having(
        (err) => err.failure,
        'failure',
        isA<ImportMnemonicScanUnexpectedFailure>(),
      ),
    );
  });
}
