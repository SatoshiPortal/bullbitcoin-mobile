import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/presentation/payment_page_cubit.dart';
import 'package:bb_mobile/features/payment_page/presentation/payment_page_state.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeLightningAddressFacade la;
  late _FakePaymentPageFacade facade;
  late _FakeGetGetPaidWalletBehaviorsUsecase walletBehaviors;
  late _FakeUpdateWalletBehaviorUsecase updateWalletBehavior;

  PaymentPageCubit build() => PaymentPageCubit(
    facade: facade,
    lightningAddress: la,
    getWalletBehaviors: walletBehaviors,
    updateWalletBehavior: updateWalletBehavior,
  );

  PaymentPage buildPage({
    bool archived = false,
    String description = 'Support my work',
  }) => PaymentPage(
    nym: 'alice',
    header: 'Tip me',
    description: description,
    displayCurrency: 'USD',
    enabled: true,
    isArchived: archived,
    publicUrl: 'https://bullpay.ca/alice',
  );

  setUp(() {
    la = _FakeLightningAddressFacade();
    facade = _FakePaymentPageFacade();
    walletBehaviors = _FakeGetGetPaidWalletBehaviorsUsecase();
    updateWalletBehavior = _FakeUpdateWalletBehaviorUsecase();
    facade.currencies = const [
      DisplayCurrency(code: 'CAD', precision: 2),
      DisplayCurrency(code: 'USD', precision: 2),
    ];
  });

  group('load', () {
    test('no nym -> needsNym', () async {
      la.lookupError = const LightningAddressServerRejectedRequestException(
        code: 'NymNotFound',
        retryable: false,
      );
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PaymentPageStatus.needsNym);
    });

    test('nym but no page -> create with the fallback currency', () async {
      la.status = const LightningAddressStatus(nym: 'alice', active: true);
      facade.page = null;
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PaymentPageStatus.create);
      expect(cubit.state.nym, 'alice');
      expect(cubit.state.displayCurrency, 'CAD');
    });

    test('existing live page -> edit with populated fields', () async {
      la.status = const LightningAddressStatus(nym: 'alice', active: true);
      facade.page = buildPage();
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PaymentPageStatus.edit);
      expect(cubit.state.header, 'Tip me');
      expect(cubit.state.displayCurrency, 'USD');
    });

    test('archived page -> archived', () async {
      la.status = const LightningAddressStatus(nym: 'alice', active: true);
      facade.page = buildPage(archived: true);
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PaymentPageStatus.archived);
    });

    test('nym lookup failure -> loadFailed', () async {
      la.lookupError = const LightningAddressServerRejectedRequestException(
        code: 'ServiceUnavailable',
        retryable: true,
      );
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PaymentPageStatus.loadFailed);
    });

    test(
      'server load failure still exposes the local wallet behavior',
      () async {
        la.lookupError = const LightningAddressServerRejectedRequestException(
          code: 'ServiceUnavailable',
          retryable: true,
        );
        walletBehaviors.behaviors = const [
          GetPaidWalletBehavior(
            product: GetPaidWalletProduct.paymentPage,
            walletId: 'wallet-102',
            hideOnHome: true,
            autoSweepEnabled: true,
          ),
        ];
        final cubit = build();

        await cubit.load();

        expect(cubit.state.status, PaymentPageStatus.loadFailed);
        expect(cubit.state.walletBehavior?.walletId, 'wallet-102');
      },
    );

    test(
      'currency fetch failure degrades but still reaches the form',
      () async {
        la.status = const LightningAddressStatus(nym: 'alice', active: true);
        facade.page = null;
        facade.currenciesError = const PaymentPageException.network();
        final cubit = build();

        await cubit.load();

        expect(cubit.state.status, PaymentPageStatus.create);
        expect(cubit.state.currenciesUnavailable, isTrue);
      },
    );
  });

  test('createNym delegates to the LA registration then reloads', () async {
    la.lookupError = const LightningAddressServerRejectedRequestException(
      code: 'NymNotFound',
      retryable: false,
    );
    final cubit = build();
    await cubit.load();
    expect(cubit.state.status, PaymentPageStatus.needsNym);

    // After registration the nym becomes resolvable and no page exists yet.
    cubit.nymDraftChanged('alice');
    facade.page = null;
    await cubit.createNym();

    expect(la.registeredNyms, ['alice']);
    expect(cubit.state.status, PaymentPageStatus.create);
  });

  group('save', () {
    test('success moves to edit with the returned page', () async {
      la.status = const LightningAddressStatus(nym: 'alice', active: true);
      facade.page = null;
      final cubit = build();
      await cubit.load();

      cubit
        ..headerChanged('Tip me')
        ..descriptionChanged('Support my work');
      facade.savedPage = buildPage();
      await cubit.save();

      expect(facade.saveCallCount, 1);
      expect(cubit.state.status, PaymentPageStatus.edit);
      expect(cubit.state.submitting, isFalse);
    });

    test('surfaces an uncertain submission failure', () async {
      la.status = const LightningAddressStatus(nym: 'alice', active: true);
      facade.page = null;
      final cubit = build();
      await cubit.load();
      cubit
        ..headerChanged('Tip me')
        ..descriptionChanged('Support my work');
      facade.saveError = PaymentPageSaveException.submission(
        cause: const PaymentPageException.timeout(),
      );

      await cubit.save();

      expect(cubit.state.failure, isNotNull);
      expect(cubit.state.submissionUncertain, isTrue);
      expect(cubit.state.submitting, isFalse);
    });

    test('invalid input is refused without a wire call', () async {
      la.status = const LightningAddressStatus(nym: 'alice', active: true);
      facade.page = null;
      final cubit = build();
      await cubit.load();
      // header left empty -> invalid
      cubit.descriptionChanged('Support my work');

      await cubit.save();

      expect(facade.saveCallCount, 0);
      expect(cubit.state.failure?.kind, PaymentPageErrorKind.invalidInput);
    });

    test(
      'legacy archived content can be corrected before reactivation',
      () async {
        la.status = const LightningAddressStatus(nym: 'alice', active: true);
        facade.page = buildPage(archived: true, description: 'a' * 121);
        final cubit = build();
        await cubit.load();

        expect(cubit.state.status, PaymentPageStatus.archived);
        expect(cubit.state.canSubmit, isFalse);
        await cubit.save();
        expect(facade.saveCallCount, 0);

        cubit.descriptionChanged('A new short description');
        facade.savedPage = buildPage(description: 'A new short description');
        await cubit.save();

        expect(facade.saveCallCount, 1);
        expect(cubit.state.status, PaymentPageStatus.edit);
      },
    );

    test('a double-tap yields exactly one wire call', () async {
      la.status = const LightningAddressStatus(nym: 'alice', active: true);
      facade.page = null;
      final cubit = build();
      await cubit.load();
      cubit
        ..headerChanged('Tip me')
        ..descriptionChanged('Support my work');

      final gate = Completer<void>();
      facade.saveGate = gate.future;
      facade.savedPage = buildPage();

      final first = cubit.save();
      final second = cubit.save(); // inert: a save is already in flight
      gate.complete();
      await Future.wait([first, second]);

      expect(facade.saveCallCount, 1);
    });
  });
}

