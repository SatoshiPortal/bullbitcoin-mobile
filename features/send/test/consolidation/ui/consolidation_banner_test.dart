import 'dart:async';

import 'package:bull_ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:send/send.dart';
import 'package:send/setup.dart' show SendLocalizations;

import '../../payment/testing/send_test_localizations.dart';

class _Consolidation extends Mock implements Consolidation {}

void main() {
  late _Consolidation consolidation;
  late SendLocalizations l10n;

  setUp(() async {
    consolidation = _Consolidation();
    l10n = await SendLocalizations.delegate.load(const Locale('en'));
  });

  Widget app(Widget child) => MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    localizationsDelegates: sendTestLocalizationsDelegates,
    supportedLocales: SendLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  testWidgets('home renders only required named wallets after loading', (
    tester,
  ) async {
    final pending = Completer<Result<bool, ConsolidationStatusFailure>>();
    when(() => consolidation.isRequired('one'))
        .thenAnswer((_) => pending.future);
    when(() => consolidation.isRequired('two'))
        .thenAnswer((_) async => const Ok(false));

    await tester.pumpWidget(
      app(
        HomeConsolidationBanner(
          consolidation: consolidation,
          wallets: const [
            (walletId: 'one', walletName: 'Savings'),
            (walletId: 'two', walletName: 'Spending'),
          ],
          isRefreshing: false,
        ),
      ),
    );
    expect(
      find.text(l10n.consolidationRequiredTitleNamed('Savings')),
      findsNothing,
    );
    pending.complete(const Ok(true));
    await tester.pumpAndSettle();
    expect(
      find.text(l10n.consolidationRequiredTitleNamed('Savings')),
      findsOneWidget,
    );
    expect(
      find.text(l10n.consolidationRequiredTitleNamed('Spending')),
      findsNothing,
    );
    verify(() => consolidation.isRequired('one')).called(1);
    verify(() => consolidation.isRequired('two')).called(1);
  });

  testWidgets('empty home does not check consolidation', (tester) async {
    await tester.pumpWidget(
      app(
        HomeConsolidationBanner(
          consolidation: consolidation,
          wallets: const [],
          isRefreshing: false,
        ),
      ),
    );
    verifyNever(() => consolidation.isRequired(any()));
  });

  testWidgets('home forwards refresh completion to every wallet', (
    tester,
  ) async {
    when(() => consolidation.isRequired(any()))
        .thenAnswer((_) async => const Ok(true));

    Widget home(bool refreshing) => app(
      HomeConsolidationBanner(
        consolidation: consolidation,
        wallets: const [
          (walletId: 'one', walletName: 'Savings'),
          (walletId: 'two', walletName: 'Liquid Wallet'),
        ],
        isRefreshing: refreshing,
      ),
    );

    await tester.pumpWidget(home(false));
    await tester.pumpAndSettle();
    verify(() => consolidation.isRequired('one')).called(1);
    verify(() => consolidation.isRequired('two')).called(1);

    await tester.pumpWidget(home(true));
    await tester.pumpAndSettle();
    verifyNever(() => consolidation.isRequired(any()));

    await tester.pumpWidget(home(false));
    await tester.pumpAndSettle();
    verify(() => consolidation.isRequired('one')).called(1);
    verify(() => consolidation.isRequired('two')).called(1);
    verifyNoMoreInteractions(consolidation);
  });

  testWidgets('home preserves supplied labels and wallet order', (
    tester,
  ) async {
    when(() => consolidation.isRequired(any()))
        .thenAnswer((_) async => const Ok(true));

    await tester.pumpWidget(
      app(
        HomeConsolidationBanner(
          consolidation: consolidation,
          wallets: const [
            (walletId: 'one', walletName: 'Savings'),
            (walletId: 'two', walletName: 'Liquid Wallet'),
          ],
          isRefreshing: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final first = find.text(l10n.consolidationRequiredTitleNamed('Savings'));
    final fallback = find.text(
      l10n.consolidationRequiredTitleNamed('Liquid Wallet'),
    );
    expect(first, findsOneWidget);
    expect(fallback, findsOneWidget);
    expect(
      tester.getTopLeft(first).dy,
      lessThan(tester.getTopLeft(fallback).dy),
    );
  });

  testWidgets('detail reloads after refresh and hides on typed failure', (
    tester,
  ) async {
    var calls = 0;
    when(() => consolidation.isRequired('one')).thenAnswer((_) async {
      calls++;
      return calls == 1
          ? const Ok(true)
          : const Err(ConsolidationStatusUnavailable());
    });

    Widget detail(bool refreshing) => app(
      ConsolidationBanner(
        consolidation: consolidation,
        walletId: 'one',
        isRefreshing: refreshing,
      ),
    );
    await tester.pumpWidget(detail(false));
    await tester.pumpAndSettle();
    expect(find.text(l10n.consolidationRequiredTitle), findsOneWidget);
    await tester.pumpWidget(detail(true));
    await tester.pumpAndSettle();
    expect(calls, 1);
    await tester.pumpWidget(detail(false));
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.text(l10n.consolidationRequiredTitle), findsNothing);
  });

  testWidgets('tapping a named banner opens the selected wallet route', (
    tester,
  ) async {
    when(() => consolidation.isRequired('liquid-1'))
        .thenAnswer((_) async => const Ok(true));
    String? selectedWallet;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: HomeConsolidationBanner(
              consolidation: consolidation,
              wallets: const [(walletId: 'liquid-1', walletName: 'Savings')],
              isRefreshing: false,
            ),
          ),
        ),
        GoRoute(
          name: ConsolidationRoute.consolidation.name,
          path: ConsolidationRoute.consolidation.path,
          builder: (_, state) {
            selectedWallet = state.pathParameters['walletId'];
            return const Scaffold(body: Text('Review'));
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: sendTestLocalizationsDelegates,
        supportedLocales: SendLocalizations.supportedLocales,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.text(l10n.consolidationRequiredTitleNamed('Savings')),
    );
    await tester.pumpAndSettle();
    expect(selectedWallet, 'liquid-1');
    expect(find.text('Review'), findsOneWidget);
  });
}
