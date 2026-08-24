import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/ledger/data/datasources/ledger_device_datasource.dart';
import 'package:bb_mobile/core/ledger/data/models/ledger_device_model.dart';
import 'package:bb_mobile/core/ledger/data/repositories/ledger_device_repository_impl.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/data/ledger_exception.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLedgerDeviceDatasource extends Mock
    implements LedgerDeviceDatasource {}

void main() {
  late _MockLedgerDeviceDatasource datasource;
  late LedgerDeviceRepositoryImpl repository;

  const device = LedgerDeviceEntity(
    id: 'device-1',
    name: 'Nano X',
    connectionType: LedgerConnectionType.usb,
    deviceType: SignerDeviceEntity.ledgerNanoX,
  );

  setUpAll(() {
    registerFallbackValue(device.toModel());
    registerFallbackValue(ScriptType.bip84);
  });

  setUp(() {
    datasource = _MockLedgerDeviceDatasource();
    repository = LedgerDeviceRepositoryImpl(datasource: datasource);
  });

  group('LedgerDeviceRepositoryImpl (scan policy)', () {
    test('turns an empty scan into a no-devices failure', () async {
      when(
        () => datasource.scanDevices(deviceType: any(named: 'deviceType')),
      ).thenAnswer((_) async => <LedgerDeviceModel>[]);

      final result = await repository.scanDevices();

      expect((result as Err).failure, isA<LedgerNoDevicesFoundFailure>());
    });

    test('turns an ambiguous scan into a multiple-devices failure', () async {
      when(
        () => datasource.scanDevices(deviceType: any(named: 'deviceType')),
      ).thenAnswer(
        (_) async => [
          device.toModel(),
          device.copyWith(id: 'device-2').toModel(),
        ],
      );

      final result = await repository.scanDevices();

      expect((result as Err).failure, isA<LedgerMultipleDevicesFoundFailure>());
    });

    test('returns the single device on an unambiguous scan', () async {
      when(
        () => datasource.scanDevices(deviceType: any(named: 'deviceType')),
      ).thenAnswer((_) async => [device.toModel()]);

      final result = await repository.scanDevices();

      expect(result, isA<Ok<List<LedgerDeviceEntity>, LedgerFailure>>());
      expect((result as Ok).value, hasLength(1));
    });
  });

  group('LedgerDeviceRepositoryImpl (the sanitization boundary)', () {
    test('maps an uninitialized transport to a no-connection failure, '
        'not a generic one', () async {
      when(
        () => datasource.connectDevice(any()),
      ).thenThrow(const ConnectionTypeNotInitializedLedgerException());

      final result = await repository.connectDevice(device);

      expect((result as Err).failure, isA<LedgerNoConnectionFailure>());
    });

    test('maps a semantic LedgerException to its typed failure', () async {
      when(
        () => datasource.connectDevice(any()),
      ).thenThrow(const PermissionDeniedLedgerException());

      final result = await repository.connectDevice(device);

      expect(result, isA<Err<Null, LedgerFailure>>());
      expect((result as Err).failure, isA<LedgerPermissionDeniedFailure>());
    });

    test('interprets a raw APDU 6985 device string as rejected-by-user, '
        'keeping the raw reason for logs only', () async {
      when(
        () => datasource.signPsbt(
          any(),
          psbt: any(named: 'psbt'),
          derivationPath: any(named: 'derivationPath'),
          scriptType: any(named: 'scriptType'),
        ),
      ).thenThrow(Exception('Ledger error: 0x6985 rejected'));

      final result = await repository.signPsbt(
        device,
        psbt: 'psbt',
        derivationPath: "m/84'/0'/0'",
        scriptType: ScriptType.bip84,
      );

      final failure = (result as Err).failure;
      expect(failure, isA<LedgerRejectedByUserFailure>());
      // The raw reason is retained for logs/Sentry, never rendered by the UI.
      expect(failure.logMessage, contains('6985'));
    });

    test('does not mistake an unlabelled 4-digit run for an APDU status word, '
        'so an unrelated message cannot show a wrong reason', () async {
      when(
        () => datasource.signPsbt(
          any(),
          psbt: any(named: 'psbt'),
          derivationPath: any(named: 'derivationPath'),
          scriptType: any(named: 'scriptType'),
        ),
      ).thenThrow(Exception('transport timeout after 6985 ms'));

      final result = await repository.signPsbt(
        device,
        psbt: 'psbt',
        derivationPath: "m/84'/0'/0'",
        scriptType: ScriptType.bip84,
      );

      // '6985' here is a duration, not a status word: reading it as one would
      // tell the user they rejected the operation on the device.
      final failure = (result as Err).failure;
      expect(failure, isA<LedgerUnexpectedFailure>());
      expect(failure, isNot(isA<LedgerRejectedByUserFailure>()));
    });

    test(
      'still recognizes a keyword-labelled status word without 0x',
      () async {
        when(
          () => datasource.signPsbt(
            any(),
            psbt: any(named: 'psbt'),
            derivationPath: any(named: 'derivationPath'),
            scriptType: any(named: 'scriptType'),
          ),
        ).thenThrow(Exception('ledger responded sw=5515'));

        final result = await repository.signPsbt(
          device,
          psbt: 'psbt',
          derivationPath: "m/84'/0'/0'",
          scriptType: ScriptType.bip84,
        );

        expect((result as Err).failure, isA<LedgerDeviceLockedFailure>());
      },
    );

    test('maps an unrecognized raw exception to a sanitized unexpected failure '
        'without leaking the message to the UI surface', () async {
      when(
        () => datasource.signPsbt(
          any(),
          psbt: any(named: 'psbt'),
          derivationPath: any(named: 'derivationPath'),
          scriptType: any(named: 'scriptType'),
        ),
      ).thenThrow(Exception('bdk: internal descriptor parse blew up'));

      final result = await repository.signPsbt(
        device,
        psbt: 'psbt',
        derivationPath: "m/84'/0'/0'",
        scriptType: ScriptType.bip84,
      );

      expect((result as Err).failure, isA<LedgerUnexpectedFailure>());
    });

    test('returns Ok with the value on success', () async {
      when(
        () => datasource.signPsbt(
          any(),
          psbt: any(named: 'psbt'),
          derivationPath: any(named: 'derivationPath'),
          scriptType: any(named: 'scriptType'),
        ),
      ).thenAnswer((_) async => 'deadbeef');

      final result = await repository.signPsbt(
        device,
        psbt: 'psbt',
        derivationPath: "m/84'/0'/0'",
        scriptType: ScriptType.bip84,
      );

      expect(result, isA<Ok<String, LedgerFailure>>());
      expect((result as Ok).value, 'deadbeef');
    });

    test('getMasterFingerprint returns Ok with the datasource value', () async {
      when(
        () => datasource.getMasterFingerprint(any()),
      ).thenAnswer((_) async => 'abcd1234');

      final result = await repository.getMasterFingerprint(device);

      expect(result, isA<Ok<String, LedgerFailure>>());
      expect((result as Ok).value, 'abcd1234');
    });

    test(
      'getXpub sanitizes a raw datasource throw into a typed failure',
      () async {
        when(
          () => datasource.getXpub(
            any(),
            derivationPath: any(named: 'derivationPath'),
            scriptType: any(named: 'scriptType'),
          ),
        ).thenThrow(Exception('bdk: xpub derivation blew up'));

        final result = await repository.getXpub(
          device,
          derivationPath: "m/84'/0'/0'",
          scriptType: ScriptType.bip84,
        );

        expect((result as Err).failure, isA<LedgerUnexpectedFailure>());
      },
    );
  });
}
