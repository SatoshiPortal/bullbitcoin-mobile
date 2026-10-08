import 'dart:async';

import 'package:bull_recoverbull/src/domain/repositories/recoverbull_repository.dart';
import 'package:bull_recoverbull/src/domain/usecases/allow_permission_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_permission_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/fetch_recoverbull_url_usecase.dart';
import 'package:bull_recoverbull/src/domain/usecases/store_recoverbull_url_usecase.dart';
import 'package:bull_recoverbull/src/router/recoverbull_flow.dart';
import 'package:bull_recoverbull/src/router/flow_type.dart';
import 'package:bull_recoverbull/src/ui/screens/settings_page.dart';
import 'package:bull_recoverbull/src/ui/screens/server_confirmation_page.dart';
import 'package:bull_recoverbull/generated/l10n/recoverbull_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import '../support/log_sink.dart';

class _Repository extends Mock implements RecoverBullRepository {}

void main() {
  testWidgets('caches the permission Future across rebuilds', (tester) async {
    final repository = _Repository();
    var fetchCount = 0;
    when(() => repository.fetchPermission()).thenAnswer((_) async {
      fetchCount++;
      return false;
    });

    var rebuilds = 0;
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
        home: StatefulBuilder(
          builder: (context, setState) => Column(
            children: [
              TextButton(
                onPressed: () => setState(() => rebuilds++),
                child: const Text('Rebuild'),
              ),
              Expanded(
                child: _navigator(repository, key: const ValueKey('flow')),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Rebuild'));
    await tester.pumpAndSettle();

    expect(fetchCount, 1);
  });

  testWidgets('back pops an internal page before the GoRoute', (tester) async {
    final repository = _Repository();
    when(() => repository.fetchPermission()).thenAnswer((_) async => false);

    await tester.pumpWidget(
      _TestHost(
        repository: repository,
        builder: (context, navigator) => navigator,
      ),
    );
    await tester.pumpAndSettle();

    final nestedNavigator = find.byType(Navigator).last;
    Navigator.of(tester.element(nestedNavigator)).push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Internal page')),
      ),
    );
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Internal page'), findsNothing);
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byType(RecoverBullFlowNavigator), findsOneWidget);
  });

  testWidgets('system back steps through the flow before leaving it', (
    tester,
  ) async {
    // Permission denied keeps the flow on `RequestPermissionPage`, which needs
    // no Tor or key server — only the navigation shape is under test.
    final repository = _Repository();
    when(() => repository.fetchPermission()).thenAnswer((_) async => false);
    when(
      () => repository.fetchUrl(),
    ).thenAnswer((_) async => Uri.parse('https://recoverbull.com'));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Backup settings')),
        ),
        GoRoute(
          path: '/flow',
          builder: (_, _) =>
              _navigator(repository, flow: RecoverBullFlow.viewVaultKey),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
        supportedLocales: RecoverBullLocalizations.supportedLocales,
      ),
    );
    unawaited(router.push('/flow'));
    await tester.pumpAndSettle();
    expect(find.byType(RequestPermissionPage), findsOneWidget);

    // A deeper page inside the flow, pushed the way the flow's pages do.
    final nested = tester.state<NavigatorState>(
      find
          .ancestor(
            of: find.byType(RequestPermissionPage),
            matching: find.byType(Navigator),
          )
          .first,
    );
    unawaited(
      nested.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('Deeper page')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Deeper page'), findsOneWidget);

    // First back pops only the nested page; the flow stays open.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Deeper page'), findsNothing);
    expect(find.byType(RequestPermissionPage), findsOneWidget);

    // Second back, on the flow's first page, leaves the flow.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.byType(RecoverBullFlowNavigator), findsNothing);
    expect(find.text('Backup settings'), findsOneWidget);
  });
}

RecoverBullFlowNavigator _navigator(
  _Repository repository, {
  Key? key,
  RecoverBullFlow flow = RecoverBullFlow.settings,
}) => RecoverBullFlowNavigator(
  key: key,
  flow: flow,
  fetchPermissionUsecase: FetchPermissionUsecase(
    recoverBullRepository: repository,
  ),
  settingsPageBuilder: (context) => SettingsPage(
    log: const TestLogSink(),
    fetchUrlUsecase: FetchRecoverbullUrlUsecase(
      recoverBullRepository: repository,
    ),
    storeUrlUsecase: StoreRecoverbullUrlUsecase(
      recoverBullRepository: repository,
    ),
  ),
  requestPermissionPageBuilder: (context) => RequestPermissionPage(
    log: const TestLogSink(),
    fetchUrlUsecase: FetchRecoverbullUrlUsecase(
      recoverBullRepository: repository,
    ),
    allowPermissionUsecase: AllowPermissionUsecase(
      recoverBullRepository: repository,
    ),
  ),
);

class _TestHost extends StatelessWidget {
  final _Repository repository;
  final Widget Function(BuildContext context, Widget navigator) builder;

  const _TestHost({required this.repository, required this.builder});

  @override
  Widget build(BuildContext context) {
    final navigator = _navigator(repository);
    return MaterialApp(
      localizationsDelegates: RecoverBullLocalizations.localizationsDelegates,
      supportedLocales: RecoverBullLocalizations.supportedLocales,
      home: Builder(builder: (context) => builder(context, navigator)),
    );
  }
}
