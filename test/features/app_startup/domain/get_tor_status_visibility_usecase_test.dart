import 'package:bb_mobile/features/app_startup/domain/app_startup_wallet_port.dart';
import 'package:bb_mobile/features/app_startup/domain/usecases/get_tor_status_visibility_usecase.dart';
import 'package:bb_mobile/features/electrum_settings/public/electrum_settings_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _WalletPort implements AppStartupWalletPort {
  bool tested = false;
  bool fail = false;

  @override
  Future<bool> hasMainnetBitcoinEncryptedBackup() async => false;

  @override
  Future<bool> hasTestedRecoverBullBackup() async {
    if (fail) throw Exception('wallet unavailable');
    return tested;
  }
}

class _ElectrumFacade extends Mock implements ElectrumSettingsFacade {}

void main() {
  late _WalletPort wallet;
  late _ElectrumFacade electrum;

  setUp(() {
    wallet = _WalletPort();
    electrum = _ElectrumFacade();
    when(
      electrum.hasActiveCustomBitcoinOnionServer,
    ).thenAnswer((_) async => false);
  });

  test('is hidden by default', () async {
    expect(
      await GetTorStatusVisibilityUsecase(wallet, electrum).execute(),
      isFalse,
    );
  });

  test('is visible when the RecoverBull backup was tested', () async {
    wallet.tested = true;
    expect(
      await GetTorStatusVisibilityUsecase(wallet, electrum).execute(),
      isTrue,
    );
  });

  test('is visible for a custom Bitcoin onion server', () async {
    when(
      electrum.hasActiveCustomBitcoinOnionServer,
    ).thenAnswer((_) async => true);
    expect(
      await GetTorStatusVisibilityUsecase(wallet, electrum).execute(),
      isTrue,
    );
  });

  test('independent failures preserve the OR contract', () async {
    wallet.tested = true;
    when(
      electrum.hasActiveCustomBitcoinOnionServer,
    ).thenThrow(Exception('electrum unavailable'));
    expect(
      await GetTorStatusVisibilityUsecase(wallet, electrum).execute(),
      isTrue,
    );

    wallet.tested = false;
    wallet.fail = true;
    when(
      electrum.hasActiveCustomBitcoinOnionServer,
    ).thenAnswer((_) async => true);
    expect(
      await GetTorStatusVisibilityUsecase(wallet, electrum).execute(),
      isTrue,
    );
  });
}
