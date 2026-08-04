import 'dart:async';

import 'package:bb_mobile/core/nfc/data/nfc_error_mapper.dart';
import 'package:bb_mobile/core/nfc/data/nfc_kit_datasource.dart';
import 'package:bb_mobile/core/nfc/domain/nfc_failure.dart';
import 'package:bb_mobile/core/nfc/domain/nfc_session.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/core/utils/nfc_payload_parser.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart'
    show NFCAvailability, NFCTag;
import 'package:ndef/ndef.dart' as ndef;
import 'package:synchronized/synchronized.dart';

sealed class _StepOutcome<T> {
  const _StepOutcome();
}

final class _StepValue<T> extends _StepOutcome<T> {
  const _StepValue(this.value);

  final T value;
}

final class _StepFailure<T> extends _StepOutcome<T> {
  const _StepFailure(this.failure);

  final NfcFailure failure;
}

final class NfcSessionImpl implements NfcSession {
  NfcSessionImpl({required this._kit, required this._isIOS});

  static const pollTimeout = Duration(seconds: 15);
  static const androidPollWatchdog = Duration(seconds: 20);
  static const iosPollWatchdog = Duration(seconds: 75);
  static const transferWatchdog = Duration(seconds: 30);
  static const finishWatchdog = Duration(seconds: 3);
  static const iosRetryAttempts = 3;

  final NfcKitDatasource _kit;
  final bool _isIOS;
  final Lock _lock = Lock();

  bool _inProgress = false;
  int _generation = 0;
  Completer<NfcFailure>? _cancelSignal;

  @override
  Future<Result<String, NfcFailure>> readPayload({
    required String iosAlertMessage,
    required String iosTagLostMessage,
  }) => _read(
    parse: payloadFromNdefRecords,
    label: 'read',
    iosAlertMessage: iosAlertMessage,
    iosTagLostMessage: iosTagLostMessage,
  );

  @override
  Future<Result<String, NfcFailure>> readPushTxUri({
    required String iosAlertMessage,
    required String iosTagLostMessage,
  }) => _read(
    parse: pushTxUriFromNdefRecords,
    label: 'read-pushtx',
    iosAlertMessage: iosAlertMessage,
    iosTagLostMessage: iosTagLostMessage,
  );

  @override
  Future<Result<void, NfcFailure>> writeText({
    required String data,
    required String iosAlertMessage,
    required String iosErrorMessage,
  }) async {
    final result = await _withSession<bool>(
      label: 'write',
      iosAlertMessage: iosAlertMessage,
      iosFailureMessage: iosErrorMessage,
      isWrite: true,
      transfer: (signal) => _guard<bool>(
        step: () async {
          await _kit.writeTextRecord(data);
          return true;
        },
        signal: signal,
        isWrite: true,
        watchdog: transferWatchdog,
        label: 'write records',
      ),
    );

    return switch (result) {
      Ok() => const Ok<void, NfcFailure>(null),
      Err(:final failure) => Err<void, NfcFailure>(failure),
    };
  }

  @override
  Future<void> cancel() async {
    final signal = _cancelSignal;
    if (!_inProgress || signal == null || signal.isCompleted) {
      log.warning('nfc cancel skipped: no active operation');
      return;
    }

    log.warning('nfc op #$_generation cancelled by caller');
    signal.complete(const NfcCancelledFailure());
  }

  Future<Result<String, NfcFailure>> _read({
    required String? Function(List<ndef.NDEFRecord> records) parse,
    required String label,
    required String iosAlertMessage,
    required String iosTagLostMessage,
  }) => _withSession<String>(
    label: label,
    iosAlertMessage: iosAlertMessage,
    iosFailureMessage: iosTagLostMessage,
    isWrite: false,
    transfer: (signal) => _readRecords(
      parse: parse,
      signal: signal,
      label: label,
      iosTagLostMessage: iosTagLostMessage,
    ),
  );

  Future<Result<T, NfcFailure>> _withSession<T>({
    required String label,
    required String iosAlertMessage,
    required String iosFailureMessage,
    required bool isWrite,
    required Future<Result<T, NfcFailure>> Function(
      Completer<NfcFailure> signal,
    )
    transfer,
  }) async {
    if (_inProgress) {
      log.warning('nfc $label rejected: another operation is in progress');
      return Err<T, NfcFailure>(const NfcBusyFailure());
    }

    return _lock.synchronized(() async {
      final generation = ++_generation;
      final signal = Completer<NfcFailure>();
      final startedAt = DateTime.now();
      _inProgress = true;
      _cancelSignal = signal;
      log.warning('nfc op #$generation $label starting');

      try {
        final availabilityFailure = await _availabilityFailure(
          generation,
          label,
        );
        if (availabilityFailure != null) {
          return Err<T, NfcFailure>(availabilityFailure);
        }

        Result<T, NfcFailure>? result;
        try {
          final pollFailure = await _poll(
            iosAlertMessage: iosAlertMessage,
            signal: signal,
            generation: generation,
          );
          result = pollFailure != null
              ? Err<T, NfcFailure>(pollFailure)
              : await transfer(signal);
          return result;
        } finally {
          await _finish(
            iosErrorMessage: _iosErrorMessage(
              _failureOf(result),
              iosFailureMessage,
            ),
          );
        }
      } finally {
        _inProgress = false;
        _cancelSignal = null;
        final elapsed = DateTime.now().difference(startedAt).inMilliseconds;
        log.warning('nfc op #$generation $label ended after ${elapsed}ms');
      }
    });
  }

