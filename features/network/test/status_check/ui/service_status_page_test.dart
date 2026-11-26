import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:network/src/status_check/domain/check_service_status_usecase.dart';
import 'package:network/src/status_check/domain/service_status.dart';
import 'package:network/src/status_check/ui/service_status_page.dart';
import 'package:network/src/status_check/status_session.dart';
import 'package:primitives/primitives.dart';

import '../../fixtures.dart';

class _StatusCheck extends Mock implements CheckServiceStatusUsecase {}

void main() {
  testWidgets('shows the Silent row only after confirmed admission', (
    tester,
  ) async {
    registerFallbackValue(const AllServicesStatus());
    registerFallbackValue((AllServicesStatus _) {});
    final check = _StatusCheck();
    var result = const AllServicesStatus();
    when(
      () => check.execute(
        initialStatus: any(named: 'initialStatus'),
        onUpdate: any(named: 'onUpdate'),
      ),
    ).thenAnswer((_) async => Ok(result));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: networkTestLocalizationsDelegates,
        theme: networkTestTheme(),
        home: ServiceStatusPage(status: buildNetworkStatus(() => check)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Silent Payments'), findsNothing);
    result = const AllServicesStatus(
      silent: ServiceStatusInfo(status: ServiceStatus.online),
    );
    await tester.tap(find.byTooltip('Refresh service status'));
    await tester.pumpAndSettle();
    expect(find.text('Silent Payments'), findsOneWidget);
    result = const AllServicesStatus();
    await tester.tap(find.byTooltip('Refresh service status'));
    await tester.pumpAndSettle();
    expect(find.text('Silent Payments'), findsNothing);
  });

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
    final status = buildNetworkStatus(() => check);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('fr'),
        supportedLocales: const [Locale('fr')],
        localizationsDelegates: networkTestLocalizationsDelegates,
        theme: networkTestTheme(),
        home: ServiceStatusPage(status: status),
      ),
    );
    await tester.pumpAndSettle();

    verify(
      () => check.execute(
        initialStatus: any(named: 'initialStatus'),
        onUpdate: any(named: 'onUpdate'),
      ),
    ).called(1);

    final action = find.byTooltip('Actualiser l’état des services');
    expect(action, findsOneWidget);
    await tester.tap(action);
    await tester.pumpAndSettle();
    verify(
      () => check.execute(
        initialStatus: any(named: 'initialStatus'),
        onUpdate: any(named: 'onUpdate'),
      ),
    ).called(1);
  });
}
