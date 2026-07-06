import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:bb_mobile/features/remote_keychain_recovery/domain/usecases/heal_recovered_products_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

const _laReservation = 'lightning_address_wallet_seed';
const _ppReservation = 'payment_page_wallet_seed';
const _posReservation = 'pos_wallet_seed';

class _FakeLightningAddressFacade implements LightningAddressFacade {
  int ensureCalls = 0;
  LightningAddressHealOutcome outcome = const LightningAddressHealOutcome(
    liveness: LightningAddressRegistrationLiveness.live,
  );
  Object? error;

  @override
  Future<LightningAddressHealOutcome> ensureRegistrationLive() async {
    ensureCalls++;
    final error = this.error;
    if (error != null) throw error;
    return outcome;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePaymentPageFacade implements PaymentPageFacade {
  int ensureCalls = 0;
  PaymentPageHealOutcome outcome = const PaymentPageHealOutcome(
    liveness: PaymentPageLiveness.live,
  );
  Object? error;

  @override
  Future<PaymentPageHealOutcome> ensurePageLive() async {
    ensureCalls++;
    final error = this.error;
    if (error != null) throw error;
    return outcome;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePosFacade implements PosFacade {
  int ensureCalls = 0;
  PosHealOutcome outcome = const PosHealOutcome(liveness: PosLiveness.live);
  Object? error;

  @override
  Future<PosHealOutcome> ensurePosLive() async {
    ensureCalls++;
    final error = this.error;
    if (error != null) throw error;
    return outcome;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeLightningAddressFacade la;
  late _FakePaymentPageFacade pp;
  late _FakePosFacade pos;
  late HealRecoveredProductsUsecase usecase;

  setUp(() {
    la = _FakeLightningAddressFacade();
    pp = _FakePaymentPageFacade();
    pos = _FakePosFacade();
    usecase = HealRecoveredProductsUsecase(la, pp, pos);
  });

  test('heals only the Lightning Address when only it is flagged', () async {
    la.outcome = const LightningAddressHealOutcome(
      liveness: LightningAddressRegistrationLiveness.reregistered,
    );

    final outcome = await usecase.execute({_laReservation});

    expect(la.ensureCalls, 1);
    expect(pp.ensureCalls, 0);
    expect(
      outcome.lightningAddress?.liveness,
      LightningAddressRegistrationLiveness.reregistered,
    );
    expect(outcome.paymentPage, isNull);
  });

  test('heals only the Payment Page when only it is flagged', () async {
    pp.outcome = const PaymentPageHealOutcome(
      liveness: PaymentPageLiveness.needsReactivation,
    );

    final outcome = await usecase.execute({_ppReservation});

    expect(pp.ensureCalls, 1);
    expect(la.ensureCalls, 0);
    expect(
      outcome.paymentPage?.liveness,
      PaymentPageLiveness.needsReactivation,
    );
    expect(outcome.lightningAddress, isNull);
  });

  test('heals only the Point of Sale when only it is flagged', () async {
    pos.outcome = const PosHealOutcome(
      liveness: PosLiveness.needsReactivation,
    );

    final outcome = await usecase.execute({_posReservation});

    expect(pos.ensureCalls, 1);
    expect(la.ensureCalls, 0);
    expect(pp.ensureCalls, 0);
    expect(outcome.pos?.liveness, PosLiveness.needsReactivation);
    expect(outcome.lightningAddress, isNull);
    expect(outcome.paymentPage, isNull);
  });

  test('heals all products when all are flagged', () async {
    final outcome = await usecase.execute({
      _laReservation,
      _ppReservation,
      _posReservation,
    });

    expect(la.ensureCalls, 1);
    expect(pp.ensureCalls, 1);
    expect(pos.ensureCalls, 1);
    expect(outcome.lightningAddress, isNotNull);
    expect(outcome.paymentPage, isNotNull);
    expect(outcome.pos, isNotNull);
  });

  test('a Point of Sale heal failure degrades to unreachable (never throws)',
      () async {
    pos.error = StateError('boom');

    final outcome = await usecase.execute({_posReservation});

    expect(outcome.pos?.liveness, PosLiveness.unreachable);
  });

  test('healing the POS never touches the page (coexistence)', () async {
    final outcome = await usecase.execute({_posReservation});

    expect(pp.ensureCalls, 0);
    expect(outcome.paymentPage, isNull);
  });

  test(
    'a Payment Page heal failure degrades to unreachable (never throws)',
    () async {
      pp.error = StateError('boom');

      final outcome = await usecase.execute({_ppReservation});

      expect(outcome.paymentPage?.liveness, PaymentPageLiveness.unreachable);
    },
  );

  test('a Lightning Address heal failure degrades to unreachable', () async {
    la.error = StateError('boom');

    final outcome = await usecase.execute({_laReservation});

    expect(
      outcome.lightningAddress?.liveness,
      LightningAddressRegistrationLiveness.unreachable,
    );
  });

  test('nothing flagged heals nothing', () async {
    final outcome = await usecase.execute(const {});

    expect(la.ensureCalls, 0);
    expect(pp.ensureCalls, 0);
    expect(pos.ensureCalls, 0);
    expect(outcome.lightningAddress, isNull);
    expect(outcome.paymentPage, isNull);
    expect(outcome.pos, isNull);
  });
}
