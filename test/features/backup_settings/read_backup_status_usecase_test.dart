import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:preferences/preferences.dart';
import 'package:bb_mobile/features/wallet/domain/wallet_failure.dart';
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
  final physicalDate = DateTime.utc(2026, 2, 3);

  Future<BackupStatusSummary> summary(
    rb.BackupStatus status, {
    Network network = Network.bitcoinTestnet,
    bool physicalVerified = false,
    void Function(rb.VaultContext)? onReadVault,
  }) async {
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
      network: network,
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
      isPhysicalBackupTested: physicalVerified,
      latestPhysicalBackup: physicalVerified ? physicalDate : null,
      latestEncryptedBackup: legacyDate,
    );
    final result = await ReadBackupStatusUsecase(_Wallets(wallet), settings, (
      context,
    ) async {
      onReadVault?.call(context);
      return Ok(status);
    }).execute();
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
      expect(status.encryptedAt, legacyDate);
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

  test('physical facts do not stand in for encrypted verification', () async {
    final status = await summary(
      const rb.BackupStatus(),
      physicalVerified: true,
      onReadVault: (context) {
        expect(context.fingerprint.hex, 'deadbeef');
      },
    );
    expect(status.physicalVerified, isTrue);
    expect(status.physicalAt, physicalDate);
    expect(status.encryptedVerified, isFalse);
  });

  test('a default on another network cannot contribute backup facts', () async {
    final status = await summary(
      const rb.BackupStatus(),
      network: Network.bitcoinMainnet,
      physicalVerified: true,
      onReadVault: (_) => fail('A different network must not open a vault'),
    );
    expect(status.physicalVerified, isFalse);
    expect(status.physicalAt, isNull);
    expect(status.encryptedHistorical, isFalse);
    expect(status.encryptedAt, isNull);
  });
}
