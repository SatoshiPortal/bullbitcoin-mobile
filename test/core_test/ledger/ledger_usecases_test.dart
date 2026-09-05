import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/entities/ledger_device_entity.dart';
import 'package:bb_mobile/core/ledger/domain/ledger_failure.dart';
import 'package:bb_mobile/core/ledger/domain/repositories/ledger_device_repository.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/get_ledger_watch_only_wallet_usecase.dart';
import 'package:bb_mobile/core/ledger/domain/usecases/get_ledger_account_key_usecase.dart';
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

  test('reads the requested account key with its verified origin', () async {
    const path = "m/48'/1'/0'/2'";
    const xpub =
        'tpubDFH9dgzveyD8zTbPUFuLrGmCydNvxehyNdUXKJAQN8x4aZ4j6UZqGfnqFrD4NqyaTVGKbvEW54tsvPTK2UoSbCC1PJY8iCNiwTL3RWZEheQ';
    final usecase = GetLedgerAccountKeyUsecase(repository);
    when(
      () => repository.getMasterFingerprint(device),
    ).thenAnswer((_) async => const Ok('AABBCCDD'));
    when(
      () => repository.getXpub(
        device,
        derivationPath: path,
        scriptType: ScriptType.bip44,
      ),
    ).thenAnswer((_) async => const Ok(xpub));

    final result = await usecase.execute(device: device, derivationPath: path);

    expect(result, isA<Ok>());
    expect((result as Ok).value, '[aabbccdd/48\'/1\'/0\'/2\']$xpub');
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
