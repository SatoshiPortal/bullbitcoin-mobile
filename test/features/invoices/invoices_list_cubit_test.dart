import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_list_cubit.dart';
import 'package:bb_mobile/features/invoices/presentation/invoices_list_state.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockFacade extends Mock implements InvoicesFacade {}

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

void main() {
  setUpAll(() => registerFallbackValue(const ListInvoicesCommand()));

  late _MockFacade facade;

  setUp(() => facade = _MockFacade());

  test('load fetches with NO server status filter and marks loaded', () async {
    when(() => facade.list(any())).thenAnswer(
      (_) async => Ok(
        ListInvoicesResult(
          invoices: [_invoice('a', InvoiceStatus.unpaid)],
          page: 1,
          pageSize: 100,
          hasMore: false,
        ),
      ),
    );

    final cubit = InvoicesListCubit(facade: facade);
    await cubit.load();

    expect(cubit.state.status, InvoicesListStatus.loaded);
    expect(cubit.state.invoices, hasLength(1));
    final sent =
        verify(() => facade.list(captureAny())).captured.single
            as ListInvoicesCommand;
    expect(sent.status, isNull); // no server-side filter
    await cubit.close();
  });

  test(
    'the status filter is applied CLIENT-SIDE over the loaded set',
    () async {
      when(() => facade.list(any())).thenAnswer(
        (_) async => Ok(
          ListInvoicesResult(
            invoices: [
              _invoice('a', InvoiceStatus.unpaid),
              _invoice('b', InvoiceStatus.paid),
              _invoice('c', InvoiceStatus.unpaid),
            ],
            page: 1,
            pageSize: 100,
            hasMore: false,
          ),
        ),
      );

      final cubit = InvoicesListCubit(facade: facade);
      await cubit.load();

      cubit.setFilter(InvoiceStatus.paid);
      expect(cubit.state.visibleInvoices.map((i) => i.id.value), ['b']);
      // No extra wire call for a client-side filter.
      verify(() => facade.list(any())).called(1);

      cubit.setFilter(null);
      expect(cubit.state.visibleInvoices, hasLength(3));
      await cubit.close();
    },
  );

  test('an empty result yields the honest empty state (no error)', () async {
    when(() => facade.list(any())).thenAnswer(
      (_) async => const Ok(
        ListInvoicesResult(
          invoices: [],
          page: 1,
          pageSize: 100,
          hasMore: false,
        ),
      ),
    );

    final cubit = InvoicesListCubit(facade: facade);
    await cubit.load();

    expect(cubit.state.status, InvoicesListStatus.loaded);
    expect(cubit.state.isEmpty, isTrue);
    await cubit.close();
  });

  test(
    'a facade error flips to the error state with the typed failure',
    () async {
      when(
        () => facade.list(any()),
      ).thenAnswer((_) async => const Err(InvoicesFailure.network()));

      final cubit = InvoicesListCubit(facade: facade);
      await cubit.load();

      expect(cubit.state.status, InvoicesListStatus.error);
      expect(cubit.state.failure?.kind, InvoicesFailureKind.network);
      await cubit.close();
    },
  );
}
