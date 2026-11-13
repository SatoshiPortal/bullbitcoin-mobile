import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
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

  Wallet wallet({required bool vaultTested, required bool physicalTested}) {
    final w = _MockWallet();
    when(() => w.network).thenReturn(Network.bitcoinMainnet);
    when(() => w.masterFingerprint).thenReturn('73c5da0a');
    when(() => w.isEncryptedVaultTested).thenReturn(vaultTested);
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
    usecase = CheckBackupNeededUsecase(
      walletRepository: walletRepository,
      settingsRepository: settingsRepository,
      backupStatus: (_) async => const rb.Ok(rb.BackupStatus()),
    );
    final settings = _MockSettings();
    when(() => settings.environment).thenReturn(Environment.mainnet);
    when(settingsRepository.fetch).thenAnswer((_) async => settings);
  });

  test('a wallet with neither backup tested needs a backup', () async {
    stubWallets(Ok([wallet(vaultTested: false, physicalTested: false)]));

    expect((await usecase.execute() as Ok).value, isTrue);
  });

  test('historical verification does not certify a backup', () async {
    stubWallets(Ok([wallet(vaultTested: true, physicalTested: false)]));

    expect((await usecase.execute() as Ok).value, isTrue);
  });

  test('only the current context certificate suppresses the warning', () async {
    stubWallets(Ok([wallet(vaultTested: false, physicalTested: false)]));
    final certified = CheckBackupNeededUsecase(
      walletRepository: walletRepository,
      settingsRepository: settingsRepository,
      backupStatus: (context) async {
        expect(context.fingerprint.hex, '73c5da0a');
        expect(context.network, rb.BitcoinNetwork.mainnet);
        return rb.Ok(rb.BackupStatus(verifiedAt: DateTime.utc(2026)));
      },
    );
    expect((await certified.execute() as Ok).value, isFalse);
  });

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
    ).thenThrow(Exception('SqliteException(13): disk image is malformed'));

    final result = await usecase.execute();

    final failure = (result as Err).failure as WalletFailure;
    expect(failure, isA<WalletStorageFailure>());
    // The raw reason belongs in the log, never in a value presentation holds.
    expect(failure.logMessage, isNot(contains('disk image is malformed')));
  });
}
