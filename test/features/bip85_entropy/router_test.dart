import 'package:bb_mobile/features/bip85_entropy/domain/can_access_bip85_entropy_usecase.dart';
import 'package:bb_mobile/features/bip85_entropy/router.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockCanAccessBip85EntropyUsecase extends Mock
    implements CanAccessBip85EntropyUsecase {}

class _MockBuildContext extends Mock implements BuildContext {}

class _MockGoRouterState extends Mock implements GoRouterState {}

void main() {
  late _MockCanAccessBip85EntropyUsecase canAccess;

  setUp(() async {
    await locator.reset();
    canAccess = _MockCanAccessBip85EntropyUsecase();
    locator.registerSingleton<CanAccessBip85EntropyUsecase>(canAccess);
  });

  tearDown(locator.reset);

  test('constructs the named entropy route at the expected path', () {
    final route = Bip85EntropyRouter.route.routes.single as GoRoute;

    expect(route.name, Bip85EntropyRoute.bip85Home.name);
    expect(route.path, '/bip85-home');
    expect(route.redirect, isNotNull);
  });

  test('redirect permits access only when the guard permits it', () async {
    final route = Bip85EntropyRouter.route.routes.single as GoRoute;
    final context = _MockBuildContext();
    final state = _MockGoRouterState();
    when(canAccess.execute).thenAnswer((_) async => true);

    expect(await route.redirect!(context, state), isNull);

    when(canAccess.execute).thenAnswer((_) async => false);
    expect(await route.redirect!(context, state), '/wallet');
    verify(canAccess.execute).called(2);
  });
}
