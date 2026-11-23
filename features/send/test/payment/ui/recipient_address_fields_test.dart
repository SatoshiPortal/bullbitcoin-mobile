import 'package:bull_ui/app_theme.dart';
import 'package:bull_ui/bull_ui.dart' show bullUiLocalizationsDelegate;
import 'package:send/src/payment/presentation/bloc/send_state.dart';
import 'package:send/src/payment/ui/widgets/recipient_fields.dart';
import 'package:address_view/address_view.dart';
import 'package:address_view/routes.dart' show AddressViewLocalizations;
import 'package:send/setup.dart' show SendLocalizations;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  const first = (
    id: 1,
    address: 'bc1qexample',
    amount: '',
    receivesRemainder: false,
    isValid: true,
  );
  const invalid = (
    id: 2,
    address: '',
    amount: '',
    receivesRemainder: false,
    isValid: false,
  );

  Widget app(List<SendRecipientDraft> recipients, {bool multi = false}) =>
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: const [
          bullUiLocalizationsDelegate,
          AddressViewLocalizations.delegate,
          SendLocalizations.delegate,
          ...GlobalMaterialLocalizations.delegates,
        ],
        supportedLocales: SendLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: RecipientAddressFields(
              recipients: recipients,
              multipleRecipients: multi,
              primaryField: const Text('Primary editor'),
              onRemoveRecipient: (_) {},
              onAddressChanged: (_, _) async {},
            ),
          ),
        ),
      );

  testWidgets(
    'multiple mode collapses a valid primary and displays an empty second editor',
    (tester) async {
      await tester.pumpWidget(app([first, invalid], multi: true));
      expect(find.text('Primary editor'), findsNothing);
      expect(find.byType(AddressViewer), findsOneWidget);
      expect(find.text('Recipient 2 address'), findsOneWidget);
      expect(find.text('Paste'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.byTooltip('Remove Recipient'), findsOneWidget);
    },
  );

  testWidgets('valid extra recipient keeps a 48dp remove target', (
    tester,
  ) async {
    final second = (
      id: 2,
      address: 'bc1qsecond',
      amount: '',
      receivesRemainder: false,
      isValid: true,
    );
    await tester.pumpWidget(app([first, second], multi: true));
    final remove = find.byTooltip('Remove Recipient');
    expect(remove, findsOneWidget);
    final button = find.byWidgetPredicate(
      (widget) => widget is IconButton && widget.tooltip == 'Remove Recipient',
    );
    expect(tester.getSize(button), const Size(48, 48));
  });

  testWidgets('single mode keeps the primary editor', (tester) async {
    await tester.pumpWidget(app([first]));
    expect(find.text('Primary editor'), findsOneWidget);
    expect(find.byType(AddressViewer), findsNothing);
  });
}
