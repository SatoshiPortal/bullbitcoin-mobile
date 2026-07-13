import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_list_cubit.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_list_state.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:bb_mobile/features/invoices/ui/screens/invoices_list_screen.dart';
import 'package:bb_mobile/features/invoices/ui/widgets/invoice_list_item.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// A stub cubit seeded with a fixed state; the actions are no-ops so the screen
// renders the seeded status without a locator or network.
class _StubListCubit extends Cubit<InvoicesListState>
    implements InvoicesListCubit {
  _StubListCubit(super.initialState);

  @override
  Future<void> load() async {}

  @override
  Future<void> refresh() async {}

  @override
  void setFilter(InvoiceStatus? filter) {}
}

Invoice _invoice(String id, InvoiceStatus status) => Invoice(
  id: InvoiceId(id),
  status: status,
  amountSat: 1000,
  remainingAmountSat: 1000,
  acceptBtc: false,
  acceptLn: false,
  acceptLiquid: true,
  createdAt: DateTime.utc(2026),
  expiresAt: DateTime.utc(2030),
);

Future<void> _pump(WidgetTester tester, InvoicesListState state) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: BlocProvider<InvoicesListCubit>.value(
        value: _StubListCubit(state),
        child: const InvoicesListScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('loading shows the shimmer placeholder', (tester) async {
    await _pump(
      tester,
      const InvoicesListState(status: InvoicesListStatus.loading),
    );
    expect(find.byType(LoadingBoxContent), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an empty loaded state shows the empty copy', (tester) async {
    await _pump(
      tester,
      const InvoicesListState(status: InvoicesListStatus.loaded),
    );
    expect(find.byType(InvoiceListItem), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a loaded list renders one row per invoice', (tester) async {
    await _pump(
      tester,
      InvoicesListState(
        status: InvoicesListStatus.loaded,
        invoices: [
          _invoice('a', InvoiceStatus.unpaid),
          _invoice('b', InvoiceStatus.paid),
        ],
      ),
    );
    expect(find.byType(InvoiceListItem), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('the error state renders without throwing', (tester) async {
    await _pump(
      tester,
      const InvoicesListState(
        status: InvoicesListStatus.error,
        failure: InvoicesFailure.network(),
      ),
    );
    expect(tester.takeException(), isNull);
  });
}
