import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/settings/ui/screens/swap/swap_provider_settings_screen.dart';
import 'package:bb_mobile/features/swap/public/swap_provider_settings.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';

class _MockStore extends Mock implements SwapProviderStore {}

class _MockSwitch extends Mock implements SwitchSwapProvider {}

void main() {
  testWidgets(
    'a failure renders a translated message, never a raw logMessage',
    (tester) async {
      final store = _MockStore();
      final switcher = _MockSwitch();
      when(
        () => store.all(),
      ).thenAnswer((_) async => const <SwapProviderConfig>[]);
      when(() => store.active()).thenAnswer((_) async => null);
      when(() => switcher.call('boltz')).thenAnswer(
        (_) async => const Err(SwapUnexpectedFailure('DEV_SECRET_XYZ')),
      );

      final cubit = SwapProviderSettingsCubit(store, switcher);
      addTearDown(cubit.close);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: const SwapProviderSettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await cubit.select('boltz');
      await tester.pumpAndSettle();

      expect(find.textContaining('DEV_SECRET_XYZ'), findsNothing);
      expect(find.text('Oops! Something went wrong'), findsOneWidget);
    },
  );
}
