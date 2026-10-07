import 'package:bull_recoverbull/bull_recoverbull.dart';
import 'package:bb_mobile/core/settings/domain/repositories/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/check_backup_needed_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletRepository extends Mock implements WalletRepository {}

class _MockSettingsRepository extends Mock implements SettingsRepository {}

class _MockSettings extends Mock implements SettingsEntity {}

class _MockWallet extends Mock implements Wallet {}

/// Drives the "back up your wallet" banner on the home screen.
///
/// The failure path matters more than the happy one here: a read that fails
/// must not be reported as "no backup needed", which would silently hide the
/// banner from a user who genuinely has an unbacked-up wallet.
void main() {
  late _MockWalletRepository walletRepository;
  late _MockSettingsRepository settingsRepository;
  late CheckBackupNeededUsecase usecase;
  late RecoverBullStatus status;
  late Environment environment;
  late List<RecoverBullNetwork> askedNetworks;

  _MockWallet wallet({required bool physicalTested}) {
    final w = _MockWallet();
    when(() => w.isPhysicalBackupTested).thenReturn(physicalTested);
    return w;
  }

  void stubWallets(Result<List<Wallet>, WalletFailure> result) {
    when(
      () => walletRepository.getWallets(
        environment: any(named: 'environment'),
        onlyDefaults: any(named: 'onlyDefaults'),
        onlyBitcoin: any(named: 'onlyBitcoin'),
        onlyLiquid: any(named: 'onlyLiquid'),
        sync: any(named: 'sync'),
      ),
    ).thenAnswer((_) async => result);
  }

  setUp(() {
    walletRepository = _MockWalletRepository();
    settingsRepository = _MockSettingsRepository();
    status = const RecoverBullStatus.initial();
    environment = Environment.mainnet;
    askedNetworks = [];
    usecase = CheckBackupNeededUsecase(
      walletRepository: walletRepository,
      settingsRepository: settingsRepository,
      recoverBullStatus: (network) async {
        askedNetworks.add(network);
        return status;
      },
    );
    final settings = _MockSettings();
    when(() => settings.environment).thenAnswer((_) => environment);
    when(settingsRepository.fetch).thenAnswer((_) async => settings);
  });

  test('a wallet with neither backup tested needs a backup', () async {
    stubWallets(Ok([wallet(physicalTested: false)]));

    expect((await usecase.execute() as Ok).value, isTrue);
  });

  test('verified package backup is enough — no banner', () async {
    status = RecoverBullStatus(lastVerifiedEncryptedBackupAt: DateTime(2026));
    stubWallets(Ok([wallet(physicalTested: false)]));

    expect((await usecase.execute() as Ok).value, isFalse);
  });

  for (final (env, network) in [
    (Environment.mainnet, RecoverBullNetwork.mainnet),
    (Environment.testnet, RecoverBullNetwork.testnet),
  ]) {
    test('reads the ${network.name} encrypted backup in $env', () async {
      environment = env;
      stubWallets(Ok([wallet(physicalTested: false)]));

      expect((await usecase.execute() as Ok).value, isTrue);
      expect(askedNetworks, [network]);
    });
  }

  test('no default wallets means nothing to back up', () async {
    stubWallets(const Ok([]));

    expect((await usecase.execute() as Ok).value, isFalse);
  });

  test('a failed wallet read is an Err, NOT "no backup needed"', () async {
    // The distinction is the point of the Result: collapsing this to `false`
    // would hide the banner from a user whose wallet is genuinely unbacked up.
    stubWallets(const Err(WalletStorageFailure('getWallets: SqliteException')));

    final result = await usecase.execute();

    expect(result, isA<Err<bool, WalletFailure>>());
    expect((result as Err).failure, isA<WalletStorageFailure>());
  });

  test('sanitizes a throwing settings read', () async {
    when(
      settingsRepository.fetch,
    ).thenThrow(StateError('SqliteException(13): disk image is malformed'));

    final result = await usecase.execute();

    final failure = (result as Err).failure as WalletFailure;
    expect(failure, isA<WalletStorageFailure>());
    // The raw reason belongs in the log, never in a value presentation holds.
    expect(failure.logMessage, isNot(contains('disk image is malformed')));
  });
  test(
    'legacy encrypted metadata does not replace package verification',
    () async {
      final legacy = wallet(physicalTested: false);
      when(() => legacy.isEncryptedVaultTested).thenReturn(true);
      stubWallets(Ok([legacy]));
      expect((await usecase.execute() as Ok).value, isTrue);
      verifyNever(() => legacy.isEncryptedVaultTested);
    },
  );

  test(
    'physical backup satisfies the requirement without package verification',
    () async {
      stubWallets(Ok([wallet(physicalTested: true)]));
      expect((await usecase.execute() as Ok).value, isFalse);
    },
  );

  test(
    'unavailable package status falls back to the physical backup: untested',
    () async {
      stubWallets(Ok([wallet(physicalTested: false)]));
      status = const RecoverBullStatus.unavailable();
      expect((await usecase.execute() as Ok).value, isTrue);
    },
  );

  test(
    'unavailable package status falls back to the physical backup: tested',
    () async {
      stubWallets(Ok([wallet(physicalTested: true)]));
      status = const RecoverBullStatus.unavailable();
      expect((await usecase.execute() as Ok).value, isFalse);
    },
  );
}
