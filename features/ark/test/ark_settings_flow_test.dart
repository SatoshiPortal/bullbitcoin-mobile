import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/ark_account_selection_port.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/repositories/ark_preferences_repository.dart';
import 'package:bull_ark/src/domain/usecases/load_ark_settings_usecase.dart';
import 'package:bull_ark/src/domain/usecases/enable_ark_usecase.dart';
import 'package:bull_ark/src/domain/usecases/set_ark_enabled_usecase.dart';
import 'package:bull_ark/src/domain/usecases/read_ark_next_round_usecase.dart';
import 'package:bull_ark/src/presentation/ark_next_round_cubit.dart';
import 'package:bull_ark/src/presentation/ark_settings_cubit.dart';
import 'package:bull_ark/src/ui/ark_settings_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullSwitch;
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

import 'ark_operations_test.dart' show account, snapshot, Provisioner;
import 'fake_ark_client.dart';

ArkAccountConfig config({
  ArkAccountId? id,
  String ark = 'https://ark.example',
  String chain = 'https://chain.example',
  String? fallback = 'https://fallback.example',
  int threshold = 1008,
}) => ArkAccountConfig(
  id: id ?? account(),
  arkUrl: Uri.parse(ark),
  primaryEsploraUrl: Uri.parse(chain),
  fallbackEsploraUrl: fallback == null ? null : Uri.parse(fallback),
  renewalThresholdBlocks: threshold,
);

class Selection implements ArkAccountSelectionPort {
  ArkAccountConfig current = config();
  final pending = <Future<Result<ArkAccountConfig, ArkFailure>>>[];
  @override
  Future<Result<ArkAccountConfig, ArkFailure>> selectedAccount() =>
      pending.isEmpty ? Future.value(Ok(current)) : pending.removeAt(0);
}

class Preferences implements ArkPreferencesRepository {
  bool enabled = false;
  bool failEnable = false;
  final writes = <(ArkAccountId, bool)>[];
  @override
  Future<Result<bool, ArkFailure>> isEnabled(ArkAccountId account) async =>
      Ok(enabled);
  @override
  Future<Result<void, ArkFailure>> setEnabled(
    ArkAccountId account,
    bool value,
  ) async {
    writes.add((account, value));
    if (value && failEnable) return const Err(ArkFeatureStorageFailure());
    enabled = value;
    return const Ok(null);
  }
}

class Client extends FakeArkClient {
  Completer<Result<ArkSnapshot, ArkWalletFailure>>? pending;
  @override
  Future<Result<ArkSnapshot, ArkWalletFailure>> create(
    ArkAccountConfig config,
  ) {
    calls.add('create');
    arguments.add(config);
    return pending?.future ?? Future.value(this.snapshot);
  }
}

class Fixture {
  Fixture() {
    // The page closes its next-round helper; tests stand in for the page.
    addTearDown(() => rounds.close());
  }
  final selection = Selection();
  final preferences = Preferences();
  final client = Client()..snapshot = Ok(snapshot(account()));
  late final repository = ArkRepositoryImpl(client);
  late final cubit = ArkSettingsCubit(
    LoadArkSettingsUsecase(selection, preferences),
    EnableArkUsecase(repository, preferences, Provisioner()),
    SetArkEnabledUsecase(repository, preferences),
  );
  final opened = <String>[];
  DateTime clock = DateTime.utc(2026, 11, 19, 12);
  late final rounds = ArkNextRoundCubit(
    ReadArkNextRoundUsecase(repository),
    now: () => clock,
  );
  Widget app() => MaterialApp(
    theme: ThemeData(extensions: testBullExtensions),
    home: ArkSettingsScreen(
      cubit: cubit,
      onOpenAccount: (_) => opened.add('account'),
      onInfo: () => opened.add('info'),
      onVtxos: () => opened.add('vtxos'),
      onBoard: () => opened.add('board'),
      onExits: () => opened.add('exits'),
      nextRound: rounds,
    ),
  );

