import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/usecases/heal_recovered_products_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'heals Lightning Address only when its reservation is flagged',
    () async {
      final lightningAddress = _LightningAddressFacade();
      final usecase = HealRecoveredProductsUsecase(lightningAddress);

      final outcome = await usecase.execute({
        'lightning_address_wallet_seed',
        'payment_page_wallet_seed',
      });

      expect(lightningAddress.ensureCalls, 1);
      expect(
        outcome.lightningAddress?.liveness,
        LightningAddressRegistrationLiveness.reregistered,
      );
    },
  );

  test('unknown heal failure degrades to unreachable', () async {
    final lightningAddress = _LightningAddressFacade()..error = StateError('x');
    final usecase = HealRecoveredProductsUsecase(lightningAddress);

    final outcome = await usecase.execute({'lightning_address_wallet_seed'});

    expect(
      outcome.lightningAddress?.liveness,
      LightningAddressRegistrationLiveness.unreachable,
    );
  });
}

final class _LightningAddressFacade implements LightningAddressFacade {
  int ensureCalls = 0;
  Object? error;

  @override
  Future<LightningAddressHealOutcome> ensureRegistrationLive() async {
    ensureCalls += 1;
    final error = this.error;
    if (error != null) throw error;
    return const LightningAddressHealOutcome(
      liveness: LightningAddressRegistrationLiveness.reregistered,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
