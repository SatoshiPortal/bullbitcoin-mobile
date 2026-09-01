import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/backup_settings/ui/widgets/backup_server_editor_dialog.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('edits, validates, and saves without owning a controller', (
    tester,
  ) async {
    String? result;
    await _pump(
      tester,
      onOpen: (context) async {
        result = await showBackupServerEditorDialog(context);
      },
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('https://backup.bull-wallet.com'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'http://example.com');
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Save'))
          .onPressed,
      isNull,
    );

    await tester.enterText(
      find.byType(TextFormField),
      'https://backup.example.com',
    );
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.widgetWithText(TextButton, 'Save'));
    await tester.pumpAndSettle();
    expect(result, 'https://backup.example.com');
  });

  testWidgets('cancel and route pop return no value', (tester) async {
    String? result = 'unchanged';
    await _pump(
      tester,
      onOpen: (context) async {
        result = await showBackupServerEditorDialog(context);
      },
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(result, isNull);

    result = 'unchanged';
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('reset returns the default sentinel', (tester) async {
    String? result;
    await _pump(
      tester,
      onOpen: (context) async {
        result = await showBackupServerEditorDialog(
          context,
          current: 'https://backup.example.com',
        );
      },
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Reset'));
    await tester.pumpAndSettle();
    expect(result, '');
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Future<void> Function(BuildContext context) onOpen,
}) => tester.pumpWidget(
  MaterialApp(
    theme: AppTheme.themeData(AppThemeType.light),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    locale: const Locale('en'),
    home: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => onOpen(context),
          child: const Text('Open'),
        ),
      ),
    ),
  ),
);
