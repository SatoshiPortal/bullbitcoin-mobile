import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/errors/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/get_ledger_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/sign_psbt_ledger_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/watch_only_wallet_entity.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockLedgerDeviceRepository extends Mock
    implements LedgerDeviceRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

void main() {
  late _MockLedgerDeviceRepository repository;
  late _MockSettingsRepository settingsRepository;

  const device = LedgerDeviceEntity(
    id: 'device-1',
    name: 'Nano X',
    connectionType: LedgerConnectionType.usb,
    deviceType: SignerDeviceEntity.ledgerNanoX,
  );

  setUpAll(() {
    registerFallbackValue(device);
    registerFallbackValue(ScriptType.bip84);
  });

  setUp(() {
    repository = _MockLedgerDeviceRepository();
    settingsRepository = _MockSettingsRepository();
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
    GetLedgerWatchOnlyWalletUsecase buildUsecase() =>
        GetLedgerWatchOnlyWalletUsecase(
          repository: repository,
          settingsRepository: settingsRepository,
        );

    void stubSettings() {
      when(() => settingsRepository.fetch()).thenAnswer(
        (_) async => SettingsEntity(
          environment: Environment.mainnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      );
    }

    test('forwards a repository failure unchanged (no raw leak)', () async {
      final usecase = buildUsecase();
      stubSettings();
      when(
        () => repository.getMasterFingerprint(any()),
      ).thenAnswer((_) async => const Err(LedgerDeviceLockedFailure()));

      final result = await usecase.execute(label: 'Ledger', device: device);

      expect(result, isA<Err<WatchOnlyWalletEntity, LedgerFailure>>());
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

    test('sanitizes a throwing settings fetch into an unexpected failure '
        'without touching the device', () async {
      final usecase = buildUsecase();
      when(
        () => settingsRepository.fetch(),
      ).thenThrow(Exception('STORAGE UNAVAILABLE'));

      final result = await usecase.execute(label: 'Ledger', device: device);

      expect((result as Err).failure, isA<LedgerUnexpectedFailure>());
      verifyNever(() => repository.getMasterFingerprint(any()));
    });
  });
}