class _FakeGetGetPaidWalletBehaviorsUsecase
    implements GetGetPaidWalletBehaviorsUsecase {
  List<GetPaidWalletBehavior> behaviors = const [];

  @override
  Future<List<GetPaidWalletBehavior>> execute({
    GetPaidWalletProduct? only,
  }) async {
    if (only == null) return behaviors;
    return behaviors.where((b) => b.product == only).toList();
  }
}

class _FakeUpdateWalletBehaviorUsecase implements UpdateWalletBehaviorUsecase {
  @override
  Future<void> execute({
    required String walletId,
    bool? hideOnHome,
    bool? autoSweepEnabled,
  }) async {}
}

class _FakeLightningAddressFacade implements LightningAddressFacade {
  LightningAddressStatus status = const LightningAddressStatus(
    nym: 'alice',
    active: true,
  );
  Object? lookupError;
  final List<String> registeredNyms = [];

  @override
  Future<LightningAddressStatus> lookupWalletOwnedRegistration() async {
    final error = lookupError;
    if (error != null) throw error;
    return status;
  }

  @override
  Future<WalletOwnedLightningAddressRegistration> registerWalletOwned({
    required String nym,
  }) async {
    registeredNyms.add(nym);
    // Registration makes the nym resolvable on the next lookup.
    lookupError = null;
    status = LightningAddressStatus(nym: nym, active: true);
    return WalletOwnedLightningAddressRegistration(
      registration: LightningAddressRegistration(
        nym: nym,
        lightningAddress: '$nym@bullpay.ca',
      ),
      walletId: 'la-wallet',
      walletCreated: true,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePaymentPageFacade implements PaymentPageFacade {
  PaymentPage? page;
  PaymentPage? savedPage;
  Object? saveError;
  List<DisplayCurrency> currencies = const [];
  Object? currenciesError;
  Future<void>? saveGate;
  int saveCallCount = 0;

  @override
  Future<PaymentPage?> find({required String nym}) async => page;

  @override
  Future<PaymentPage> save(SavePaymentPageCommand command) async {
    saveCallCount += 1;
    final gate = saveGate;
    if (gate != null) await gate;
    final error = saveError;
    if (error != null) throw error;
    return savedPage ?? page!;
  }

  @override
  Future<PaymentPage?> archive() async => page;

  @override
  Future<List<DisplayCurrency>> supportedCurrencies() async {
    final error = currenciesError;
    if (error != null) throw error;
    return currencies;
  }

  @override
  Future<PaymentPageHealOutcome> ensurePageLive() async =>
      throw UnimplementedError();
}