  Future<NfcFailure?> _availabilityFailure(int generation, String label) async {
    try {
      final availability = await _kit.availability();
      return switch (availability) {
        NFCAvailability.available => null,
        NFCAvailability.disabled => const NfcDisabledFailure(),
        NFCAvailability.not_supported => const NfcUnsupportedFailure(),
      };
    } catch (e) {
      log.warning('nfc op #$generation $label availability failed', error: e);
      return nfcFailureFromError(e, isWrite: false);
    }
  }

  Future<NfcFailure?> _poll({
    required String iosAlertMessage,
    required Completer<NfcFailure> signal,
    required int generation,
  }) async {
    final outcome = await _guard<NFCTag>(
      step: () =>
          _kit.poll(timeout: pollTimeout, iosAlertMessage: iosAlertMessage),
      signal: signal,
      isWrite: false,
      watchdog: _isIOS ? iosPollWatchdog : androidPollWatchdog,
      label: 'op #$generation poll',
    );

    return switch (outcome) {
      Ok() => null,
      Err(:final failure) => failure,
    };
  }

  Future<Result<String, NfcFailure>> _readRecords({
    required String? Function(List<ndef.NDEFRecord> records) parse,
    required Completer<NfcFailure> signal,
    required String label,
    required String iosTagLostMessage,
  }) async {
    final attempts = _isIOS ? iosRetryAttempts : 1;

    for (var attempt = 1; attempt <= attempts; attempt++) {
      final records = await _guard<List<ndef.NDEFRecord>>(
        step: _kit.readNdefRecords,
        signal: signal,
        isWrite: false,
        watchdog: transferWatchdog,
        label: '$label records',
      );

      switch (records) {
        case Ok(:final value):
          final payload = parse(value);
          if (payload == null || payload.isEmpty) {
            return const Err(NfcInvalidPayloadFailure());
          }
          return Ok<String, NfcFailure>(payload);
        case Err(:final failure):
          if (failure is! NfcTagLostFailure || attempt == attempts) {
            return Err<String, NfcFailure>(failure);
          }
          final restarted = await _restartIosPolling(iosTagLostMessage);
          if (!restarted) return Err<String, NfcFailure>(failure);
      }
    }

    return const Err(NfcTagLostFailure());
  }

  Future<Result<T, NfcFailure>> _guard<T>({
    required Future<T> Function() step,
    required Completer<NfcFailure> signal,
    required bool isWrite,
    required Duration watchdog,
    required String label,
  }) async {
    try {
      final outcome =
          await Future.any<_StepOutcome<T>>([
            step().then<_StepOutcome<T>>(_StepValue<T>.new),
            signal.future.then<_StepOutcome<T>>(_StepFailure<T>.new),
          ]).timeout(
            watchdog,
            onTimeout: () {
              log.warning(
                'nfc $label watchdog tripped after '
                '${watchdog.inMilliseconds}ms, platform never replied',
              );
              return const _StepFailure(NfcTimeoutFailure());
            },
          );

      return switch (outcome) {
        _StepValue<T>(:final value) => Ok<T, NfcFailure>(value),
        _StepFailure<T>(:final failure) => Err<T, NfcFailure>(failure),
      };
    } catch (e) {
      final failure = nfcFailureFromError(e, isWrite: isWrite);
      log.warning('nfc $label failed as ${failure.runtimeType}', error: e);
      return Err<T, NfcFailure>(failure);
    }
  }

  Future<bool> _restartIosPolling(String message) async {
    try {
      await _kit.setIosAlertMessage(message);
      await _kit.iosRestartPolling();
      return true;
    } catch (e) {
      log.warning('nfc restart polling failed', error: e);
      return false;
    }
  }

  Future<void> _finish({String? iosErrorMessage}) async {
    try {
      await _kit
          .finish(iosErrorMessage: iosErrorMessage)
          .timeout(finishWatchdog);
    } catch (e) {
      log.warning('nfc finish failed', error: e);
    }
  }

  NfcFailure? _failureOf<T>(Result<T, NfcFailure>? result) => switch (result) {
    null => null,
    Ok() => null,
    Err(:final failure) => failure,
  };

  String? _iosErrorMessage(NfcFailure? failure, String iosFailureMessage) {
    if (!_isIOS || failure == null || failure is NfcCancelledFailure) {
      return null;
    }
    return iosFailureMessage;
  }
}
