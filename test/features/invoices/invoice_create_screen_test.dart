import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_create_cubit.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:bb_mobile/features/invoices/ui/screens/invoice_create_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFacade extends Mock implements InvoicesFacade {}

void main() {
  late _MockFacade facade;
  late InvoiceCreateCubit cubit;

  setUp(() async {
    facade = _MockFacade();
    when(() => facade.resumeCreate()).thenAnswer(
      (_) async => const Ok<CreateInvoiceResult?, InvoicesFailure>(null),
    );
    when(
      () => facade.supportedCurrencies(),
    ).thenAnswer((_) async => const BullnymSupportedCurrencies(currencies: []));
    cubit = InvoiceCreateCubit(facade: facade);
    await cubit.initialize();
  });

  tearDown(() => cubit.close());

  testWidgets('optional private details are collapsed and preserve values', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.themeData(AppThemeType.light),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: BlocProvider<InvoiceCreateCubit>.value(
          value: cubit,
          child: const InvoiceCreateScreen(),
        ),
      ),
    );

    expect(find.text('Add invoice details (optional)'), findsOneWidget);
    expect(find.text('Payer'), findsNothing);
    expect(find.text('Invoice'), findsNothing);
    expect(find.text('Payee'), findsNothing);
    expect(find.text('Private note (only you)'), findsNothing);
    expect(find.textContaining('Expires in'), findsNothing);

    await tester.tap(find.text('Add invoice details (optional)'));
    await tester.pump();
    expect(find.text('Payer'), findsOneWidget);
    expect(find.text('Invoice'), findsOneWidget);
    expect(find.text('Payee'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Name').first,
      'Jane',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Corporate name').first,
      'Example Corp',
    );
    await tester.pump();
    expect(find.text('Invoice details · 2 fields added'), findsOneWidget);

    final detailsLabel = find.text('Invoice details · 2 fields added');
    await tester.ensureVisible(detailsLabel);
    await tester.pump();
    await tester.tap(
      find.ancestor(of: detailsLabel, matching: find.byType(ListTile)),
    );
    await tester.pump();
    expect(find.text('Payer'), findsNothing);

    await tester.tap(
      find.ancestor(of: detailsLabel, matching: find.byType(ListTile)),
    );
    await tester.pump();
    expect(find.text('Jane'), findsOneWidget);
    expect(find.text('Example Corp'), findsOneWidget);
  });
}
