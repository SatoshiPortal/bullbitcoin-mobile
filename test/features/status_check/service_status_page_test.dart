import 'package:bb_mobile/core/status/domain/entity/service_status.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/status_check/domain/check_service_status_usecase.dart';
import 'package:bb_mobile/features/status_check/service_status_page.dart';
import 'package:bb_mobile/features/status_check/presentation/cubit.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockCheckServiceStatusUsecase extends Mock
    implements CheckServiceStatusUsecase {}

void main() {
  setUpAll(() {
    registerFallbackValue(const AllServicesStatus());
  });

  testWidgets('renders RecoverBull degraded status and explanation', (
    tester,
  ) async {
    final check = _MockCheckServiceStatusUsecase();
    final status = const AllServicesStatus(
      recoverbull: ServiceStatusInfo(
        status: ServiceStatus.degraded,
        name: 'Recoverbull',
        reason: ServiceStatusReason.temporarilyUnavailable,
      ),
    );
    when(
      () => check.execute(
        initialStatus: any(named: 'initialStatus'),
        onUpdate: any(named: 'onUpdate'),
      ),
    ).thenAnswer((_) async => Ok(status));
    final cubit = ServiceStatusCubit(checkServiceStatusUsecase: check);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const ServiceStatusPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.statusCheckDegraded), findsOneWidget);
    expect(
      find.text(l10n.statusCheckTemporarilyUnavailableExplanation),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).color ==
                tester.element(find.text('Recoverbull')).appColors.warning,
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not explain an offline status', (tester) async {
    final check = _MockCheckServiceStatusUsecase();
    const status = AllServicesStatus(
      recoverbull: ServiceStatusInfo(
        status: ServiceStatus.offline,
        name: 'Recoverbull',
      ),
    );
    when(
      () => check.execute(
        initialStatus: any(named: 'initialStatus'),
        onUpdate: any(named: 'onUpdate'),
      ),
    ).thenAnswer((_) async => const Ok(status));
    final cubit = ServiceStatusCubit(checkServiceStatusUsecase: check);
    addTearDown(cubit.close);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider.value(
          value: cubit,
          child: const ServiceStatusPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      find.text(l10n.statusCheckTemporarilyUnavailableExplanation),
      findsNothing,
    );
  });
}
