import 'package:bb_mobile/core/entities/signer_device_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/wallet_signer_device_port.dart';
import 'package:bb_mobile/features/settings/domain/settings_failure.dart';
import 'package:bb_mobile/features/settings/domain/usecases/update_wallet_signer_device_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletSignerDevicePort extends Mock
    implements WalletSignerDevicePort {}

class _MockWallet extends Mock implements Wallet {}

void main() {
  late _MockWalletSignerDevicePort walletSignerDevicePort;
  late UpdateWalletSignerDeviceUsecase usecase;

  setUp(() {
    walletSignerDevicePort = _MockWalletSignerDevicePort();
    usecase = UpdateWalletSignerDeviceUsecase(
      walletSignerDevicePort: walletSignerDevicePort,
    );
  });

  test('returns the wallet with its updated signer device', () async {
    final wallet = _MockWallet();
    when(
      () => walletSignerDevicePort.updateSignerDevice(
        walletId: 'wallet-id',
        signerId: 'signer-id',
        signerDevice: SignerDeviceEntity.jade,
      ),
    ).thenAnswer((_) async => wallet);

    final result = await usecase.execute(
      walletId: 'wallet-id',
      signerId: 'signer-id',
      signerDevice: SignerDeviceEntity.jade,
    );

    expect(result, isA<Ok<Wallet, SettingsFailure>>());
    expect((result as Ok<Wallet, SettingsFailure>).value, same(wallet));
  });

  test('maps persistence exceptions to a settings failure', () async {
    when(
      () => walletSignerDevicePort.updateSignerDevice(
        walletId: 'wallet-id',
        signerId: 'signer-id',
        signerDevice: SignerDeviceEntity.jade,
      ),
    ).thenThrow(Exception('write failed'));

    final result = await usecase.execute(
      walletId: 'wallet-id',
      signerId: 'signer-id',
      signerDevice: SignerDeviceEntity.jade,
    );

    expect(result, isA<Err<Wallet, SettingsFailure>>());
    expect(
      (result as Err<Wallet, SettingsFailure>).failure,
      isA<SettingsStorageFailure>(),
    );
  });
}