  /// Wallet lifecycle calls, without the settings card's next-round reads.
  List<String> get walletCalls =>
      client.calls.where((c) => c != 'next-round').toList();
  int get roundRequests => client.calls.where((c) => c == 'next-round').length;
}

void main() {
  testWidgets(
    'turning Ark on asks consent to the providers shown and then creates',
    (tester) async {
      final f = Fixture();
      addTearDown(f.cubit.close);
      await tester.pumpWidget(f.app());
      await tester.pumpAndSettle();
      expect(find.text('Ark is off'), findsOneWidget);
      await tester.tap(find.byType(BullSwitch));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ark-consent')), findsOneWidget);
      expect(find.textContaining('https://ark.example'), findsOneWidget);
      expect(find.textContaining('https://chain.example'), findsOneWidget);
      expect(find.textContaining('https://fallback.example'), findsOneWidget);
      expect(f.walletCalls, isEmpty);
      await tester.tap(find.text('I understand'));
      await tester.pumpAndSettle();
      expect(f.walletCalls, ['create']);
      expect(f.cubit.state.settings?.enabled, true);
      expect(find.text('Next round'), findsOneWidget);
      expect(find.text('Board to Ark'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('cancelling the consent dialog keeps Ark off', (tester) async {
    final f = Fixture();
    addTearDown(f.cubit.close);
    await tester.pumpWidget(f.app());
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BullSwitch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(f.walletCalls, isEmpty);
    expect(f.preferences.writes, isEmpty);
    expect(tester.widget<BullSwitch>(find.byType(BullSwitch)).value, false);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'a provider change while the consent dialog is open cannot reuse that consent',
    (tester) async {
      for (final next in [
        config(ark: 'https://changed.example'),
        config(chain: 'https://changed-chain.example'),
        config(fallback: null),
        config(threshold: 144),
        config(
          id: ArkAccountId(
            parent: Fingerprint('44556677'),
            network: BitcoinNetwork.regtest,
            serverIdentity: 'other-server',
          ),
        ),
      ]) {
        final f = Fixture();
        await tester.pumpWidget(f.app());
        await tester.pumpAndSettle();
        await tester.tap(find.byType(BullSwitch));
        await tester.pumpAndSettle();
        f.selection.current = next;
        await f.cubit.load();
        await tester.tap(find.text('I understand'));
        await tester.pumpAndSettle();
        expect(f.walletCalls, isEmpty);
        expect(f.preferences.writes, isEmpty);
        await tester.pumpWidget(const SizedBox.shrink());
        await f.cubit.close();
      }
    },
  );
  testWidgets(
    'while off, every Ark row is hidden and only the switch remains',
    (tester) async {
      final f = Fixture();
      addTearDown(f.cubit.close);
      await tester.pumpWidget(f.app());
      await tester.pumpAndSettle();
      for (final label in [
        'Ark wallet',
        'Ark info',
        'VTXOs',
        'Board to Ark',
        'Emergency exit',
      ]) {
        expect(find.text(label), findsNothing);
      }
      expect(find.byType(BullSwitch), findsOneWidget);
      expect(f.opened, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'late read cannot rearm a pending mutation or change its captured config',
    () async {
      final f = Fixture();
      addTearDown(f.cubit.close);
      await f.cubit.load();
      final old = Completer<Result<ArkAccountConfig, ArkFailure>>();
      f.selection.pending.add(old.future);
      final reading = f.cubit.load();
      await f.cubit.load();
      f.client.pending = Completer<Result<ArkSnapshot, ArkWalletFailure>>();
      final enabling = f.cubit.enable(privacyDisclosureAccepted: true);
      await Future<void>.delayed(Duration.zero);
      expect(f.walletCalls, ['create']);
      try {
        old.complete(Ok(config(ark: 'https://stale.example')));
        await reading;
        expect(f.cubit.state.busy, true);
        await f.cubit.enable(privacyDisclosureAccepted: true);
        expect(f.walletCalls, ['create']);
      } finally {
        f.client.pending?.complete(Ok(snapshot(account())));
        await enabling;
      }
      expect(f.cubit.state.settings?.config.arkUrl, config().arkUrl);
    },
  );
  test('reverse completed reads cannot revive an older selection', () async {
    final f = Fixture();
    addTearDown(f.cubit.close);
    final old = Completer<Result<ArkAccountConfig, ArkFailure>>();
    f.selection.pending.add(old.future);
    final reading = f.cubit.load();
    f.selection.current = config(ark: 'https://latest.example');
    await f.cubit.load();
    old.complete(Ok(config()));
    await reading;
    expect(
      f.cubit.state.settings?.config.arkUrl,
      Uri.parse('https://latest.example'),
    );
  });
  test('consent and mainnet refuse before create; funded-off disable changes only preference', () async {
    final f = Fixture();
    addTearDown(f.cubit.close);
    await f.cubit.load();
    await f.cubit.enable(privacyDisclosureAccepted: false);
    expect(f.cubit.state.failure, isA<ArkPrivacyDisclosureFailure>());
    f.selection.current = config(
      id: ArkAccountId(
        parent: account().parent,
        network: BitcoinNetwork.mainnet,
        serverIdentity: account().serverIdentity,
      ),
    );
    await f.cubit.load();
    await f.cubit.enable(privacyDisclosureAccepted: true);
    expect(f.cubit.state.failure, isA<ArkNetworkUnavailableFailure>());
    expect(f.walletCalls, isEmpty);
    expect(f.preferences.writes, isEmpty);
    f.selection.current = config();
    f.preferences.enabled = true;
    await f.cubit.load();
    await f.cubit.disable();
    expect(f.preferences.writes, [(account(), false)]);
    expect(f.cubit.state.settings?.enabled, false);
    expect(f.walletCalls, isEmpty);
  });
  testWidgets(
    'explicit retry after create and preference error retains the same config',
    (tester) async {
      final f = Fixture();
      addTearDown(f.cubit.close);
      f.preferences.failEnable = true;
      await tester.pumpWidget(f.app());
      await tester.pumpAndSettle();
      final captured = f.selection.current;
      await f.cubit.enable(privacyDisclosureAccepted: true);
      expect(f.walletCalls, ['create']);
      expect(f.cubit.state.failure, isA<ArkFeatureStorageFailure>());
      await tester.pumpAndSettle();
      expect(find.text('Ark is unavailable. Try again.'), findsOneWidget);
      expect(identical(f.cubit.state.settings?.config, captured), true);
      f.preferences.failEnable = false;
      await f.cubit.enable(privacyDisclosureAccepted: true);
      expect(f.walletCalls, ['create', 'create']);
      expect(f.client.arguments.every((arg) => identical(arg, captured)), true);
      expect(f.cubit.state.settings?.enabled, true);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'pending creation disables the switch; closing does not cancel admitted effects',
    (tester) async {
      final f = Fixture();
      final held = Completer<Result<ArkSnapshot, ArkWalletFailure>>();
      f.client.pending = held;
      await tester.pumpWidget(f.app());
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BullSwitch));
      await tester.pumpAndSettle();
      await tester.tap(find.text('I understand'));
      await tester.pump();
      await tester.pump();
      expect(
        tester.widget<BullSwitch>(find.byType(BullSwitch)).onChanged,
        isNull,
      );
      await f.cubit.load();
      await f.cubit.disable();
      expect(f.walletCalls, ['create']);
      expect(f.preferences.writes, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(f.cubit.isClosed, false);
      await f.cubit.close();
      held.complete(Ok(snapshot(account())));
      await tester.pump();
      expect(f.preferences.writes, [(account(), true)]);
      expect(f.walletCalls, ['create']);
    },
  );
  testWidgets(
    'replacement detaches the old read; consent shows the current providers',
    (tester) async {
      final first = Fixture(), second = Fixture();
      addTearDown(first.cubit.close);
      addTearDown(second.cubit.close);
      final old = Completer<Result<ArkAccountConfig, ArkFailure>>();
      first.selection.pending.add(old.future);
      second.selection.current = config(ark: 'https://new-visible.example');
      await tester.pumpWidget(first.app());
      await tester.pump();
      await tester.pumpWidget(second.app());
      await tester.pumpAndSettle();
      old.complete(Ok(config()));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(BullSwitch));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('https://new-visible.example'),
        findsOneWidget,
      );
      expect(find.textContaining('https://ark.example'), findsNothing);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(first.client.calls, isEmpty);
      expect(second.client.calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(first.cubit.isClosed, false);
      expect(second.cubit.isClosed, false);
    },
  );

  group('next round', () {
    testWidgets('while on, counts down to the server start time', (
      tester,
    ) async {
      final f = Fixture();
      f.preferences.enabled = true;
      f.client.nextRoundStart = Ok(f.clock.add(const Duration(seconds: 290)));
      addTearDown(f.cubit.close);
      await tester.pumpWidget(f.app());
      await tester.pump();
      await tester.pump();
      expect(find.text('in 5 min.'), findsOneWidget);
      expect(f.roundRequests, 1);
      f.clock = f.clock.add(const Duration(seconds: 250));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('in 40 sec.'), findsOneWidget);
      f.clock = f.clock.add(const Duration(seconds: 40));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Now'), findsOneWidget);
      // The countdown is local: only the start of the round triggers a new
      // server request, not each tick.
      expect(f.roundRequests, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('asks again once the scheduled round has started', (
      tester,
    ) async {
      final f = Fixture();
      f.preferences.enabled = true;
      f.client.nextRoundStart = Ok(f.clock.add(const Duration(minutes: 2)));
      addTearDown(f.cubit.close);
      await tester.pumpWidget(f.app());
      await tester.pump();
      await tester.pump();
      expect(f.roundRequests, 1);
      f.clock = f.clock.add(const Duration(minutes: 2));
      f.client.nextRoundStart = Ok(f.clock.add(const Duration(minutes: 10)));
      await tester.pump(const Duration(minutes: 2));
      await tester.pump();
      expect(f.roundRequests, 2);
      expect(find.text('in 10 min.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('while off, never asks the server', (tester) async {
      final f = Fixture();
      addTearDown(f.cubit.close);
      await tester.pumpWidget(f.app());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(minutes: 5));
      expect(f.roundRequests, 0);
      expect(find.text('Next round'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('an unreachable server shows Unavailable and retries', (
      tester,
    ) async {
      final f = Fixture();
      f.preferences.enabled = true;
      addTearDown(f.cubit.close);
      await tester.pumpWidget(f.app());
      await tester.pump();
      await tester.pump();
      expect(find.text('Unavailable'), findsOneWidget);
      expect(f.roundRequests, 1);
      f.client.nextRoundStart = Ok(f.clock.add(const Duration(minutes: 3)));
      await tester.pump(f.rounds.retryAfter);
      await tester.pump();
      expect(f.roundRequests, 2);
      expect(find.text('in 3 min.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('turning Ark off stops asking the server', (tester) async {
      final f = Fixture();
      f.preferences.enabled = true;
      addTearDown(f.cubit.close);
      await tester.pumpWidget(f.app());
      await tester.pump();
      await tester.pump();
      expect(f.roundRequests, 1);
      await f.cubit.disable();
      await tester.pump();
      expect(f.rounds.state, isA<ArkNextRoundIdle>());
      await tester.pump(const Duration(minutes: 5));
      expect(f.roundRequests, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
