import 'package:bb_mobile/features/bip85_registry/bip85_registry_locator.dart';
import 'package:bb_mobile/features/bip85_registry/public/bip85_registry_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

void main() {
  test('resolves one lazy singleton and rejects duplicate setup', () async {
    final locator = GetIt.asNewInstance();
    addTearDown(locator.reset);

    Bip85RegistryLocator.setup(locator);

    final first = locator<Bip85RegistryFacade>();
    final second = locator<Bip85RegistryFacade>();
    expect(second, same(first));
    expect(first.btcpayWalletSeed.walletIndex, 100);

    expect(
      () => Bip85RegistryLocator.setup(locator),
      throwsA(isA<ArgumentError>()),
    );
    expect(locator<Bip85RegistryFacade>(), same(first));
  });
}
