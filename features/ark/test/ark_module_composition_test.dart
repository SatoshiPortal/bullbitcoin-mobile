import 'package:bull_ark/src/ui/ark_exit_request_screen.dart';

import 'ark_exit_request_screen_test.dart' as exit_input;

import 'package:bull_ark/src/ui/ark_board_amount_screen.dart';

import 'fake_ark_board_funding.dart';

import 'dart:async';

import 'package:ark/ark.dart';
import 'package:bloc/bloc.dart';
import 'package:bull_ark/ark_ui_setup.dart';
import 'package:bull_ark/src/domain/ark_failure.dart';
import 'package:bull_ark/src/domain/repositories/ark_account_registry_repository.dart';
import 'package:bull_ark/src/presentation/ark_cubit.dart';
import 'package:bull_ark/src/presentation/ark_operation_cubit.dart';
import 'package:bull_ark/src/presentation/ark_payment_cubit.dart';
import 'package:bull_ark/src/presentation/ark_receive_cubit.dart';
import 'package:bull_ark/src/ui/ark_account_screen.dart';
import 'package:bull_ark/src/ui/ark_settings_screen.dart';
import 'package:bull_ark/src/ui/ark_payment_screen.dart';
import 'package:bull_ark/src/ui/ark_receive_screen.dart';
import 'package:bull_ark/src/ui/ark_operation_review_screen.dart';
import 'package:bull_ark/src/ui/ark_snapshot_page.dart';
import 'package:bull_ark/src/ui/ark_unavailable_screen.dart';
import 'package:bull_ark/ark_ui.dart' show ArkPaymentEntry;
import 'package:bull_ui/bull_ui.dart' show BullButton, BullBorderedTile;
import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';

import 'ark_settings_flow_test.dart' show config, Selection, Preferences;
import 'ark_operations_test.dart' show account, Provisioner;
import 'ark_operation_review_screen_test.dart' show reviewed;
import 'ark_account_screen_test.dart' as account_test;

// Test-only scripted boundary. No runtime/default adapter is supplied by this suite.
class Registry implements ArkAccountRegistryRepository {
  @override
  Future<Result<void, ArkFailure>> publish(ArkAccountConfig config) async =>
      const Err(ArkFeatureStorageFailure());
  @override
  Future<Result<List<ArkAccountConfig>, ArkFailure>> list() async =>
      const Ok([]);
}

class Client extends account_test.Client {
  Completer<Result<ArkQuote, ArkWalletFailure>>? quoteReply;
  void Function()? beforeQuote;
  Client() {
    snapshot = Ok(observation());
    quoted = Ok(reviewed(account()));
    submitted = const Err(ArkStorageFailure());
    destination = const Err(ArkUnavailableFailure());
  }
  @override
  Future<Result<ArkQuote, ArkWalletFailure>> quote(
    ArkAccountId account,
    ArkQuoteRequest request,
  ) {
    beforeQuote?.call();
    final reply = quoteReply;
    if (reply == null) return super.quote(account, request);
    calls.add('quote');
    arguments.add((account, request));
    return reply.future;
  }
}

ArkSnapshot observation() => ArkSnapshot(
  account: account(),
  revision: 2,
  observedAt: DateTime.utc(2026),
  stale: false,
  tipHeight: 100,
  recovery: ArkRecoveryStatus.complete,
  vtxoCompleteness: ArkSectionCompleteness.complete,
  renewal: ArkRenewalStatus.current,
  vtxos: [
    ArkVtxo(
      id: 'v',
      amount: Sats.fromInt(1000),
      expiryHeight: 200,
      state: ArkVtxoState.spendable,
    ),
  ],
);

class Owners extends BlocObserver {
  final created = <BlocBase<Object?>>[], closed = <BlocBase<Object?>>[];
  BlocBase<Object?>? failClose;
  @override
  void onCreate(BlocBase<Object?> bloc) {
    super.onCreate(bloc);
    created.add(bloc);
  }

  @override
  void onClose(BlocBase<Object?> bloc) {
    super.onClose(bloc);
    closed.add(bloc);
    if (identical(bloc, failClose)) throw Exception('scripted cleanup failure');
  }
}

