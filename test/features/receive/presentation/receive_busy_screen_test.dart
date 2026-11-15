import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/features/receive/domain/receive_failure.dart';
import 'package:bb_mobile/features/receive/presentation/bloc/receive_bloc.dart';
import 'package:bb_mobile/features/receive/ui/screens/receive_qr_screen.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _ReceiveBloc extends MockBloc<ReceiveEvent, ReceiveState>
    implements ReceiveBloc {}

void main() {
  for (final type in [ReceiveType.bitcoin, ReceiveType.liquid]) {
    testWidgets('$type unavailable address offers retry instead of empty QR', (
      tester,
    ) async {
      final bloc = _ReceiveBloc();
      when(() => bloc.state).thenReturn(
        ReceiveState(
          type: type,
          failure: const ReceiveAddressUnavailableFailure(),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<ReceiveBloc>.value(
            value: bloc,
            child: Builder(
              builder: (context) {
                Device.init(context);
                return const Scaffold(body: ReceiveQRDetails());
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(QrDisplayWidget), findsNothing);
      await tester.tap(find.text('Retry'));
      verify(
        () => bloc.add(
          type == ReceiveType.bitcoin
              ? const ReceiveBitcoinStarted(null)
              : const ReceiveLiquidStarted(),
        ),
      ).called(1);
    });
  }
}
