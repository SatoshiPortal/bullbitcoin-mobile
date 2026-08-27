import 'package:bb_mobile/features/tor_settings/presentation/bloc/embedded_tor_status_cubit.dart';
import 'package:bb_mobile/features/tor_settings/public/embedded_tor_status_scope.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockEmbeddedTorStatusCubit extends Mock
    implements EmbeddedTorStatusCubit {}

void main() {
  late _MockEmbeddedTorStatusCubit cubit;

  setUp(() {
    cubit = _MockEmbeddedTorStatusCubit();
    when(() => cubit.state).thenReturn(const EmbeddedTorStatusState());
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(cubit.init).thenAnswer((_) async {});
    when(cubit.refreshConfiguration).thenAnswer((_) async {});
    when(cubit.close).thenAnswer((_) async {});
    when(() => cubit.setVisibilityChecker(any())).thenReturn(null);
    locator.registerSingleton<EmbeddedTorStatusCubit>(cubit);
  });

  tearDown(() => locator.reset());

  testWidgets('owns init, route refresh, resume and close', (tester) async {
    Future<bool> shouldShow() async => true;
    final router = GoRouter(
      routes: [
        ShellRoute(
          builder: (_, _, child) =>
              EmbeddedTorStatusScope(shouldShow: shouldShow, child: child),
          routes: [
            GoRoute(path: '/', builder: (_, _) => const SizedBox()),
            GoRoute(path: '/next', builder: (_, _) => const SizedBox()),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    verify(cubit.init).called(1);
    verify(() => cubit.setVisibilityChecker(shouldShow)).called(1);

    router.go('/next');
    await tester.pump();
    verify(cubit.refreshConfiguration).called(1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    verify(cubit.refreshConfiguration).called(1);

    await tester.pumpWidget(const SizedBox());
    verify(cubit.close).called(1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    verifyNoMoreInteractions(cubit);
  });
}