typedef _BuildMark = ({GoRouterWidgetBuilder source, GoRouterState state});

class Rig {
  final boardFunding = FakeArkBoardFunding();
  final builds = <String, List<_BuildMark>>{};
  final selection = Selection();
  final preferences = Preferences()..enabled = true;
  final client = Client();
  late final feature = make(config(), client);
  late final routing = ValueNotifier(RoutingConfig(routes: routes(feature)));
  late final router = GoRouter.routingConfig(
    routingConfig: routing,
    initialLocation: '/ark',
  );
  Rig() {
    addTearDown(() {
      router.dispose();
      routing.dispose();
    });
  }
  ArkFeature make(ArkAccountConfig captured, Client native) => ArkFeature(
    selection,
    boardFunding: boardFunding,
    config: captured,
    client: native,
    preferences: preferences,
    provisioning: Provisioner(),
    registry: Registry(),
  );
  List<RouteBase> routes(ArkFeature feature) => [
    for (final route in [
      GoRoute(path: '/', builder: (_, _) => const SizedBox.shrink()),
      ...feature.routes,
    ])
      _record(route),
  ];
  GoRoute _copy(GoRoute route, {GoRouterWidgetBuilder? builder}) => GoRoute(
    path: route.path,
    name: route.name,
    builder: builder ?? route.builder,
    pageBuilder: route.pageBuilder,
    parentNavigatorKey: route.parentNavigatorKey,
    redirect: route.redirect,
    metadata: route.metadata,
    onExit: route.onExit,
    caseSensitive: route.caseSensitive,
    routes: route.routes,
  );
  GoRoute _record(GoRoute route) {
    final source = route.builder;
    if (source == null ||
        route.pageBuilder != null ||
        route.routes.isNotEmpty) {
      throw StateError('Fixture expects flat widget-builder routes');
    }
    return _copy(
      route,
      builder: (context, state) {
        (builds[route.path] ??= []).add((source: source, state: state));
        return source(context, state);
      },
    );
  }

  void rebuildInstalledRoutes() {
    // Includes any replacement feature, never initial Rig.feature.
    final current = routing.value;
    routing.value = RoutingConfig(
      onEnter: current.onEnter,
      redirect: current.redirect,
      redirectLimit: current.redirectLimit,
      routes: [
        for (final route in current.routes)
          if (route is GoRoute && route.routes.isEmpty)
            _copy(route)
          else
            throw StateError('Fixture expects current flat GoRoutes'),
      ],
    );
  }

  _BuildMark _mark(String path) {
    final target = builds[path] ?? const <_BuildMark>[];
    expect(target, isNotEmpty, reason: 'Target builder $path must execute');
    return target.last;
  }

  int count(String path) => builds[path]?.length ?? 0;
  void _expectRebuilt(String path, _BuildMark before, int previousCount) {
    final after = _mark(path);
    expect(previousCount, greaterThan(0));
    expect(count(path), greaterThan(previousCount));
    expect(identical(after.source, before.source), true);
    expect(after.state.fullPath, before.state.fullPath);
    expect(after.state.uri, before.state.uri);
    expect(after.state.pathParameters, before.state.pathParameters);
    expect(identical(after.state.extra, before.state.extra), true);
    expect(after.state.pageKey.value, before.state.pageKey.value);
  }

  Widget app() => MaterialApp.router(
    theme: ThemeData(extensions: testBullExtensions),
    routerConfig: router,
  );
}

Future<void> frame(WidgetTester tester) async {
  await tester.pumpAndSettle();
}

BullButton button(WidgetTester tester, String label) =>
    tester.widget<BullButton>(find.widgetWithText(BullButton, label));
T page<T extends Widget>(WidgetTester tester) =>
    tester.widget<T>(find.byType(T));
Future<void> accountPage(WidgetTester tester, Rig r) async {
  await tester.pumpWidget(r.app());
  await frame(tester);
  button(tester, 'Ark').onPressed();
  await frame(tester);
}

