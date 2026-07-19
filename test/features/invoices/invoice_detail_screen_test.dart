import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/presentation/invoice_detail_cubit.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:bb_mobile/features/invoices/ui/screens/invoice_detail_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFacade extends Mock implements InvoicesFacade {}

InvoiceStatusSnapshot _snapshot(InvoiceStatus status) => InvoiceStatusSnapshot(
  status: status,
  pricingMode: 'sat',
  settlementStatus: 'pending',
  amountSat: 1000,
  remainingAmountSat: 1000,
  paymentToleranceSat: 0,
  rateLocksUntil: DateTime.utc(2030),
  expiresAt: DateTime.utc(2030),
  lightningPr: 'lnbc1000',
  liquidAddress: 'lq1qaddress',
  bitcoinAddress: 'bc1qaddress',
  acceptBtc: true,
  acceptLn: true,
  acceptLiquid: true,
);

Future<void> _pump(
  WidgetTester tester, {
  required InvoiceDetailCubit cubit,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: BlocProvider<InvoiceDetailCubit>.value(
        value: cubit,
        child: const InvoiceDetailScreen(),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(InvoiceId('x'));
  });

  late _MockFacade facade;
  late InvoiceDetailCubit cubit;

  setUp(() {
    facade = _MockFacade();
    cubit = InvoiceDetailCubit(
      facade: facade,
      invoiceId: InvoiceId('inv-1'),
      pollInitialDelay: const Duration(seconds: 30),
    );
  });

  tearDown(() async {
    await cubit.close();
  });

  testWidgets(
    'unsupported status requires update/reconciliation and hides actions',
    (tester) async {
      when(
        () => facade.status(any()),
      ).thenAnswer((_) async => Ok(_snapshot(InvoiceStatus.unsupported)));

      await cubit.refresh();
      await _pump(tester, cubit: cubit);
      await tester.pump();

      expect(find.text('Update required'), findsOneWidget);
      expect(
        find.text(
          'Update the app, then refresh this invoice. Payment reconciliation '
          'may still be in progress.',
        ),
        findsOneWidget,
      );
      expect(find.text('Cancel invoice'), findsNothing);
      expect(find.text('Lightning invoice'), findsNothing);
      expect(find.text('Liquid address'), findsNothing);
      expect(find.text('Bitcoin address'), findsNothing);
    },
  );

  testWidgets('retained private link is the only invoice sharing surface', (
    tester,
  ) async {
    final invoiceId = InvoiceId('inv-1');
    final link = PrivateInvoiceLink.fromServer(
      invoiceUrl: 'https://pay2.bull-wallet.com/invoice/inv-1',
      expectedInvoiceId: invoiceId,
      viewingKey: 'A' * 43,
      expectedOrigin: Uri.parse('https://pay2.bull-wallet.com'),
    );
    when(
      () => facade.status(any()),
    ).thenAnswer((_) async => Ok(_snapshot(InvoiceStatus.paid)));
    when(() => facade.privateLink(any())).thenAnswer((_) async => link);

    await cubit.load();
    await _pump(tester, cubit: cubit);
    await tester.pump();

    expect(find.text('Private payment link'), findsOneWidget);
    expect(find.text('Copy private link'), findsOneWidget);
    expect(find.text('Share private link'), findsOneWidget);
    expect(find.text('Open link'), findsOneWidget);
    expect(find.text('Lightning invoice'), findsNothing);
    expect(find.text('Liquid address'), findsNothing);
    expect(find.text('Bitcoin address'), findsNothing);
  });

  testWidgets('missing retained link has no fragmentless fallback', (
    tester,
  ) async {
    when(
      () => facade.status(any()),
    ).thenAnswer((_) async => Ok(_snapshot(InvoiceStatus.paid)));
    when(() => facade.privateLink(any())).thenAnswer((_) async => null);

    await cubit.load();
    await _pump(tester, cubit: cubit);
    await tester.pump();

    expect(
      find.text('Private link unavailable on this device'),
      findsOneWidget,
    );
    expect(find.text('Copy private link'), findsNothing);
    expect(find.text('Share private link'), findsNothing);
    expect(find.text('Open link'), findsNothing);
  });
}
