import '../../testing/send_test_localizations.dart';

import 'package:send/setup.dart' show SendLocalizations;
import 'package:bull_ui/app_theme.dart';
import 'package:send/src/payment/presentation/bloc/send_cubit.dart';
import 'package:send/src/payment/presentation/bloc/send_state.dart';
import 'package:send/src/payment/ui/widgets/advanced_options_bottom_sheet.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _SendCubit extends Mock implements SendCubit {}

void main() {
  testWidgets('withholds wallet actions until a wallet is available', (
    tester,
  ) async {
    final cubit = _SendCubit();
    when(() => cubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => cubit.state).thenReturn(const SendState());
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: sendTestLocalizationsDelegates,
        supportedLocales: SendLocalizations.supportedLocales,
        home: Scaffold(
          body: BlocProvider<SendCubit>.value(
            value: cubit,
            child: const AdvancedOptionsBottomSheet(),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(Switch), findsNothing);
    expect(find.byType(ListTile), findsNothing);
  });
}
