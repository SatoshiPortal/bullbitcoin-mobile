import 'package:signers/src/signer_device.dart';
import 'package:signers/src/ledger/domain/entities/ledger_device_entity.dart';
import 'package:signers/src/ledger/domain/ledger_failure.dart';
import 'package:signers/src/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:signers/src/ledger_flow/domain/read_ledger_account_usecase.dart';
import 'package:signers/src/ledger/domain/usecases/sign_psbt_ledger_usecase.dart';
import 'package:primitives/primitives.dart'
    show NetworkEnv, Err, Ok, ScriptType;
import 'package:signers/src/ledger/domain/usecases/verify_address_ledger_usecase.dart';
import 'package:signers/src/ledger_flow/domain/signer_account.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLedgerDeviceRepository extends Mock
    implements LedgerDeviceRepository {}

void main() {
  late _MockLedgerDeviceRepository repository;

  const device = LedgerDeviceEntity(
    id: 'device-1',
    name: 'Nano X',
    connectionType: LedgerConnectionType.usb,
    deviceType: SignerDevice.ledgerNanoX,
  );

  setUpAll(() {
    registerFallbackValue(device);
    registerFallbackValue(ScriptType.bip84);
  });

  setUp(() {
    repository = _MockLedgerDeviceRepository();
  });

  group('SignPsbtLedgerUsecase', () {
    test('forwards the repository failure unchanged (no raw leak)', () async {
      final usecase = SignPsbtLedgerUsecase(repository: repository);
      when(
        () => repository.signPsbt(
          any(),
          psbt: any(named: 'psbt'),
          derivationPath: any(named: 'derivationPath'),
          scriptType: any(named: 'scriptType'),
        ),
      ).thenAnswer((_) async => const Err(LedgerRejectedByUserFailure()));

      final result = await usecase.execute(
        device,
        network: NetworkEnv.mainnet,
        psbt: 'psbt',
        derivationPath: "m/84'/0'/0'",
        scriptType: ScriptType.bip84,
      );

      expect((result as Err).failure, isA<LedgerRejectedByUserFailure>());
    });
  });

  test('address mismatch is a failure, never verification success', () async {
    when(
      () => repository.verifyAddress(
        device,
        address: 'requested-address',
        derivationPath: "m/84'/0'/0'/0/0",
        scriptType: ScriptType.bip84,
      ),
    ).thenAnswer((_) async => const Ok(false));
    final result = await VerifyAddressLedgerUsecase(repository: repository)
        .execute(
          device: device,
          address: 'requested-address',
          network: NetworkEnv.mainnet,
          derivationPath: "m/84'/0'/0'/0/0",
          scriptType: ScriptType.bip84,
        );
    expect(result, isA<Err<bool, LedgerFailure>>());
  });

  group('ReadLedgerAccountUsecase', () {
    ReadLedgerAccountUsecase buildUsecase() =>
        ReadLedgerAccountUsecase(repository: repository);

    test('forwards a repository failure unchanged (no raw leak)', () async {
      final usecase = buildUsecase();
      when(() => repository.getMasterFingerprint(any()))
          .thenAnswer((_) async => const Err(LedgerDeviceLockedFailure()));

      final result = await usecase.execute(
        network: NetworkEnv.mainnet,
        device: device,
      );

      expect(result, isA<Err<SignerAccount, LedgerFailure>>());
      expect((result as Err).failure, isA<LedgerDeviceLockedFailure>());
      // The xpub step must not run once the fingerprint step fails.
      verifyNever(
        () => repository.getXpub(
          any(),
          derivationPath: any(named: 'derivationPath'),
          scriptType: any(named: 'scriptType'),
        ),
      );
    });

    test('refuses regtest before reading the device', () async {
      final result = await buildUsecase().execute(
        network: NetworkEnv.regtest,
        device: device,
      );
      expect((result as Err).failure, isA<LedgerUnexpectedFailure>());
      verifyZeroInteractions(repository);
    });
  });
}
