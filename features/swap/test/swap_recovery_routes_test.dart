import 'package:bull_ui/testing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:swap_feature/src/presentation/swap_rescue_cubit.dart';
import 'package:swap_feature/src/presentation/swap_restore_cubit.dart';
import 'package:swap_feature/src/swap_feature.dart';
import 'package:swaps/swaps.dart';

class _RestoreCubit extends Mock implements SwapRestoreCubit {}

class _RescueCubit extends Mock implements SwapRescueCubit {}

void main() {
  testWidgets('recovery routes redirect invalid extras before rescue', (
    tester,
  ) async {
    final restore = _RestoreCubit();
    when(() => restore.state)
        .thenReturn(const SwapRestoreState(status: SwapRestoreStatus.success));
    when(() => restore.stream).thenAnswer((_) => const Stream.empty());
    when(() => restore.close()).thenAnswer((_) async {});
    final rescue = _RescueCubit();
    when(() => rescue.state)
        .thenReturn(const SwapRescueState(status: SwapRescueStatus.ready));
    when(() => rescue.stream).thenAnswer((_) => const Stream.empty());
    when(() => rescue.close()).thenAnswer((_) async {});
    var rescueCreated = 0;
    final router = GoRouter(
      initialLocation: '/settings/swap-rescue',
      routes: [
        GoRoute(
          path: '/settings',
          builder: (_, _) => const SizedBox(),
          routes: [
            ...swapRecoveryRoutes(
              createRestore: () => restore,
              createRescue: (_) {
                rescueCreated++;
                return rescue;
              },
            ),
            GoRoute(path: 'wallet', builder: (_, _) => const Text('wallet')),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(extensions: testBullExtensions),
        routerConfig: router,
      ),
    );
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/settings/swap-restore',
    );
    expect(rescueCreated, 0);
    router.goNamed('swapRescue', extra: 'invalid');
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/settings/swap-restore',
    );
    expect(rescueCreated, 0);
    final restorable = RestorableSwap(
      swap: RestoredSwap(
        id: 'test',
        kind: RestoredSwapKind.crossChain,
        status: SwapStatus.pending,
        recoverable: true,
        amountSat: 100,
        createdAt: DateTime.utc(2026),
        fromAsset: 'BTC',
        toAsset: 'L-BTC',
      ),
      existsLocally: false,
    );
    router.goNamed('swapRescue', extra: restorable);
    await tester.pumpAndSettle();
    expect(
      router.routeInformationProvider.value.uri.path,
      '/settings/swap-rescue',
    );
    expect(rescueCreated, 1);
    router.go('/settings/wallet');
    await tester.pumpAndSettle();
    expect(find.text('wallet'), findsOneWidget);
  });
}
