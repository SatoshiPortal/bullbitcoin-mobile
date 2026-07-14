import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/payment_page/domain/usecases/get_payment_page_permanent_name_usecase.dart';
import 'package:bb_mobile/features/payment_page/presentation/payment_page_cubit.dart';
import 'package:bb_mobile/features/payment_page/presentation/payment_page_state.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeGetPaymentPagePermanentNameUsecase permanentName;
  late _FakePaymentPageFacade facade;
  late _FakeGetGetPaidWalletBehaviorsUsecase walletBehaviors;
  late _FakeUpdateWalletBehaviorUsecase updateWalletBehavior;

  PaymentPageCubit build() => PaymentPageCubit(
    facade: facade,
    getPermanentName: permanentName,
    getWalletBehaviors: walletBehaviors,
    updateWalletBehavior: updateWalletBehavior,
  );

  PaymentPage buildPage({
    bool archived = false,
    String description = 'Support my work',
    String? alias,
  }) => PaymentPage(
    nym: 'alice',
    header: 'Tip me',
    description: description,
    displayCurrency: 'USD',
    enabled: true,
    isArchived: archived,
    alias: alias,
    publicUrl: alias == null
        ? 'https://bullpay.ca/alice'
        : 'https://bullpay.ca/a/$alias',
  );

  setUp(() {
    permanentName = _FakeGetPaymentPagePermanentNameUsecase();
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
      permanentName.value = const PaymentPagePermanentName.unclaimed();
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PaymentPageStatus.needsNym);
    });

    test('nym but no page -> create with the fallback currency', () async {
      facade.page = null;
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PaymentPageStatus.create);
      expect(cubit.state.nym, 'alice');
      expect(cubit.state.displayCurrency, 'CAD');
    });

    test('existing live page -> edit with populated fields', () async {
      facade.page = buildPage();
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PaymentPageStatus.edit);
      expect(cubit.state.header, 'Tip me');
      expect(cubit.state.displayCurrency, 'USD');
    });

    test('archived page -> archived', () async {
      facade.page = buildPage(archived: true);
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PaymentPageStatus.archived);
    });

    test('nym lookup failure -> loadFailed', () async {
      permanentName.error = const PaymentPageException.network();
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PaymentPageStatus.loadFailed);
    });

    test(
      'server load failure still exposes the local wallet behavior',
      () async {
        permanentName.error = const PaymentPageException.network();
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
        facade.page = null;
        facade.currenciesError = const PaymentPageException.network();
        final cubit = build();

        await cubit.load();

        expect(cubit.state.status, PaymentPageStatus.create);
        expect(cubit.state.currenciesUnavailable, isTrue);
      },
    );

    test(
      'missing exact capability hides alias and availability actions',
      () async {
        permanentName.value = const PaymentPagePermanentName.unsupported();
        facade.page = buildPage();

        final cubit = build();
        await cubit.load();

        expect(cubit.state.status, PaymentPageStatus.unsupported);
        expect(facade.findCallCount, 0);
        expect(cubit.state.permanentAlias, isNull);
      },
    );

    test('reconstructs the permanent alias from server ownership', () async {
      permanentName.value = const PaymentPagePermanentName.claimed(
        nym: 'alice',
        alias: 'shop',
      );
      facade.page = buildPage(alias: 'shop');

      final first = build();
      await first.load();
      expect(first.state.permanentAlias, 'shop');
      await first.close();

      // A fresh cubit has no local alias state; the next owner lookup restores
      // it and the server page must agree.
      final afterAppStateWipe = build();
      await afterAppStateWipe.load();
      expect(afterAppStateWipe.state.permanentAlias, 'shop');
      expect(afterAppStateWipe.state.aliasDraft, isEmpty);
    });

    test(
      'fails closed when the page alias disagrees with owner state',
      () async {
        permanentName.value = const PaymentPagePermanentName.claimed(
          nym: 'alice',
          alias: 'shop',
        );
        facade.page = buildPage(alias: 'other');

        final cubit = build();
        await cubit.load();

        expect(cubit.state.status, PaymentPageStatus.loadFailed);
        expect(
          cubit.state.failure?.kind,
          PaymentPageErrorKind.invalidServerResponse,
        );
      },
    );
  });

  test('an unclaimed nym exposes no product-owned name mutation', () async {
    permanentName.value = const PaymentPagePermanentName.unclaimed();
    final cubit = build();
    await cubit.load();

    expect(cubit.state.status, PaymentPageStatus.needsNym);
    expect(facade.saveCallCount, 0);
    expect(facade.archiveCallCount, 0);
  });

  group('save', () {
    test('success moves to edit with the returned page', () async {
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

    test(
      'normalizes and submits the optional first shared alias claim',
      () async {
        facade.page = null;
        final cubit = build();
        await cubit.load();
        cubit
          ..aliasDraftChanged('  Shop  ')
          ..headerChanged('Tip me')
          ..descriptionChanged('Support my work');
        facade.savedPage = buildPage(alias: 'shop');

        await cubit.save();

        expect(facade.lastCommand?.aliasClaim, 'shop');
        expect(cubit.state.permanentAlias, 'shop');
        expect(cubit.state.aliasDraft, isEmpty);
      },
    );

    test('structured owned-alias conflict adopts the server alias', () async {
      facade.page = null;
      final cubit = build();
      await cubit.load();
      cubit
        ..aliasDraftChanged('other')
        ..headerChanged('Tip me')
        ..descriptionChanged('Support my work');
      facade.saveError = PaymentPageSaveException.submission(
        cause: const PaymentPageException.aliasAlreadyAssigned(
          ownedAlias: 'shop',
        ),
      );

      await cubit.save();

      expect(cubit.state.permanentAlias, 'shop');
      expect(cubit.state.aliasDraft, isEmpty);
      expect(cubit.state.submissionUncertain, isFalse);
    });

    test('alias namespace conflict points at only the alias field', () async {
      facade.page = null;
      final cubit = build();
      await cubit.load();
      cubit
        ..aliasDraftChanged('taken')
        ..headerChanged('Tip me')
        ..descriptionChanged('Support my work');
      facade.saveError = PaymentPageSaveException.submission(
        cause: const PaymentPageException.aliasTaken(),
      );

      await cubit.save();

      expect(cubit.state.invalidField, PaymentPageField.alias);
      expect(cubit.state.submissionUncertain, isFalse);
    });
  });

  test(
    'availability switch archives only Donation Page and preserves alias',
    () async {
      permanentName.value = const PaymentPagePermanentName.claimed(
        nym: 'alice',
        alias: 'shop',
      );
      facade.page = buildPage(alias: 'shop');
      final cubit = build();
      await cubit.load();

      facade.page = buildPage(archived: true, alias: 'shop');
      await cubit.setOnline(false);

      expect(facade.archiveCallCount, 1);
      expect(facade.saveCallCount, 0);
      expect(cubit.state.status, PaymentPageStatus.archived);
      expect(cubit.state.permanentAlias, 'shop');
    },
  );
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

class _FakeGetPaymentPagePermanentNameUsecase
    implements GetPaymentPagePermanentNameUsecase {
  PaymentPagePermanentName value = const PaymentPagePermanentName.claimed(
    nym: 'alice',
  );
  Object? error;

  @override
  Future<PaymentPagePermanentName> execute() async {
    final currentError = error;
    if (currentError != null) throw currentError;
    return value;
  }
}

class _FakePaymentPageFacade implements PaymentPageFacade {
  PaymentPage? page;
  PaymentPage? savedPage;
  Object? saveError;
  List<DisplayCurrency> currencies = const [];
  Object? currenciesError;
  Future<void>? saveGate;
  int saveCallCount = 0;
  int findCallCount = 0;
  int archiveCallCount = 0;
  SavePaymentPageCommand? lastCommand;

  @override
  Future<PaymentPage?> find({required String nym}) async {
    findCallCount += 1;
    return page;
  }

  @override
  Future<PaymentPage> save(SavePaymentPageCommand command) async {
    saveCallCount += 1;
    lastCommand = command;
    final gate = saveGate;
    if (gate != null) await gate;
    final error = saveError;
    if (error != null) throw error;
    return savedPage ?? page!;
  }

  @override
  Future<PaymentPage?> archive() async {
    archiveCallCount += 1;
    return page;
  }

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
