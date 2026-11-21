import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network/src/status_check/domain/check_service_status_usecase.dart';
import 'package:network/src/status_check/domain/service_status.dart';
import 'package:network/src/status_check/ui/service_status_page.dart';
import 'package:network/src/status_check/presentation/service_status_cubit.dart';
import 'package:primitives/primitives.dart';

import '../../fixtures.dart';

class _StatusCheck extends Mock implements CheckServiceStatusUsecase {}

void main() {
  testWidgets('a localized refresh action checks service status again', (
    tester,
  ) async {
    registerFallbackValue(const AllServicesStatus());
    final check = _StatusCheck();
    when(
      () => check.execute(
        initialStatus: any(named: 'initialStatus'),
        onUpdate: any(named: 'onUpdate'),
      ),
    ).thenAnswer((_) async => const Ok(AllServicesStatus()));
    final cubit = ServiceStatusCubit(checkServiceStatusUsecase: check);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: networkTestLocalizationsDelegates,
        theme: networkTestTheme(),
        home: BlocProvider.value(
          value: cubit,
          child: const ServiceStatusPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final action = find.byTooltip('Actualiser l’état des services');
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    verify(
      () => check.execute(
        initialStatus: any(named: 'initialStatus'),
        onUpdate: any(named: 'onUpdate'),
      ),
    ).called(2);
  });
}
