import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/wizard/presentation/bloc/wizard_bloc.dart';
import 'package:bb_mobile/features/wizard/ui/screens/wizard_screen.dart';
import 'package:bb_mobile/features/wizard/ui/widgets/exchange_step.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Wizard extends MockBloc<WizardEvent, WizardState>
    implements WizardBloc {}

void main() {
  for (final allowed in [false, true]) {
    testWidgets('wizard exchange step follows platform permission $allowed', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Device.screen = const Size(400, 800);
      final bloc = _Wizard();
      whenListen(
        bloc,
        const Stream<WizardState>.empty(),
        initialState: const WizardState(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<WizardBloc>.value(
            value: bloc,
            child: WizardScreen(exchangeAllowed: allowed),
          ),
        ),
      );
      await tester.pump();
      final pages =
          tester.widget<PageView>(find.byType(PageView)).childrenDelegate
              as SliverChildListDelegate;
      expect(
        pages.children.whereType<ExchangeStep>(),
        hasLength(allowed ? 1 : 0),
      );
      expect(pages.children, hasLength(allowed ? 5 : 4));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
