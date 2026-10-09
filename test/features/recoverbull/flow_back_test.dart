import 'dart:async';

import 'package:bb_mobile/core/recoverbull/domain/usecases/allow_permission_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_permission_usecase.dart';
import 'package:bb_mobile/core/recoverbull/domain/usecases/fetch_recoverbull_url_usecase.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/recoverbull/flow.dart';
import 'package:bb_mobile/features/recoverbull/presentation/bloc.dart';
import 'package:bb_mobile/features/recoverbull/ui/pages/server_confirmation_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _FakeRecoverBullBloc extends Fake implements RecoverBullBloc {
  final StreamController<RecoverBullState> _states =
      StreamController<RecoverBullState>.broadcast();

  @override
  RecoverBullState get state =>
      const RecoverBullState(flow: RecoverBullFlow.viewVaultKey);

  @override
  Stream<RecoverBullState> get stream => _states.stream;

  @override
  void add(RecoverBullEvent event) {}

  @override
  Future<void> close() => _states.close();
}

// Permission denied keeps the flow on `RequestPermissionPage`, which needs no
// Tor or key server — only the navigation shape is under test.
class _FakeFetchPermissionUsecase extends Fake
    implements FetchPermissionUsecase {
  @override
  Future<bool> execute() async => false;
}

class _FakeFetchRecoverbullUrlUsecase extends Fake
    implements FetchRecoverbullUrlUsecase {
  @override
  Future<Uri> execute() async => Uri.parse('https://recoverbull.com');
}

class _FakeAllowPermissionUsecase extends Fake
    implements AllowPermissionUsecase {}

void main() {
  setUp(() {
    locator
      ..registerSingleton<FetchPermissionUsecase>(_FakeFetchPermissionUsecase())
      ..registerSingleton<FetchRecoverbullUrlUsecase>(
        _FakeFetchRecoverbullUrlUsecase(),
      )
      ..registerSingleton<AllowPermissionUsecase>(
        _FakeAllowPermissionUsecase(),
      );
  });

  tearDown(() {
    locator
      ..unregister<FetchPermissionUsecase>()
      ..unregister<FetchRecoverbullUrlUsecase>()
      ..unregister<AllowPermissionUsecase>();
  });

  testWidgets('system back steps through the flow before leaving it', (
    tester,
  ) async {
    final bloc = _FakeRecoverBullBloc();
    addTearDown(bloc.close);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Backup settings')),
        ),
        GoRoute(
          path: '/flow',
          builder: (_, _) => BlocProvider<RecoverBullBloc>.value(
            value: bloc,
            child: const RecoverBullFlowNavigator(),
          ),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
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
