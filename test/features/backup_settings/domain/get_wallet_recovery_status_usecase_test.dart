import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallets_usecase.dart';
import 'package:bb_mobile/features/backup_settings/domain/backup_settings_failure.dart';
import 'package:bb_mobile/features/backup_settings/domain/usecases/get_wallet_recovery_status_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _GetWallets extends Mock implements GetWalletsUsecase {}

void main() {
  late _GetWallets wallets;
  late GetWalletRecoveryStatusUsecase usecase;
  final wallet = Wallet(
    origin: 'default',
    network: Network.bitcoinMainnet,
    isDefault: true,
    signers: [],
    scriptType: ScriptType.bip84,
    publicDescriptor: 'wpkh(xpub/<0;1>/*)',
    balanceSat: BigInt.zero,
  );

  setUp(() {
    wallets = _GetWallets();
    usecase = GetWalletRecoveryStatusUsecase(wallets);
  });

  void returns(List<Wallet> values) => when(
    () => wallets.execute(
      onlyDefaults: true,
      onlyBitcoin: true,
      includeHidden: true,
    ),
  ).thenAnswer((_) async => values);

  test('uses the existing active-environment default Bitcoin lookup', () async {
    final date = DateTime.utc(2026, 9, 18);
    final selected = wallet.copyWith(
      isHidden: true,
      latestPhysicalBackup: date,
    );
    returns([selected]);
    final result = await usecase.execute();
    expect((result as Ok<Wallet, BackupSettingsFailure>).value, selected);
    verify(
      () => wallets.execute(
        onlyDefaults: true,
        onlyBitcoin: true,
        includeHidden: true,
      ),
    ).called(1);
  });

  test(
    'missing and ambiguous defaults never report successful status',
    () async {
      returns([]);
      expect(
        await usecase.execute(),
        isA<Err<Wallet, BackupSettingsFailure>>(),
      );
      returns([wallet, wallet.copyWith(origin: 'another')]);
      expect(
        await usecase.execute(),
        isA<Err<Wallet, BackupSettingsFailure>>(),
      );
    },
  );

  test('reload reads actual dates without recording a test', () async {
    returns([wallet]);
    var result = await usecase.execute();
    expect(
      (result as Ok<Wallet, BackupSettingsFailure>).value.latestEncryptedBackup,
      isNull,
    );
    final tested = wallet.copyWith(
      latestEncryptedBackup: DateTime.utc(2026, 9, 18),
    );
    returns([tested]);
    result = await usecase.execute();
    expect(
      (result as Ok<Wallet, BackupSettingsFailure>).value.latestEncryptedBackup,
      tested.latestEncryptedBackup,
    );
  });

  test('storage failure remains a typed recoverable error', () async {
    when(
      () => wallets.execute(
        onlyDefaults: true,
        onlyBitcoin: true,
        includeHidden: true,
      ),
    ).thenThrow(GetWalletsException('unavailable'));
    expect(await usecase.execute(), isA<Err<Wallet, BackupSettingsFailure>>());
  });
}
