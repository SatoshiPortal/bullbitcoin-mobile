import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/errors/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/get_ledger_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/sign_psbt_ledger_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
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
    deviceType: SignerDeviceEntity.ledgerNanoX,
  );

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
        psbt: 'psbt',
        derivationPath: "m/84'/0'/0'",
        scriptType: ScriptType.bip84,
      );

      expect((result as Err).failure, isA<LedgerRejectedByUserFailure>());
    });
  });

  group('GetLedgerWatchOnlyWalletUsecase', () {
    test('forwards the repository failure unchanged (no raw leak)', () async {
      final usecase = GetLedgerWatchOnlyWalletUsecase(repository: repository);
      when(
        () => repository.getWatchOnlyWallet(
          any(),
          label: any(named: 'label'),
          scriptType: any(named: 'scriptType'),
          account: any(named: 'account'),
        ),
      ).thenAnswer((_) async => const Err(LedgerUnexpectedFailure('raw boom')));

      final result = await usecase.execute(label: 'Ledger', device: device);

      expect(result, isA<Err<WatchOnlyWalletEntity, LedgerFailure>>());
      expect((result as Err).failure, isA<LedgerUnexpectedFailure>());
    });
  });
}
