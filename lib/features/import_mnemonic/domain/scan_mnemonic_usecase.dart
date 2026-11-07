import 'dart:async';

import 'package:bb_mobile/core/electrum/domain/errors/electrum_fallback_exception.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/import_mnemonic_failure.dart';
import 'package:bb_mobile/features/import_mnemonic/domain/check_wallet_status_usecase.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart' show Language;
import 'package:bull_logger/bull_logger.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart'
    show ScriptType;

typedef MnemonicScan = ({BigInt satoshis, int transactions});

/// Scans the chain for a mnemonic before it is imported, one result per script type.
///
/// Every scan resolves to a [Result]: a failure is typed, never mistaken for an empty wallet.
class ScanMnemonicUsecase {
  final CheckWalletStatusUsecase _checkWalletStatus;

  ScanMnemonicUsecase({required this._checkWalletStatus});

  /// Derives once for all [scriptTypes]; each future completes on its own, so a slow scan does not hold back the others. None of them throws.
  Map<ScriptType, Future<Result<MnemonicScan, ImportMnemonicScanFailure>>>
  execute({
    required List<String> words,
    required Language language,
    required String passphrase,
    required Set<ScriptType> scriptTypes,
  }) {
    final scans = _checkWalletStatus(
      words: words,
      language: language,
      passphrase: passphrase,
      scriptTypes: scriptTypes,
    );
    // The derivation error, if any, is read by every scan below.
    unawaited(scans.then<void>((_) {}, onError: (Object _) {}));
    return {
      for (final scriptType in scriptTypes)
        scriptType: _scan(scans, scriptType),
    };
  }

  Future<Result<MnemonicScan, ImportMnemonicScanFailure>> _scan(
    Future<Map<ScriptType, Future<MnemonicScan>>> scans,
    ScriptType scriptType,
  ) async {
    try {
      final scan = (await scans)[scriptType];
      if (scan == null) {
        return const Err(
          ImportMnemonicScanUnexpectedFailure('No scan for the script type'),
        );
      }
      return Ok(await scan);
    } catch (e) {
      final failure = _failureOf(e);
      log.warning(
        'Pre-import scan failed for ${scriptType.name}: '
        '${_failureCode(failure)}',
      );
      return Err(failure);
    }
  }

  static String _failureCode(ImportMnemonicScanFailure failure) =>
      switch (failure) {
        ImportMnemonicScanServerUnavailableFailure() => 'server_unavailable',
        ImportMnemonicScanTimeoutFailure() => 'timeout',
        ImportMnemonicScanInvalidMnemonicFailure() => 'invalid_mnemonic',
        ImportMnemonicScanUnexpectedFailure() => 'unexpected',
      };

  /// Keeps the kind of [error] only: its message may name a server, a descriptor or a word.
  static ImportMnemonicScanFailure _failureOf(Object error) => switch (error) {
    CheckWalletStatusInvalidMnemonicException() =>
      const ImportMnemonicScanInvalidMnemonicFailure(),
    TimeoutException() => const ImportMnemonicScanTimeoutFailure(),
    AllElectrumServersFailedException(:final attempts)
        when attempts.isNotEmpty &&
            attempts.every((a) => a.error is TimeoutException) =>
      const ImportMnemonicScanTimeoutFailure(),
    ElectrumFallbackException() =>
      const ImportMnemonicScanServerUnavailableFailure(),
    _ => ImportMnemonicScanUnexpectedFailure('${error.runtimeType}'),
  };
}
