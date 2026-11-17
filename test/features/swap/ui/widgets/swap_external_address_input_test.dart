import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:bb_mobile/features/swap/ui/widgets/swap_external_address_input.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

class _Transfer extends MockBloc<TransferEvent, TransferState>
    implements TransferBloc {}

void main() {
  testWidgets('names its scan and paste buttons, each 48 dp', (tester) async {
    final bloc = _Transfer();
    whenListen(
      bloc,
      const Stream<TransferState>.empty(),
      initialState: const TransferState(),
    );
    await tester.pumpWidget(
      BlocProvider<TransferBloc>.value(
        value: bloc,
        child: MaterialApp(
          theme: AppTheme.themeData(AppThemeType.light),
          locale: const Locale('en'),
          localizationsDelegates: [
            ...AppLocalizations.localizationsDelegates,
            bullUiLocalizationsDelegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SwapExternalAddressInput()),
        ),
      ),
    );

    for (final tooltip in ['Scan QR Code', 'Paste']) {
      expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
      final button = find
          .ancestor(
            of: find.byTooltip(tooltip),
            matching: find.byType(IconButton),
          )
          .first;
      expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
    }
  });
}
