import 'dart:async';

import 'package:bull_ui/bull_ui.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:overview/overview.dart';
import 'package:overview/routes.dart';

class _HistoryScope extends InheritedWidget {
  const _HistoryScope({required super.child});

  @override
  bool updateShouldNotify(_HistoryScope oldWidget) => false;
}

void main() {
  for (final liquid in [false, true]) {
    testWidgets(
      'owner layout preserves ${liquid ? 'Liquid' : 'Bitcoin'} slots and scoped refresh',
      (tester) async {
        final calls = <String>[];
        final price = Completer<void>();
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.themeData(AppThemeType.values.first),
            home: OverviewWalletDetail(
              walletId: 'abc',
              walletName: 'Savings',
              settings: const SizedBox(),
              isLoading: false,
              unavailableMessage: 'Unavailable',
              hasBalance: true,
              isLiquid: liquid,
              scopeWalletHistory: (id, child) {
                expect(id, 'abc');
                return _HistoryScope(child: child);
              },
              refreshPrice: (context) {
                expect(
                  context.dependOnInheritedWidgetOfExactType<_HistoryScope>(),
                  isNotNull,
                );
                calls.add('price');
                return price.future;
              },
              refreshWalletHistory: (context) async {
                expect(
                  context.dependOnInheritedWidgetOfExactType<_HistoryScope>(),
                  isNotNull,
                );
                calls.add('history');
              },
              balanceCard: (_) => const Text('balance'),
              consolidation: (_) => const Text('consolidation'),
              coinsEntry: (_) => const Text('coins'),
              liquidDisclosure: (_) => const Text('disclosure'),
              history: (_) => const SliverToBoxAdapter(child: Text('history')),
              bottomActions: const Text('actions'),
            ),
          ),
        );
        final pull = tester.widget<BullPullableBody>(
          find.byType(BullPullableBody),
        );
        final slivers = pull.slivers;
        expect(slivers.length, liquid ? 7 : 5);
        expect(
          (slivers[0] as SliverToBoxAdapter).child,
          isA<Text>().having((w) => w.data, 'balance', 'balance'),
        );
        expect(
          (slivers[liquid ? 3 : 2] as SliverToBoxAdapter).child,
          isA<Text>().having((w) => w.data, 'coins', 'coins'),
        );
        if (liquid) {
          expect(
            (slivers[1] as SliverToBoxAdapter).child,
            isA<Text>().having((w) => w.data, 'consolidation', 'consolidation'),
          );
          expect(
            (slivers[4] as SliverToBoxAdapter).child,
            isA<Text>().having((w) => w.data, 'disclosure', 'disclosure'),
          );
        }
        expect(
          (slivers.last as SliverToBoxAdapter).child,
          isA<Text>().having((w) => w.data, 'history', 'history'),
        );
        await pull.onRefresh();
        expect(calls, ['price', 'history']);
        expect(price.isCompleted, isFalse);
        price.complete();
      },
    );
  }

  testWidgets('no balance does not mount history or body', (tester) async {
    var scoped = false;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.values.first),
        home: OverviewWalletDetail(
          walletId: 'abc',
          walletName: 'Savings',
          settings: const SizedBox(),
          isLoading: false,
          unavailableMessage: 'Unavailable',
          hasBalance: false,
          isLiquid: false,
          scopeWalletHistory: (id, child) {
            scoped = true;
            return child;
          },
          refreshPrice: (_) async {},
          refreshWalletHistory: (_) async {},
          balanceCard: (_) => const SizedBox(),
          consolidation: (_) => const SizedBox(),
          coinsEntry: (_) => const SizedBox(),
          liquidDisclosure: (_) => const SizedBox(),
          history: (_) => const SliverToBoxAdapter(),
          bottomActions: const SizedBox(),
        ),
      ),
    );
    expect(scoped, isFalse);
    expect(find.text('Unavailable'), findsOneWidget);
    expect(find.byType(BullPullableBody), findsNothing);
  });

  testWidgets('owner route preserves name, path and direct wallet id', (
    tester,
  ) async {
    final route = walletDetailRoute(builder: (_, id) => Text('wallet:$id'));
    expect(WalletRoute.walletHome.name, 'walletHome');
    expect(WalletRoute.walletHome.path, '/wallet');
    expect(route.name, 'walletDetail');
    expect(route.path, '/wallet/:walletId');
    final router = GoRouter(initialLocation: '/wallet/abc', routes: [route]);
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    expect(find.text('wallet:abc'), findsOneWidget);
  });
}
