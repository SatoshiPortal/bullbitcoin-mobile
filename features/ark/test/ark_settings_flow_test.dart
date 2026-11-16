import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bull_ark/src/data/ark_repository_impl.dart';
import 'package:bull_ark/src/domain/ark_account_selection_port.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/repositories/ark_preferences_repository.dart';
import 'package:bull_ark/src/domain/usecases/load_ark_settings_usecase.dart';
import 'package:bull_ark/src/domain/usecases/enable_ark_usecase.dart';
import 'package:bull_ark/src/domain/usecases/set_ark_enabled_usecase.dart';
import 'package:bull_ark/src/presentation/ark_settings_cubit.dart';
import 'package:bull_ark/src/ui/ark_settings_screen.dart';
import 'package:bull_ui/bull_ui.dart' show BullButton;
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
  final selection = Selection();
  final preferences = Preferences();
  final client = Client()..snapshot = Ok(snapshot(account()));
  late final repository = ArkRepositoryImpl(client);
  late final cubit = ArkSettingsCubit(
    LoadArkSettingsUsecase(selection, preferences),
    EnableArkUsecase(repository, preferences, Provisioner()),
    SetArkEnabledUsecase(repository, preferences),
  );
  Widget app({ValueChanged<ArkAccountConfig>? opened}) => MaterialApp(
    theme: ThemeData(extensions: testBullExtensions),
    home: ArkSettingsScreen(cubit: cubit, onOpenAccount: opened ?? (_) {}),
  );
}

void main() {
  testWidgets(
    'same-account changed provider cannot reuse prior disclosure consent',
    (tester) async {
      final f = Fixture();
      addTearDown(f.cubit.close);
      await tester.pumpWidget(f.app());
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('I understand the direct connection'),
      );
      await tester.tap(find.text('I understand the direct connection'));
      await tester.pump();
      expect(
        tester
            .widget<BullButton>(find.widgetWithText(BullButton, 'Enable Ark'))
            .disabled,
        false,
      );
      f.selection.current = config(ark: 'https://changed.example');
      await f.cubit.load();
      await tester.pumpAndSettle();
      expect(find.text('https://changed.example'), findsOneWidget);
      expect(
        tester
            .widget<BullButton>(find.widgetWithText(BullButton, 'Enable Ark'))
            .disabled,
        true,
      );
      expect(f.client.calls, isEmpty);
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
      expect(f.client.calls, ['create']);
      try {
        old.complete(Ok(config(ark: 'https://stale.example')));
        await reading;
        expect(f.cubit.state.busy, true);
        await f.cubit.enable(privacyDisclosureAccepted: true);
        expect(f.client.calls, ['create']);
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
    expect(f.client.calls, isEmpty);
    expect(f.preferences.writes, isEmpty);
    f.selection.current = config();
    f.preferences.enabled = true;
    await f.cubit.load();
    await f.cubit.disable();
    expect(f.preferences.writes, [(account(), false)]);
    expect(f.cubit.state.settings?.enabled, false);
    expect(f.client.calls, isEmpty);
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
      expect(f.client.calls, ['create']);
      expect(f.cubit.state.failure, isA<ArkFeatureStorageFailure>());
      await tester.pumpAndSettle();
      expect(find.text('Ark is unavailable. Try again.'), findsOneWidget);
      expect(find.textContaining('Ark is off for new payments.'), findsNothing);
      expect(identical(f.cubit.state.settings?.config, captured), true);
      f.preferences.failEnable = false;
      await f.cubit.enable(privacyDisclosureAccepted: true);
      expect(f.client.calls, ['create', 'create']);
      expect(f.client.arguments.every((arg) => identical(arg, captured)), true);
      expect(f.cubit.state.settings?.enabled, true);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'full config changes reset consent and a stale callback cannot grant it',
    (tester) async {
      final f = Fixture();
      addTearDown(f.cubit.close);
      await tester.pumpWidget(f.app());
      await tester.pumpAndSettle();
      final enable = find.widgetWithText(BullButton, 'Enable Ark');
      expect(
        tester.getTopLeft(find.text('https://ark.example')).dy,
        lessThan(tester.getTopLeft(enable).dy),
      );
      expect(
        find.textContaining('Ark connects directly without Tor.'),
        findsOneWidget,
      );
      for (final next in [
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
        await tester.ensureVisible(
          find.text('I understand the direct connection'),
        );
        await tester.tap(find.text('I understand the direct connection'));
        await tester.pump();
        final staleButton = tester.widget<BullButton>(enable);
        expect(staleButton.disabled, false);
        f.selection.current = next;
        await f.cubit.load();
        staleButton.onPressed();
        await tester.pumpAndSettle();
        expect(tester.widget<BullButton>(enable).disabled, true);
        expect(f.client.calls, isEmpty);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'pending creation disables consent and controls; closing does not cancel admitted effects',
    (tester) async {
      final f = Fixture();
      final held = Completer<Result<ArkSnapshot, ArkWalletFailure>>();
      f.client.pending = held;
      await tester.pumpWidget(f.app());
      await tester.pumpAndSettle();
      final consent = find.widgetWithText(
        BullButton,
        'I understand the direct connection',
      );
      final enable = find.widgetWithText(BullButton, 'Enable Ark');
      await tester.ensureVisible(consent);
      await tester.tap(consent);
      await tester.pump();
      await tester.ensureVisible(enable);
      await tester.tap(enable);
      await tester.pump();
      expect(tester.widget<BullButton>(consent).disabled, true);
      expect(tester.widget<BullButton>(enable).disabled, true);
      await f.cubit.load();
      await f.cubit.disable();
      expect(f.client.calls, ['create']);
      expect(f.preferences.writes, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(f.cubit.isClosed, false);
      await f.cubit.close();
      held.complete(Ok(snapshot(account())));
      await tester.pump();
      expect(f.preferences.writes, [(account(), true)]);
      expect(f.client.calls, ['create']);
    },
  );
  testWidgets(
    'replacement detaches old read and details callback uses current config without owning Cubit',
    (tester) async {
      final first = Fixture(), second = Fixture();
      addTearDown(first.cubit.close);
      addTearDown(second.cubit.close);
      final old = Completer<Result<ArkAccountConfig, ArkFailure>>();
      first.selection.pending.add(old.future);
      second.selection.current = config(ark: 'https://new-visible.example');
      ArkAccountConfig? opened;
      await tester.pumpWidget(first.app());
      await tester.pump();
      await tester.pumpWidget(second.app(opened: (config) => opened = config));
      await tester.pumpAndSettle();
      old.complete(Ok(config()));
      await tester.pumpAndSettle();
      expect(find.text('https://new-visible.example'), findsOneWidget);
      expect(find.text('https://ark.example'), findsNothing);
      final details = find.widgetWithText(BullButton, 'Ark');
      await tester.ensureVisible(details);
      await tester.tap(details);
      await tester.pump();
      expect(identical(opened, second.selection.current), true);
      expect(first.client.calls, isEmpty);
      expect(second.client.calls, isEmpty);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(first.cubit.isClosed, false);
      expect(second.cubit.isClosed, false);
    },
  );
}
