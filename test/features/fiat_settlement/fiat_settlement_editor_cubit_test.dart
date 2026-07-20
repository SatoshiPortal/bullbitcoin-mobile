import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/fiat_settlement/domain/usecases/has_bull_bitcoin_account_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/presentation/fiat_settlement_editor_cubit.dart';
import 'package:bb_mobile/features/fiat_settlement/presentation/fiat_settlement_editor_state.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFacade extends Mock implements FiatSettlementFacade {}

class _MockHasAccount extends Mock implements HasBullBitcoinAccountUsecase {}

FiatSettlementConfigurationView _view(
  FiatSettlementProduct product,
  int pct, {
  FiatCurrency? currency,
}) {
  return FiatSettlementConfigurationView(
    products: [
      FiatSettlementProductConfig(
        product: product,
        fiatPercentage: pct,
        currency: currency,
      ),
    ],
    credentialActive: true,
  );
}

void main() {
  late _MockFacade facade;
  late _MockHasAccount hasAccount;
  const product = FiatSettlementProduct.paymentPage;

  setUpAll(() {
    registerFallbackValue(FiatSettlementProduct.invoice);
    registerFallbackValue(FiatCurrency.cad);
  });

  setUp(() {
    facade = _MockFacade();
    hasAccount = _MockHasAccount();
    when(() => facade.configuration()).thenAnswer(
      (_) async => Ok(_view(product, 0)),
    );
    when(() => hasAccount.execute()).thenAnswer((_) async => true);
  });

  FiatSettlementEditorCubit build() => FiatSettlementEditorCubit(
    facade: facade,
    hasBullBitcoinAccount: hasAccount,
    product: product,
  );

  test('load maps a saved bitcoin-only config to the bitcoin mode', () async {
    final cubit = build();
    await cubit.load();
    expect(cubit.state.status, FiatSettlementEditorStatus.ready);
    expect(cubit.state.mode, FiatSettlementReceiveMode.bitcoin);
    expect(cubit.state.isFirstActivation, isTrue);
  });

  test('load preselects a saved mixed config', () async {
    when(() => facade.configuration()).thenAnswer(
      (_) async => Ok(_view(product, 40, currency: FiatCurrency.cad)),
    );
    final cubit = build();
    await cubit.load();
    expect(cubit.state.mode, FiatSettlementReceiveMode.mix);
    expect(cubit.state.mixFiatPercentage, 40);
    expect(cubit.state.currency, FiatCurrency.cad);
    expect(cubit.state.isFirstActivation, isFalse);
  });

  test('bitcoin mode can always save; fiat needs currency + acceptance',
      () async {
    final cubit = build();
    await cubit.load();

    // Bitcoin selected -> immediately savable.
    expect(cubit.state.canSave, isTrue);

    cubit.selectMode(FiatSettlementReceiveMode.fiat);
    expect(cubit.state.canSave, isFalse); // no currency yet

    cubit.selectCurrency(FiatCurrency.usd);
    expect(cubit.state.requiresAcceptance, isTrue);
    expect(cubit.state.canSave, isFalse); // not understood yet

    cubit.setUnderstood(true);
    expect(cubit.state.canSave, isTrue);
  });

  test('a successful save commits the returned config as saved', () async {
    when(
      () => facade.set(
        product: any(named: 'product'),
        fiatPercentage: any(named: 'fiatPercentage'),
        currency: any(named: 'currency'),
      ),
    ).thenAnswer(
      (_) async => Ok(_view(product, 100, currency: FiatCurrency.usd)),
    );
    final cubit = build();
    await cubit.load();
    cubit.selectMode(FiatSettlementReceiveMode.fiat);
    cubit.selectCurrency(FiatCurrency.usd);
    cubit.setUnderstood(true);

    await cubit.save();

    expect(cubit.state.status, FiatSettlementEditorStatus.success);
    expect(cubit.state.saved?.fiatPercentage, 100);
  });

  test('a failed save preserves the prior saved config and surfaces failure',
      () async {
    when(() => facade.configuration()).thenAnswer(
      (_) async => Ok(_view(product, 50, currency: FiatCurrency.cad)),
    );
    when(
      () => facade.set(
        product: any(named: 'product'),
        fiatPercentage: any(named: 'fiatPercentage'),
        currency: any(named: 'currency'),
      ),
    ).thenAnswer(
      (_) async => const Err(FiatSettlementFailure.kycRequired()),
    );
    final cubit = build();
    await cubit.load();
    cubit.selectCurrency(FiatCurrency.eur);
    cubit.setUnderstood(true);

    await cubit.save();

    expect(cubit.state.status, FiatSettlementEditorStatus.ready);
    expect(cubit.state.failure, isA<FiatSettlementKycRequiredFailure>());
    // Prior config intact.
    expect(cubit.state.saved?.fiatPercentage, 50);
    expect(cubit.state.saved?.currency, FiatCurrency.cad);
  });

  test('selecting bitcoin then saving disables via the facade', () async {
    when(() => facade.configuration()).thenAnswer(
      (_) async => Ok(_view(product, 50, currency: FiatCurrency.cad)),
    );
    when(() => facade.disable(product: any(named: 'product'))).thenAnswer(
      (_) async => Ok(_view(product, 0)),
    );
    final cubit = build();
    await cubit.load();
    cubit.selectMode(FiatSettlementReceiveMode.bitcoin);

    await cubit.save();

    verify(() => facade.disable(product: product)).called(1);
    verifyNever(
      () => facade.set(
        product: any(named: 'product'),
        fiatPercentage: any(named: 'fiatPercentage'),
        currency: any(named: 'currency'),
      ),
    );
    expect(cubit.state.status, FiatSettlementEditorStatus.success);
  });

  test('percentage-only change on same currency skips acceptance', () async {
    when(() => facade.configuration()).thenAnswer(
      (_) async => Ok(_view(product, 50, currency: FiatCurrency.cad)),
    );
    final cubit = build();
    await cubit.load();
    // Same currency, just move the slider.
    cubit.setMixPercentage(30);
    expect(cubit.state.requiresAcceptance, isFalse);
    expect(cubit.state.canSave, isTrue);
  });

  test('the mix slider spans 0..100 and clamps out-of-range values', () async {
    final cubit = build();
    await cubit.load();
    cubit.selectMode(FiatSettlementReceiveMode.mix);

    cubit.setMixPercentage(-10);
    expect(cubit.state.mixFiatPercentage, 0);
    cubit.setMixPercentage(150);
    expect(cubit.state.mixFiatPercentage, 100);
  });

  test('a mix slider at 0% fiat routes save to disable', () async {
    when(() => facade.configuration()).thenAnswer(
      (_) async => Ok(_view(product, 50, currency: FiatCurrency.cad)),
    );
    when(() => facade.disable(product: any(named: 'product'))).thenAnswer(
      (_) async => Ok(_view(product, 0)),
    );
    final cubit = build();
    await cubit.load();
    // Mixed product, slider dragged all the way to Bitcoin.
    cubit.setMixPercentage(0);
    expect(cubit.state.effectiveFiatPercentage, 0);
    expect(cubit.state.requiresAcceptance, isFalse);
    expect(cubit.state.canSave, isTrue);

    await cubit.save();

    verify(() => facade.disable(product: product)).called(1);
    verifyNever(
      () => facade.set(
        product: any(named: 'product'),
        fiatPercentage: any(named: 'fiatPercentage'),
        currency: any(named: 'currency'),
      ),
    );
  });

  test('a mix slider at 100% fiat behaves like fiat-only', () async {
    when(
      () => facade.set(
        product: any(named: 'product'),
        fiatPercentage: any(named: 'fiatPercentage'),
        currency: any(named: 'currency'),
      ),
    ).thenAnswer(
      (_) async => Ok(_view(product, 100, currency: FiatCurrency.usd)),
    );
    final cubit = build();
    await cubit.load();
    cubit.selectMode(FiatSettlementReceiveMode.mix);
    cubit.setMixPercentage(100);
    expect(cubit.state.effectiveFiatPercentage, 100);
    // Needs a currency + acceptance, exactly like fiat-only.
    expect(cubit.state.canSave, isFalse);
    cubit.selectCurrency(FiatCurrency.usd);
    cubit.setUnderstood(true);
    expect(cubit.state.canSave, isTrue);

    await cubit.save();

    verify(
      () => facade.set(
        product: product,
        fiatPercentage: 100,
        currency: FiatCurrency.usd,
      ),
    ).called(1);
  });

  test('load reflects a connected Bull Bitcoin account', () async {
    when(() => hasAccount.execute()).thenAnswer((_) async => true);
    final cubit = build();
    await cubit.load();
    expect(cubit.state.hasBullBitcoinAccount, isTrue);
  });

  test('load reflects a missing Bull Bitcoin connection', () async {
    when(() => hasAccount.execute()).thenAnswer((_) async => false);
    final cubit = build();
    await cubit.load();
    expect(cubit.state.hasBullBitcoinAccount, isFalse);
  });
}
