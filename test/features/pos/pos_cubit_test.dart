import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/pos/presentation/pos_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/pos_state.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeLightningAddressFacade la;
  late _FakePosFacade facade;
  late _FakeGetGetPaidWalletBehaviorsUsecase walletBehaviors;
  late _FakeUpdateWalletBehaviorUsecase updateWalletBehavior;

  PosCubit build() => PosCubit(
    facade: facade,
    lightningAddress: la,
    getWalletBehaviors: walletBehaviors,
    updateWalletBehavior: updateWalletBehavior,
  );

  PosTerminal buildTerminal({bool archived = false}) => PosTerminal(
    nym: 'alice',
    label: 'My Till',
    displayCurrency: 'USD',
    enabled: true,
    isArchived: archived,
    terminalUrl: 'https://bullpay.ca/alice/pos',
  );

  setUp(() {
    la = _FakeLightningAddressFacade();
    facade = _FakePosFacade();
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

      expect(cubit.state.status, PosStatus.needsNym);
    });

    test('nym but no pos -> create with the fallback currency', () async {
      la.status = const LightningAddressStatus(nym: 'alice', active: true);
      facade.terminal = null;
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PosStatus.create);
      expect(cubit.state.nym, 'alice');
      expect(cubit.state.displayCurrency, 'CAD');
    });

    test(
      'existing live pos -> edit with populated fields + terminal URL',
      () async {
        la.status = const LightningAddressStatus(nym: 'alice', active: true);
        facade.terminal = buildTerminal();
        final cubit = build();

        await cubit.load();

        expect(cubit.state.status, PosStatus.edit);
        expect(cubit.state.label, 'My Till');
        expect(cubit.state.displayCurrency, 'USD');
        expect(cubit.state.terminalUrl, 'https://bullpay.ca/alice/pos');
      },
    );

    test('archived pos -> archived', () async {
      la.status = const LightningAddressStatus(nym: 'alice', active: true);
      facade.terminal = buildTerminal(archived: true);
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PosStatus.archived);
    });

    test('nym lookup failure -> loadFailed', () async {
      la.lookupError = const LightningAddressServerRejectedRequestException(
        code: 'ServiceUnavailable',
        retryable: true,
      );
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PosStatus.loadFailed);
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
            product: GetPaidWalletProduct.pos,
            walletId: 'wallet-103',
            hideOnHome: true,
            autoSweepEnabled: true,
          ),
        ];
        final cubit = build();

        await cubit.load();

        expect(cubit.state.status, PosStatus.loadFailed);
        expect(cubit.state.walletBehavior?.walletId, 'wallet-103');
      },
    );

    test(
      'currency fetch failure degrades but still reaches the form',
      () async {
        la.status = const LightningAddressStatus(nym: 'alice', active: true);
        facade.terminal = null;
        facade.currenciesError = const PosException.network();
        final cubit = build();

        await cubit.load();

        expect(cubit.state.status, PosStatus.create);
        expect(cubit.state.currenciesUnavailable, isTrue);
      },
    );

    test(
      'a kind-mismatch body surfaces as loadFailed (invalidServerResponse)',
      () async {
        la.status = const LightningAddressStatus(nym: 'alice', active: true);
        facade.findError = const PosException.invalidServerResponse();
        final cubit = build();

        await cubit.load();

        expect(cubit.state.status, PosStatus.loadFailed);
        expect(cubit.state.failure?.kind, PosErrorKind.invalidServerResponse);
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
    expect(cubit.state.status, PosStatus.needsNym);

    cubit.nymDraftChanged('alice');
    facade.terminal = null;
    await cubit.createNym();

    expect(la.registeredNyms, ['alice']);
    expect(cubit.state.status, PosStatus.create);
  });

  group('provision', () {
    test('success moves to edit with the returned terminal', () async {
      la.status = const LightningAddressStatus(nym: 'alice', active: true);
      facade.terminal = null;
      final cubit = build();
      await cubit.load();

      cubit.labelChanged('My Till');
      facade.provisionedTerminal = buildTerminal();
      await cubit.provision();

      expect(facade.provisionCallCount, 1);
      expect(cubit.state.status, PosStatus.edit);
      expect(cubit.state.submitting, isFalse);
      expect(cubit.state.terminalUrl, 'https://bullpay.ca/alice/pos');
    });

    test('surfaces an uncertain submission failure', () async {
      la.status = const LightningAddressStatus(nym: 'alice', active: true);
      facade.terminal = null;
      final cubit = build();
      await cubit.load();
      cubit.labelChanged('My Till');
      facade.provisionError = PosProvisionException.submission(
        cause: const PosException.timeout(),
      );

      await cubit.provision();

      expect(cubit.state.failure, isNotNull);
      expect(cubit.state.submissionUncertain, isTrue);
      expect(cubit.state.submitting, isFalse);
    });

    test('invalid input is refused without a wire call', () async {
      la.status = const LightningAddressStatus(nym: 'alice', active: true);
      facade.terminal = null;
      final cubit = build();
      await cubit.load();
      // label left empty -> invalid
      cubit.labelChanged('');

      await cubit.provision();

      expect(facade.provisionCallCount, 0);
      expect(cubit.state.failure?.kind, PosErrorKind.invalidInput);
    });

    test('a double-tap yields exactly one wire call', () async {
      la.status = const LightningAddressStatus(nym: 'alice', active: true);
      facade.terminal = null;
      final cubit = build();
      await cubit.load();
      cubit.labelChanged('My Till');

      final gate = Completer<void>();
      facade.provisionGate = gate.future;
      facade.provisionedTerminal = buildTerminal();

      final first = cubit.provision();
      final second = cubit
          .provision(); // inert: a provision is already in flight
      gate.complete();
      await Future.wait([first, second]);

      expect(facade.provisionCallCount, 1);
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

class _FakePosFacade implements PosFacade {
  PosTerminal? terminal;
  PosTerminal? provisionedTerminal;
  Object? provisionError;
  Object? findError;
  List<DisplayCurrency> currencies = const [];
  Object? currenciesError;
  Future<void>? provisionGate;
  int provisionCallCount = 0;

  @override
  Future<PosTerminal?> find({required String nym}) async {
    final error = findError;
    if (error != null) throw error;
    return terminal;
  }

  @override
  Future<PosTerminal> provision(PosProvisionCommand command) async {
    provisionCallCount += 1;
    final gate = provisionGate;
    if (gate != null) await gate;
    final error = provisionError;
    if (error != null) throw error;
    return provisionedTerminal ?? terminal!;
  }

  @override
  Future<PosTerminal?> archive() async => terminal;

  @override
  Future<List<DisplayCurrency>> supportedCurrencies() async {
    final error = currenciesError;
    if (error != null) throw error;
    return currencies;
  }

  @override
  Future<PosHealOutcome> ensurePosLive() async => throw UnimplementedError();
}
