import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/read_backup_status_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/wallet/domain/wallet.dart';
import 'package:bull_recoverbull/bull_recoverbull.dart' as rb;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart'
    show BitcoinUnit, Err, Ok, Result, ScriptType;

class _Settings extends Mock implements Preferences {}

final class _Wallets extends Fake implements GetWalletsUsecase {
  final Wallet wallet;

  _Wallets(this.wallet);

  @override
  Future<Result<List<Wallet>, WalletFailure>> execute({
    bool? onlyDefaults,
    bool? onlyBitcoin,
    bool? onlyLiquid,
    bool sync = false,
  }) async => Ok([wallet]);
}

void main() {
  final legacyDate = DateTime.utc(2026, 1, 2);

  Future<BackupStatusSummary> summary(rb.BackupStatus status) async {
    final settings = _Settings();
    when(() => settings.fetch()).thenAnswer(
      (_) async => Ok(
        const SettingsEntity(
          environment: Environment.testnet,
          bitcoinUnit: BitcoinUnit.sats,
          currencyCode: 'USD',
        ),
      ),
    );
    final wallet = Wallet(
      origin: "test/84'/1'/0'",
      network: Network.bitcoinTestnet,
      masterFingerprint: 'deadbeef',
      xpubFingerprint: 'test-fixture',
      scriptType: ScriptType.bip84,
      xpub: 'unused-fixture',
      externalPublicDescriptor: 'unused-fixture',
      internalPublicDescriptor: 'unused-fixture',
      signer: SignerEntity.local,
      signerDevice: null,
      balanceSat: BigInt.zero,
      isDefault: true,
      latestEncryptedBackup: legacyDate,
    );
    final result = await ReadBackupStatusUsecase(
      _Wallets(wallet),
      settings,
      (_) async => Ok(status),
    ).execute();
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => fail('$failure'),
    };
  }

  test(
    'a vault only known from before the current system is historical',
    () async {
      final status = await summary(const rb.BackupStatus());
      expect(status.encryptedHistorical, isTrue);
      expect(status.encryptedVerified, isFalse);
    },
  );

  test('a vault stored by the current system is merely untested', () async {
    final status = await summary(
      rb.BackupStatus(storedAt: DateTime.utc(2026, 11, 16)),
    );
    expect(status.encryptedHistorical, isFalse);
    expect(status.encryptedVerified, isFalse);
  });

  test('a tested vault is neither historical nor untested', () async {
    final status = await summary(
      rb.BackupStatus(verifiedAt: DateTime.utc(2026, 11, 16)),
    );
    expect(status.encryptedHistorical, isFalse);
    expect(status.encryptedVerified, isTrue);
  });
}