void main() {
  late Owners owners;
  setUp(() {
    final previous = Bloc.observer;
    owners = Owners();
    Bloc.observer = owners;
    addTearDown(() {
      Bloc.observer = previous;
    });
  });
  testWidgets(
    'exits navigation reaches an explicit native quote request before submission',
    (tester) async {
      final r = Rig();
      r.client.snapshot = Ok(exit_input.inventory());
      r.client.quoted = Ok(
        ArkQuote(
          id: 'exit-review',
          account: account(),
          generation: 1,
          chainSource: Uri.parse('https://esplora.example'),
          configGeneration: 1,
          kind: ArkOperationKind.emergencyExit,
          amount: Sats.fromInt(1000),
          fee: Sats.fromInt(20),
          net: Sats.fromInt(980),
          selectedIds: ['selected'],
          observedTip: 100,
          validUntil: DateTime.utc(2030),
          destination: 'bcrt1-return',
          feeRate: FeeRate(2),
          maxClaimFee: Sats.fromInt(500),
          confirmedReserveExposure: Sats.fromInt(10000),
        ),
      );
      await accountPage(tester, r);
      page<ArkAccountScreen>(tester).onExits();
      await frame(tester);
      button(tester, 'Emergency exit').onPressed();
      await frame(tester);
      expect(find.byType(ArkExitRequestScreen), findsOneWidget);
      expect(
        r.client.calls.where((call) => call == 'quote' || call == 'submit'),
        isEmpty,
      );
      await exit_input.fill(tester);
      exit_input.review(tester).onPressed();
      await frame(tester);
      expect(find.byType(ArkOperationReviewScreen), findsOneWidget);
      final operation = page<ArkOperationReviewScreen>(tester).cubit;
      expect(operation.request, isA<ArkEmergencyExitQuoteRequest>());
      final request = operation.request as ArkEmergencyExitQuoteRequest;
      expect(request.ids, ['selected']);
      expect(request.destination, 'bcrt1-return');
      expect(request.maxClaimFee, Sats.fromInt(500));
      expect(r.client.calls.where((call) => call == 'quote'), hasLength(1));
      expect(r.client.calls.where((call) => call == 'submit'), isEmpty);
      button(tester, 'Confirm').onPressed();
      await frame(tester);
      expect(r.client.calls.where((call) => call == 'submit'), hasLength(1));
      expect(operation.state, isA<ArkOperationUncertain>());
    },
  );
  testWidgets(
    'builders keep page owner and read count; fresh entry closes exact owner before admission',
    (tester) async {
      final r = Rig();
      await accountPage(tester, r);
      final original = page<ArkAccountScreen>(tester).cubit;
      final before = r._mark('/ark/account');
      final count = r.count('/ark/account');
      r.rebuildInstalledRoutes();
      await frame(tester);
      r._expectRebuilt('/ark/account', before, count);
      expect(identical(page<ArkAccountScreen>(tester).cubit, original), true);
      expect(r.client.calls, ['read']);
      r.router.go(
        '/ark/pay',
        extra: ArkPaymentEntry(account(), destination: 'first'),
      );
      await frame(tester);
      final old = page<ArkPaymentScreen>(tester).cubit;
      final reply = Completer<Result<ArkAccountConfig, ArkFailure>>();
      r.selection.pending.add(reply.future);
      r.router.go(
        '/ark/pay',
        extra: ArkPaymentEntry(account(), destination: 'second'),
      );
      await frame(tester);
      expect(old.isClosed, true);
      expect(find.byType(ArkPaymentScreen), findsNothing);
      reply.complete(Ok(config()));
      await frame(tester);
      expect(identical(page<ArkPaymentScreen>(tester).cubit, old), false);
      expect(page<ArkPaymentScreen>(tester).initialDestination, 'second');
      expect(owners.closed.where((c) => identical(c, old)), hasLength(1));
      expect(r.client.calls, ['read']);
    },
  );
  for (final denial in ['off', 'selection-error', 'account', 'malformed']) {
    testWidgets('public payment $denial refuses BEFORE any Payment owner', (
      tester,
    ) async {
      final r = Rig();
      await tester.pumpWidget(r.app());
      await frame(tester);
      if (denial == 'off') r.preferences.enabled = false;
      if (denial == 'selection-error') {
        r.selection.pending.add(
          Future.value(const Err(ArkFeatureStorageFailure())),
        );
      }
      final id = account();
      r.router.go(
        '/ark/pay',
        extra: denial == 'malformed'
            ? Object()
            : ArkPaymentEntry(
                denial == 'account'
                    ? ArkAccountId(
                        parent: Fingerprint('11223344'),
                        network: id.network,
                        serverIdentity: id.serverIdentity,
                      )
                    : id,
              ),
      );
      await frame(tester);
      expect(find.byType(ArkPaymentScreen), findsNothing);
      expect(owners.created.whereType<ArkPaymentCubit>(), isEmpty);
      expect(r.client.calls, isEmpty);
      expect(r.preferences.writes, isEmpty);
    });
  }
  final id = account();
  final variants = [
    config(
      id: ArkAccountId(
        parent: Fingerprint('11223344'),
        network: id.network,
        serverIdentity: id.serverIdentity,
      ),
    ),
    config(
      id: ArkAccountId(
        parent: id.parent,
        network: BitcoinNetwork.mainnet,
        serverIdentity: id.serverIdentity,
      ),
    ),
    config(
      id: ArkAccountId(
        parent: id.parent,
        network: id.network,
        serverIdentity: 'other-server',
      ),
    ),
    config(ark: 'https://other-ark.example'),
    config(chain: 'https://other-chain.example'),
    config(fallback: null),
    config(threshold: 42),
  ];
  for (var i = 0; i < variants.length; i++) {
    testWidgets(
      'full-config field variant $i cannot reuse current scope from advisory extra',
      (tester) async {
        final r = Rig();
        await tester.pumpWidget(r.app());
        await frame(tester);
        r.selection.current = variants[i];
        r.router.go('/ark/pay', extra: ArkPaymentEntry(account()));
        await frame(tester);
        expect(find.byType(ArkPaymentScreen), findsNothing);
        expect(r.client.calls, isEmpty);
        expect(
          owners.created,
          hasLength(1),
        ); // Only original Settings, no Payment owner.
      },
    );
  }
  testWidgets(
    'same-config new feature/client replaces owner before delayed admission, late results discarded',
    (tester) async {
      final r = Rig();
      await accountPage(tester, r);
      r.router.go('/ark/pay', extra: ArkPaymentEntry(account()));
      await frame(tester);
      final old = page<ArkPaymentScreen>(tester).cubit;
      final reply = Completer<Result<ArkAccountConfig, ArkFailure>>();
      r.selection.pending.add(reply.future);
      final native = Client();
      final next = r.make(config(), native);
      r.routing.value = RoutingConfig(routes: r.routes(next));
      await frame(tester);
      expect(old.isClosed, true);
      next.invalidate();
      reply.complete(Ok(config()));
      await frame(tester);
      expect(find.byType(ArkPaymentScreen), findsNothing);
      expect(native.calls, isEmpty);
      expect(r.client.calls, ['read']);
      expect(owners.closed.where((c) => identical(c, old)), hasLength(1));
    },
  );
  testWidgets(
    'Settings publication checks every old parent navigation synchronously, off protection survives',
    (tester) async {
      final r = Rig();
      await tester.pumpWidget(r.app());
      await frame(tester);
      final settings = page<ArkSettingsScreen>(tester);
      final opening = settings.onOpenAccount;
      final reply = Completer<Result<ArkAccountConfig, ArkFailure>>();
      r.selection.pending.add(reply.future);
      final loading = settings.cubit.load();
      opening(config());
      expect(r.router.routeInformationProvider.value.uri.path, '/ark');
      expect(owners.created, hasLength(1));
      reply.complete(Ok(config()));
      await loading;
      await frame(tester);
      opening(
        config(),
      ); // The old Ready must not retarget the new same-config Ready.
      expect(r.router.routeInformationProvider.value.uri.path, '/ark');
      expect(owners.created, hasLength(1));
      button(tester, 'Ark').onPressed();
      await frame(tester);
      final account = page<ArkAccountScreen>(tester);
      final oldVtxos = account.onVtxos;
      final disabling = settings.cubit.disable();
      final beforeOldVtxosNavigation = r.router.routeInformationProvider.value;
      oldVtxos();
      expect(
        identical(
          r.router.routeInformationProvider.value,
          beforeOldVtxosNavigation,
        ),
        true,
      );
      expect(r.router.state.uri.path, '/ark/account');
      // This is NAVIGATION refusal, not instantaneous child-action revocation.
      expect(account.cubit.isClosed, false);
      await disabling;
      await frame(tester);
      expect(settings.cubit.isClosed, false);
      expect(account.cubit.isClosed, true);
      final beforeOldSettingsNavigation =
          r.router.routeInformationProvider.value;
      settings.onOpenAccount(config());
      expect(
        identical(
          r.router.routeInformationProvider.value,
          beforeOldSettingsNavigation,
        ),
        true,
      );
      expect(r.router.state.uri.path, '/ark/account');
      r.router.pop();
      await frame(tester);
      final currentSettings = page<ArkSettingsScreen>(tester);
      expect(identical(currentSettings.cubit, settings.cubit), true);
      currentSettings.onOpenAccount(config());
      await frame(tester);
      final protective = page<ArkAccountScreen>(tester);
      expect(protective.enabled, false);
      button(tester, 'VTXOs').onPressed();
      await frame(tester);
      expect(find.text('Review renewal'), findsOneWidget);
      expect(r.client.calls.where((c) => c != 'read'), isEmpty);
    },
  );
  testWidgets(
    'explicit Renew loads once BEFORE passive A; rebuild and consumed entry never reset unknown',
    (tester) async {
      final r = Rig();
      await accountPage(tester, r);
      button(tester, 'VTXOs').onPressed();
      await frame(tester);
      expect(r.client.calls.where((c) => c == 'quote'), isEmpty);
      tester
          .widget<BullBorderedTile>(find.byType(BullBorderedTile))
          .onTap
          ?.call();
      await frame(tester);
      final quote = Completer<Result<ArkQuote, ArkWalletFailure>>();
      r.client.quoteReply = quote;
      r.client.beforeQuote = () =>
          expect(find.byType(ArkOperationReviewScreen), findsNothing);
      button(tester, 'Review renewal').onPressed();
      await frame(tester);
      expect(r.client.calls.where((c) => c == 'quote'), hasLength(1));
      final screen = page<ArkOperationReviewScreen>(tester);
      final cubit = screen.cubit;
      final entry = GoRouterState.of(
        tester.element(find.byType(ArkOperationReviewScreen)),
      ).extra;
      quote.complete(Ok(reviewed(account())));
      await frame(tester);
      button(tester, 'Confirm').onPressed();
      await frame(tester);
      expect(cubit.state, isA<ArkOperationUncertain>());
      final unknown = cubit.state;
      final before = r._mark('/ark/review');
      final count = r.count('/ark/review');
      r.rebuildInstalledRoutes();
      await frame(tester);
      r._expectRebuilt('/ark/review', before, count);
      expect(
        identical(page<ArkOperationReviewScreen>(tester).cubit, cubit),
        true,
      );
      expect(identical(cubit.state, unknown), true);
      r.router.pop();
      await frame(tester);
      expect(cubit.isClosed, true);
      unawaited(r.router.push<void>('/ark/review', extra: entry));
      await frame(tester);
      expect(find.byType(ArkOperationReviewScreen), findsNothing);
      expect(r.client.calls.where((c) => c == 'quote'), hasLength(1));
      expect(r.client.calls.where((c) => c == 'submit'), hasLength(1));
    },
  );
  testWidgets(
    'old Review intent never requotes after host invalidates and replaces config/client',
    (tester) async {
      final r = Rig();
      await accountPage(tester, r);
      button(tester, 'VTXOs').onPressed();
      await frame(tester);
      tester
          .widget<BullBorderedTile>(find.byType(BullBorderedTile))
          .onTap
          ?.call();
      await frame(tester);
      final reply = Completer<Result<ArkQuote, ArkWalletFailure>>();
      r.client.quoteReply = reply;
      button(tester, 'Review renewal').onPressed();
      await frame(tester);
      final owner = page<ArkOperationReviewScreen>(tester).cubit;
      final pending = owner.state;
      r.feature.invalidate();
      expect(owner.isClosed, true);
      final captured = config(chain: 'https://new-chain.example');
      r.selection.current = captured;
      final native = Client();
      final next = r.make(captured, native);
      r.routing.value = RoutingConfig(routes: r.routes(next));
      await frame(tester);
      reply.complete(Ok(reviewed(account())));
      await frame(tester);
      final before = r._mark('/ark/review');
      final count = r.count('/ark/review');
      expect(
        identical(
          before.source,
          next.routes
              .singleWhere((route) => route.path == '/ark/review')
              .builder,
        ),
        true,
      );
      r.rebuildInstalledRoutes();
      await frame(tester);
      r._expectRebuilt('/ark/review', before, count);
      expect(identical(owner.state, pending), true);
      expect(find.byType(ArkOperationReviewScreen), findsNothing);
      expect(r.client.calls.where((c) => c == 'quote'), hasLength(1));
      expect(native.calls, isEmpty);
    },
  );
  testWidgets(
    'actual router refresh loses private extra and fails closed without new effects',
    (tester) async {
      final r = Rig();
      await accountPage(tester, r);
      final owner = page<ArkAccountScreen>(tester).cubit;
      final before = r._mark('/ark/account');
      expect(before.state.extra, isNotNull);
      final calls = List<String>.of(r.client.calls);
      final created = owners.created.length;
      r.router.refresh();
      await frame(tester);
      expect(r._mark('/ark/account').state.extra, isNull);
      expect(find.byType(ArkUnavailableScreen), findsOneWidget);
      expect(find.byType(ArkAccountScreen), findsNothing);
      expect(owners.created, hasLength(created));
      expect(r.client.calls, calls);
      expect(
        owner.isClosed,
        true,
      ); // UI-only close, no native cancel/settlement proof.
    },
  );
  testWidgets(
    'host invalidate closes OWN cubes synchronously before callbacks but NEVER closes client',
    (tester) async {
      final r = Rig();
      await accountPage(tester, r);
      final account = page<ArkAccountScreen>(tester);
      account.onSend();
      await frame(tester);
      final payment = page<ArkPaymentScreen>(tester).cubit;
      r.feature.invalidate();
      r.feature.invalidate();
      expect(account.cubit.isClosed, true);
      expect(payment.isClosed, true);
      final beforeInvalidatedNavigation =
          r.router.routeInformationProvider.value;
      account.onVtxos();
      expect(
        identical(
          r.router.routeInformationProvider.value,
          beforeInvalidatedNavigation,
        ),
        true,
      );
      expect(r.router.state.uri.path, '/ark/pay');
      await frame(tester);
      expect(find.byType(ArkPaymentScreen), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(
        owners.closed.where((c) => identical(c, account.cubit)),
        hasLength(1),
      );
      expect(owners.closed.where((c) => identical(c, payment)), hasLength(1));
      expect(r.client.calls, ['read']);
    },
  );
  testWidgets(
    'cleanup failure is observed without preventing notification of other OWN pages',
    (tester) async {
      final r = Rig();
      await tester.pumpWidget(r.app());
      await frame(tester);
      final settings = page<ArkSettingsScreen>(tester).cubit;
      button(tester, 'Ark').onPressed();
      await frame(tester);
      final account = page<ArkAccountScreen>(tester).cubit;
      owners.failClose = settings;
      final errors = <Object>[];
      runZonedGuarded(r.feature.invalidate, (error, _) => errors.add(error));
      expect(account.isClosed, true);
      await frame(tester);
      expect(errors, hasLength(1));
      expect(r.client.calls, ['read']);
      owners.failClose = null;
      await settings.close(); // Fixture cleanup after reported failure.
    },
  );
  testWidgets(
    'Board uses its required host while claim and absent Share stay unavailable',
    (tester) async {
      final r = Rig();
      await accountPage(tester, r);
      button(tester, 'Add funds').onPressed();
      await frame(tester);
      expect(find.byType(ArkBoardAmountScreen), findsOneWidget);
      expect(r.boardFunding.calls, isEmpty);
      r.router.pop();
      await frame(tester);
      button(tester, 'Receive').onPressed();
      await frame(tester);
      final cubit = page<ArkReceiveScreen>(tester).cubit;
      cubit.emit(
        ArkReceiveReady(
          ArkReceiveDestination(
            kind: ArkDestinationKind.ark,
            value: 'public-request',
          ),
        ),
      );
      await frame(tester);
      expect(button(tester, 'Share').disabled, true);
      r.router.go('/ark/vtxos', extra: account());
      await frame(tester);
      expect(find.byType(ArkUnavailableScreen), findsOneWidget);
      r.router.go('/ark/claim-recovery', extra: Object());
      await frame(tester);
      expect(find.byType(ArkUnavailableScreen), findsOneWidget);
      expect(r.client.calls, ['read']);
    },
  );
  testWidgets(
    'SnapshotPage owns one read and guards foreign rows, old Retry and replaced owner',
    (tester) async {
      final client = account_test.Client()
        ..snapshot = const Err(ArkUnavailableFailure());
      final a = account_test.controller(client);
      Widget display(ArkCubit owner) => MaterialApp(
        theme: ThemeData(extensions: testBullExtensions),
        home: ArkSnapshotPage(
          cubit: owner,
          builder: (_) => const Text('bound-observation'),
        ),
      );
      await tester.pumpWidget(display(a));
      await frame(tester);
      final retry = button(tester, 'Retry').onPressed;
      a.emit(
        ArkObserved(
          ArkSnapshot(
            account: ArkAccountId(
              parent: account().parent,
              network: account().network,
              serverIdentity: 'foreign',
            ),
            revision: 1,
            observedAt: DateTime.utc(2026),
          ),
        ),
      );
      await frame(tester);
      expect(find.text('bound-observation'), findsNothing);
      retry();
      expect(client.calls, ['read']);
      final delayed = Completer<Result<ArkSnapshot, ArkWalletFailure>>();
      final nextClient = account_test.Client()..readReply = delayed;
      final b = account_test.controller(nextClient);
      await tester.pumpWidget(display(b));
      await frame(tester);
      retry();
      expect(nextClient.calls, ['read']);
      expect(a.isClosed, false);
      delayed.complete(Ok(observation()));
      await frame(tester);
      await tester.pumpWidget(display(b));
      await frame(tester);
      expect(find.text('bound-observation'), findsOneWidget);
      expect(nextClient.calls, ['read']);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(b.isClosed, false);
    },
  );
  testWidgets(
    'Settings explicitly enables the injected client and reads its balance',
    (tester) async {
      final r = Rig();
      r.preferences.enabled = false;
      r.client.snapshot = Ok(
        ArkSnapshot(
          account: account(),
          revision: 3,
          observedAt: DateTime.utc(2026),
          spendable: Sats.fromInt(1234),
          stale: false,
          tipHeight: 100,
          recovery: ArkRecoveryStatus.complete,
          vtxoCompleteness: ArkSectionCompleteness.complete,
        ),
      );
      await tester.pumpWidget(r.app());
      await frame(tester);
      expect(r.client.calls, isEmpty);
      final disabledEnable = button(tester, 'Enable Ark');
      expect(disabledEnable.disabled, true);
      disabledEnable.onPressed();
      await frame(tester);
      expect(r.client.calls, isEmpty);
      button(tester, 'I understand the direct connection').onPressed();
      await frame(tester);
      final enable = button(tester, 'Enable Ark').onPressed;
      enable();
      enable();
      await frame(tester);
      expect(r.client.calls, ['create']);
      expect(r.preferences.enabled, true);
      button(tester, 'Ark').onPressed();
      await frame(tester);
      expect(find.byType(ArkAccountScreen), findsOneWidget);
      expect(find.text('1234'), findsOneWidget);
      expect(r.client.calls, ['create', 'read']);
    },
  );
}
