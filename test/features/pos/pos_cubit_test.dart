import 'dart:async';

import 'package:bb_mobile/core/wallet/domain/usecases/update_wallet_behavior_usecase.dart';
import 'package:bb_mobile/features/get_paid_settings/domain/usecases/get_get_paid_wallet_behaviors_usecase.dart';
import 'package:bb_mobile/features/pos/domain/usecases/get_pos_permanent_name_usecase.dart';
import 'package:bb_mobile/features/pos/presentation/pos_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/pos_state.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late _FakeGetPosPermanentNameUsecase permanentName;
  late _FakePosFacade facade;
  late _FakeGetGetPaidWalletBehaviorsUsecase walletBehaviors;
  late _FakeUpdateWalletBehaviorUsecase updateWalletBehavior;

  PosCubit build() => PosCubit(
    facade: facade,
    getPermanentName: permanentName,
    getWalletBehaviors: walletBehaviors,
    updateWalletBehavior: updateWalletBehavior,
  );

  PosTerminal buildTerminal({bool archived = false, String? alias}) =>
      PosTerminal(
        nym: 'alice',
        label: 'My Till',
        displayCurrency: 'USD',
        enabled: true,
        isArchived: archived,
        alias: alias,
        terminalUrl: alias == null
            ? 'https://bullpay.ca/alice/pos'
            : 'https://bullpay.ca/a/$alias/pos',
      );

  setUp(() {
    permanentName = _FakeGetPosPermanentNameUsecase();
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
      permanentName.value = const PosPermanentName.unclaimed();
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PosStatus.needsNym);
    });

    test('nym but no pos -> create with the fallback currency', () async {
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
      facade.terminal = buildTerminal(archived: true);
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PosStatus.archived);
    });

    test('nym lookup failure -> loadFailed', () async {
      permanentName.error = const PosException.network();
      final cubit = build();

      await cubit.load();

      expect(cubit.state.status, PosStatus.loadFailed);
    });

    test(
      'server load failure still exposes the local wallet behavior',
      () async {
        permanentName.error = const PosException.network();
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
        facade.findError = const PosException.invalidServerResponse();
        final cubit = build();

        await cubit.load();

        expect(cubit.state.status, PosStatus.loadFailed);
        expect(cubit.state.failure?.kind, PosErrorKind.invalidServerResponse);
      },
    );

    test(
      'missing exact capability hides alias and availability actions',
      () async {
        permanentName.value = const PosPermanentName.unsupported();
        facade.terminal = buildTerminal();

        final cubit = build();
        await cubit.load();

        expect(cubit.state.status, PosStatus.unsupported);
        expect(facade.findCallCount, 0);
        expect(cubit.state.permanentAlias, isNull);
      },
    );

    test(
      'reconstructs the shared alias after local app state is wiped',
      () async {
        permanentName.value = const PosPermanentName.claimed(
          nym: 'alice',
          alias: 'shop',
        );
        facade.terminal = buildTerminal(alias: 'shop');

        final first = build();
        await first.load();
        expect(first.state.permanentAlias, 'shop');
        await first.close();

        final afterAppStateWipe = build();
        await afterAppStateWipe.load();
        expect(afterAppStateWipe.state.permanentAlias, 'shop');
        expect(afterAppStateWipe.state.aliasDraft, isEmpty);
      },
    );

    test(
      'fails closed when terminal alias disagrees with owner state',
      () async {
        permanentName.value = const PosPermanentName.claimed(
          nym: 'alice',
          alias: 'shop',
        );
        facade.terminal = buildTerminal(alias: 'other');

        final cubit = build();
        await cubit.load();

        expect(cubit.state.status, PosStatus.loadFailed);
        expect(cubit.state.failure?.kind, PosErrorKind.invalidServerResponse);
      },
    );
  });

  test('an unclaimed nym exposes no POS-owned name mutation', () async {
    permanentName.value = const PosPermanentName.unclaimed();
    final cubit = build();
    await cubit.load();

    expect(cubit.state.status, PosStatus.needsNym);
    expect(facade.provisionCallCount, 0);
    expect(facade.archiveCallCount, 0);
  });

  group('provision', () {
    test('success moves to edit with the returned terminal', () async {
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

    test(
      'normalizes and submits the optional first shared alias claim',
      () async {
        facade.terminal = null;
        final cubit = build();
        await cubit.load();
        cubit
          ..aliasDraftChanged('  Shop  ')
          ..labelChanged('My Till');
        facade.provisionedTerminal = buildTerminal(alias: 'shop');

        await cubit.provision();

        expect(facade.lastCommand?.aliasClaim, 'shop');
        expect(cubit.state.permanentAlias, 'shop');
        expect(cubit.state.aliasDraft, isEmpty);
      },
    );

    test('structured owned-alias conflict adopts the server alias', () async {
      facade.terminal = null;
      final cubit = build();
      await cubit.load();
      cubit
        ..aliasDraftChanged('other')
        ..labelChanged('My Till');
      facade.provisionError = PosProvisionException.submission(
        cause: const PosException.aliasAlreadyAssigned(ownedAlias: 'shop'),
      );

      await cubit.provision();

      expect(cubit.state.permanentAlias, 'shop');
      expect(cubit.state.aliasDraft, isEmpty);
      expect(cubit.state.submissionUncertain, isFalse);
    });

    test('alias namespace conflict points at only the alias field', () async {
      facade.terminal = null;
      final cubit = build();
      await cubit.load();
      cubit
        ..aliasDraftChanged('taken')
        ..labelChanged('My Till');
      facade.provisionError = PosProvisionException.submission(
        cause: const PosException.aliasTaken(),
      );

      await cubit.provision();

      expect(cubit.state.invalidField, PosField.alias);
      expect(cubit.state.submissionUncertain, isFalse);
    });
  });

  test(
    'availability switch archives only POS and preserves shared alias',
    () async {
      permanentName.value = const PosPermanentName.claimed(
        nym: 'alice',
        alias: 'shop',
      );
      facade.terminal = buildTerminal(alias: 'shop');
      final cubit = build();
      await cubit.load();

      facade.terminal = buildTerminal(archived: true, alias: 'shop');
      await cubit.setOnline(false);

      expect(facade.archiveCallCount, 1);
      expect(facade.provisionCallCount, 0);
      expect(cubit.state.status, PosStatus.archived);
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

class _FakeGetPosPermanentNameUsecase implements GetPosPermanentNameUsecase {
  PosPermanentName value = const PosPermanentName.claimed(nym: 'alice');
  Object? error;

  @override
  Future<PosPermanentName> execute() async {
    final currentError = error;
    if (currentError != null) throw currentError;
    return value;
  }
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
  int findCallCount = 0;
  int archiveCallCount = 0;
  PosProvisionCommand? lastCommand;

  @override
  Future<PosTerminal?> find({required String nym}) async {
    findCallCount += 1;
    final error = findError;
    if (error != null) throw error;
    return terminal;
  }

  @override
  Future<PosTerminal> provision(PosProvisionCommand command) async {
    provisionCallCount += 1;
    lastCommand = command;
    final gate = provisionGate;
    if (gate != null) await gate;
    final error = provisionError;
    if (error != null) throw error;
    return provisionedTerminal ?? terminal!;
  }

  @override
  Future<PosTerminal?> archive() async {
    archiveCallCount += 1;
    return terminal;
  }

  @override
  Future<List<DisplayCurrency>> supportedCurrencies() async {
    final error = currenciesError;
    if (error != null) throw error;
    return currencies;
  }

  @override
  Future<PosHealOutcome> ensurePosLive() async => throw UnimplementedError();
}
