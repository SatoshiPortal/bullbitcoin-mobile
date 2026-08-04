import 'dart:async';

import 'package:bb_mobile/core/nfc/data/nfc_kit_datasource.dart';
import 'package:bb_mobile/core/nfc/data/nfc_session_impl.dart';
import 'package:bb_mobile/core/nfc/domain/nfc_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/services.dart';
import 'package:flutter_nfc_kit/flutter_nfc_kit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ndef/ndef.dart' as ndef;

class _MockNfcKitDatasource extends Mock implements NfcKitDatasource {}

class _MockNfcTag extends Mock implements NFCTag {}

void main() {
  late _MockNfcKitDatasource kit;
  late _MockNfcTag tag;

  const alertMessage = 'Hold your phone near the Coldcard';
  const tagLostMessage = 'NFC connection lost';
  const writeFailedMessage = 'NFC transfer failed';

  NfcFailure? failureOf<T>(Result<T, NfcFailure> result) => switch (result) {
    Ok() => null,
    Err(:final failure) => failure,
  };

  T? valueOf<T>(Result<T, NfcFailure> result) => switch (result) {
    Ok(:final value) => value,
    Err() => null,
  };

  void stubPollSuccess() {
    when(
      () => kit.poll(
        timeout: any(named: 'timeout'),
        iosAlertMessage: any(named: 'iosAlertMessage'),
      ),
    ).thenAnswer((_) async => tag);
  }

  void stubPollThrows(Object error) {
    when(
      () => kit.poll(
        timeout: any(named: 'timeout'),
        iosAlertMessage: any(named: 'iosAlertMessage'),
      ),
    ).thenThrow(error);
  }

  setUpAll(() => registerFallbackValue(Duration.zero));

  setUp(() {
    kit = _MockNfcKitDatasource();
    tag = _MockNfcTag();

    when(
      () => kit.availability(),
    ).thenAnswer((_) async => NFCAvailability.available);
    stubPollSuccess();
    when(
      () => kit.readNdefRecords(),
    ).thenAnswer((_) async => [ndef.TextRecord(text: 'payload')]);
    when(() => kit.writeTextRecord(any())).thenAnswer((_) async {});
    when(
      () => kit.finish(iosErrorMessage: any(named: 'iosErrorMessage')),
    ).thenAnswer((_) async {});
    when(() => kit.setIosAlertMessage(any())).thenAnswer((_) async {});
    when(() => kit.iosRestartPolling()).thenAnswer((_) async {});
  });

  NfcSessionImpl newSession({bool isIOS = false}) =>
      NfcSessionImpl(kit: kit, isIOS: isIOS);

  Future<Result<String, NfcFailure>> read(NfcSessionImpl session) =>
      session.readPayload(
        iosAlertMessage: alertMessage,
        iosTagLostMessage: tagLostMessage,
      );

  Future<Result<void, NfcFailure>> write(NfcSessionImpl session) =>
      session.writeText(
        data: 'cHNidP8B',
        iosAlertMessage: alertMessage,
        iosErrorMessage: writeFailedMessage,
      );

  void verifyFinishedOnce() {
    verify(
      () => kit.finish(iosErrorMessage: any(named: 'iosErrorMessage')),
    ).called(1);
  }

  group('read', () {
    test('returns the payload and closes the session in order', () async {
      final result = await read(newSession());

      expect(valueOf(result), 'payload');
      verifyInOrder([
        () => kit.availability(),
        () => kit.poll(
          timeout: NfcSessionImpl.pollTimeout,
          iosAlertMessage: alertMessage,
        ),
        () => kit.readNdefRecords(),
        () => kit.finish(iosErrorMessage: any(named: 'iosErrorMessage')),
      ]);
    });

    test(
      'passes the explicit poll timeout rather than the plugin default',
      () async {
        await read(newSession());

        final captured = verify(
          () => kit.poll(
            timeout: captureAny(named: 'timeout'),
            iosAlertMessage: any(named: 'iosAlertMessage'),
          ),
        ).captured.single;

        expect(captured, NfcSessionImpl.pollTimeout);
        expect(NfcSessionImpl.pollTimeout.inSeconds, lessThan(20));
      },
    );

    test('reports an unsupported payload when nothing parses', () async {
      when(() => kit.readNdefRecords()).thenAnswer((_) async => []);

      final result = await read(newSession());

      expect(failureOf(result), isA<NfcInvalidPayloadFailure>());
      verifyFinishedOnce();
    });
  });

  group('session is always closed', () {
    test('when polling times out', () async {
      stubPollThrows(
        PlatformException(code: '408', message: 'Polling tag timeout'),
      );

      final result = await read(newSession());

      expect(failureOf(result), isA<NfcTimeoutFailure>());
      verifyFinishedOnce();
    });

    test('when the user cancels', () async {
      stubPollThrows(
        PlatformException(code: '409', message: 'Session invalidated by user'),
      );

      final result = await read(newSession());

      expect(failureOf(result), isA<NfcCancelledFailure>());
      verifyFinishedOnce();
    });

    test('when the tag is removed mid read', () async {
      when(() => kit.readNdefRecords()).thenThrow(
        PlatformException(code: '503', message: 'Tag already removed'),
      );

      final result = await read(newSession());

      expect(failureOf(result), isA<NfcTagLostFailure>());
      verifyFinishedOnce();
    });

    test('when the write fails', () async {
      when(
        () => kit.writeTextRecord(any()),
      ).thenThrow(PlatformException(code: '500', message: 'Write NDEF error'));

      final result = await write(newSession());

      expect(failureOf(result), isA<NfcWriteFailure>());
      verifyFinishedOnce();
    });

    test('when the tag does not support ndef', () async {
      when(() => kit.readNdefRecords()).thenThrow(
        PlatformException(code: '405', message: 'NDEF not supported'),
      );

      final result = await read(newSession());

      expect(failureOf(result), isA<NfcUnsupportedTagFailure>());
      verifyFinishedOnce();
    });
  });

  group('no session is opened', () {
    test('when nfc is turned off', () async {
      when(
        () => kit.availability(),
      ).thenAnswer((_) async => NFCAvailability.disabled);

      final result = await read(newSession());

      expect(failureOf(result), isA<NfcDisabledFailure>());
      verifyNever(
        () => kit.poll(
          timeout: any(named: 'timeout'),
          iosAlertMessage: any(named: 'iosAlertMessage'),
        ),
      );
      verifyNever(
        () => kit.finish(iosErrorMessage: any(named: 'iosErrorMessage')),
      );
    });

    test('when the device has no nfc hardware', () async {
      when(
        () => kit.availability(),
      ).thenAnswer((_) async => NFCAvailability.not_supported);

      final result = await read(newSession());

      expect(failureOf(result), isA<NfcUnsupportedFailure>());
      verifyNever(
        () => kit.poll(
          timeout: any(named: 'timeout'),
          iosAlertMessage: any(named: 'iosAlertMessage'),
        ),
      );
      verifyNever(
        () => kit.finish(iosErrorMessage: any(named: 'iosErrorMessage')),
      );
    });
  });

  test('a second scan cannot overlap the first, and a timeout self heals', () {
    fakeAsync((async) {
      final pending = Completer<NFCTag>();
      when(
        () => kit.poll(
          timeout: any(named: 'timeout'),
          iosAlertMessage: any(named: 'iosAlertMessage'),
        ),
      ).thenAnswer((_) => pending.future);

      final session = newSession();

      Result<String, NfcFailure>? first;
      read(session).then((result) => first = result);
      async.flushMicrotasks();

      Result<String, NfcFailure>? second;
      read(session).then((result) => second = result);
      async.flushMicrotasks();

      expect(failureOf(second!), isA<NfcBusyFailure>());
      expect(first, isNull);
      verify(
        () => kit.poll(
          timeout: any(named: 'timeout'),
          iosAlertMessage: any(named: 'iosAlertMessage'),
        ),
      ).called(1);

      async.elapse(NfcSessionImpl.androidPollWatchdog);
      async.flushMicrotasks();

      expect(failureOf(first!), isA<NfcTimeoutFailure>());
      verifyFinishedOnce();

      stubPollSuccess();

      Result<String, NfcFailure>? third;
      read(session).then((result) => third = result);
      async.elapse(const Duration(seconds: 1));

      expect(valueOf(third!), 'payload');
    });
  });

  test('a hung close cannot deadlock the next scan', () {
    fakeAsync((async) {
      when(
        () => kit.finish(iosErrorMessage: any(named: 'iosErrorMessage')),
      ).thenAnswer((_) => Completer<void>().future);

      final session = newSession();

      Result<String, NfcFailure>? first;
      read(session).then((result) => first = result);
      async.elapse(NfcSessionImpl.finishWatchdog);
      async.flushMicrotasks();

      expect(valueOf(first!), 'payload');

      Result<String, NfcFailure>? second;
      read(session).then((result) => second = result);
      async.elapse(NfcSessionImpl.finishWatchdog);
      async.flushMicrotasks();

      expect(valueOf(second!), 'payload');
      verify(
        () => kit.poll(
          timeout: any(named: 'timeout'),
          iosAlertMessage: any(named: 'iosAlertMessage'),
        ),
      ).called(2);
    });
  });

  group('cancel', () {
    test('ends an in flight scan and closes the session once', () {
      fakeAsync((async) {
        when(
          () => kit.poll(
            timeout: any(named: 'timeout'),
            iosAlertMessage: any(named: 'iosAlertMessage'),
          ),
        ).thenAnswer((_) => Completer<NFCTag>().future);

        final session = newSession();

        Result<String, NfcFailure>? result;
        read(session).then((value) => result = value);
        async.flushMicrotasks();

        session.cancel();
        async.flushMicrotasks();

        expect(failureOf(result!), isA<NfcCancelledFailure>());
        verifyFinishedOnce();
      });
    });

    test('is ignored when no scan is running', () async {
      final session = newSession();

      await session.cancel();

      verifyNever(
        () => kit.finish(iosErrorMessage: any(named: 'iosErrorMessage')),
      );
    });

    test('does not touch a later scan', () async {
      final session = newSession();

      await read(session);
      await session.cancel();

      verifyFinishedOnce();
    });
  });

  group('ios tag lost retry', () {
    test('restarts polling and succeeds on a later attempt', () async {
      var attempts = 0;
      when(() => kit.readNdefRecords()).thenAnswer((_) async {
        attempts++;
        if (attempts < 3) {
          throw PlatformException(code: '500', message: 'Read NDEF error');
        }
        return [ndef.TextRecord(text: 'payload')];
      });

      final result = await read(newSession(isIOS: true));

      expect(valueOf(result), 'payload');
      verify(() => kit.iosRestartPolling()).called(2);
      verify(() => kit.setIosAlertMessage(tagLostMessage)).called(2);
      verifyFinishedOnce();
    });

    test('gives up after the bounded attempts', () async {
      when(
        () => kit.readNdefRecords(),
      ).thenThrow(PlatformException(code: '500', message: 'Read NDEF error'));

      final result = await read(newSession(isIOS: true));

      expect(failureOf(result), isA<NfcTagLostFailure>());
      verify(
        () => kit.iosRestartPolling(),
      ).called(NfcSessionImpl.iosRetryAttempts - 1);

      final captured = verify(
        () => kit.finish(iosErrorMessage: captureAny(named: 'iosErrorMessage')),
      ).captured.single;
      expect(captured, tagLostMessage);
    });

    test('does not retry on android', () async {
      when(
        () => kit.readNdefRecords(),
      ).thenThrow(PlatformException(code: '500', message: 'Read NDEF error'));

      final result = await read(newSession());

      expect(failureOf(result), isA<NfcTagLostFailure>());
      verifyNever(() => kit.iosRestartPolling());
    });
  });
}
