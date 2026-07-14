import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/payment_page/presentation/payment_page_cubit.dart';
import 'package:bb_mobile/features/payment_page/presentation/payment_page_state.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/payment_page/ui/screens/payment_page_editor_screen.dart';
import 'package:bb_mobile/features/pos/presentation/pos_cubit.dart';
import 'package:bb_mobile/features/pos/presentation/pos_state.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:bb_mobile/features/pos/ui/screens/pos_provisioning_screen.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Donation Page permanent-name UX', () {
    testWidgets('old server hides alias and availability controls', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        const PaymentPageState(status: PaymentPageStatus.unsupported),
      );

      expect(find.text('Donation Page unavailable'), findsOneWidget);
      expect(find.byKey(const Key('payment_page_alias_field')), findsNothing);
      expect(find.byKey(const Key('payment_page_online_switch')), findsNothing);
    });

    testWidgets('optional first alias claim requires permanence confirmation', (
      tester,
    ) async {
      await _pumpPage(
        tester,
        const PaymentPageState(
          status: PaymentPageStatus.create,
          nym: 'alice',
          aliasDraft: 'shop',
          header: 'Tip me',
          description: 'Support my work',
          displayCurrency: 'CAD',
        ),
      );

      expect(find.byKey(const Key('payment_page_alias_field')), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Create Donation Page'),
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Create Donation Page'));
      await tester.pumpAndSettle();

      expect(find.text('Claim this alias permanently?'), findsOneWidget);
      expect(
        find.textContaining('shared by your Donation Page and Point of Sale'),
        findsOneWidget,
      );
      expect(find.textContaining('cannot be renamed, cleared'), findsOneWidget);
    });

    testWidgets('claimed alias is read-only and Page switch is kind-scoped', (
      tester,
    ) async {
      final cubit = await _pumpPage(tester, _pageEditState());

      expect(find.byKey(const Key('payment_page_alias_field')), findsNothing);
      expect(find.text('shop'), findsOneWidget);
      expect(
        find.textContaining('Permanent alias shared with Point of Sale'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Controls only your Donation Page. Lightning Address and Point of '
          'Sale stay as they are.',
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const Key('payment_page_online_switch')),
      );
      await tester.tap(find.byKey(const Key('payment_page_online_switch')));
      await tester.pumpAndSettle();
      expect(find.text('Turn off Donation Page?'), findsOneWidget);
      expect(
        find.text(
          'Your Donation Page will show an offline notice. Your permanent '
          'names remain claimed, and Lightning Address and Point of Sale stay '
          'as they are.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Turn off'));
      await tester.pumpAndSettle();
      expect(cubit.setOnlineCalls, [false]);
    });
  });

  group('Point of Sale permanent-name UX', () {
    testWidgets('old server hides alias and availability controls', (
      tester,
    ) async {
      await _pumpPos(tester, const PosState(status: PosStatus.unsupported));

      expect(find.text('Point of Sale unavailable'), findsOneWidget);
      expect(find.byKey(const Key('pos_alias_field')), findsNothing);
      expect(find.byKey(const Key('pos_online_switch')), findsNothing);
    });

    testWidgets('optional first alias claim requires permanence confirmation', (
      tester,
    ) async {
      await _pumpPos(
        tester,
        const PosState(
          status: PosStatus.create,
          nym: 'alice',
          aliasDraft: 'shop',
          label: 'My Till',
          displayCurrency: 'CAD',
        ),
      );

      expect(find.byKey(const Key('pos_alias_field')), findsOneWidget);
      await tester.ensureVisible(find.text('Create Point of Sale'));
      await tester.tap(find.text('Create Point of Sale'));
      await tester.pumpAndSettle();

      expect(find.text('Claim this alias permanently?'), findsOneWidget);
      expect(
        find.textContaining('shared by your Donation Page and Point of Sale'),
        findsOneWidget,
      );
      expect(find.textContaining('cannot be renamed, cleared'), findsOneWidget);
    });

    testWidgets('claimed alias is read-only and POS switch is kind-scoped', (
      tester,
    ) async {
      final cubit = await _pumpPos(tester, _posEditState());

      expect(find.byKey(const Key('pos_alias_field')), findsNothing);
      expect(find.text('shop'), findsOneWidget);
      expect(
        find.textContaining('Permanent alias shared with Donation Page'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Controls only your Point of Sale. Lightning Address and Donation '
          'Page stay as they are.',
        ),
        findsOneWidget,
      );

      await tester.ensureVisible(find.byKey(const Key('pos_online_switch')));
      await tester.tap(find.byKey(const Key('pos_online_switch')));
      await tester.pumpAndSettle();
      expect(find.text('Turn off Point of Sale?'), findsOneWidget);
      expect(
        find.text(
          'Your Point of Sale will show an offline notice. Your permanent '
          'names remain claimed, and Lightning Address and Donation Page stay '
          'as they are.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Turn off'));
      await tester.pumpAndSettle();
      expect(cubit.setOnlineCalls, [false]);
    });
  });
}

PaymentPageState _pageEditState() => const PaymentPageState(
  status: PaymentPageStatus.edit,
  nym: 'alice',
  permanentAlias: 'shop',
  header: 'Tip me',
  description: 'Support my work',
  displayCurrency: 'CAD',
  page: PaymentPage(
    nym: 'alice',
    header: 'Tip me',
    description: 'Support my work',
    displayCurrency: 'CAD',
    enabled: true,
    isArchived: false,
    alias: 'shop',
    publicUrl: 'https://bullpay.ca/a/shop',
  ),
);

PosState _posEditState() => const PosState(
  status: PosStatus.edit,
  nym: 'alice',
  permanentAlias: 'shop',
  label: 'My Till',
  displayCurrency: 'CAD',
  terminal: PosTerminal(
    nym: 'alice',
    label: 'My Till',
    displayCurrency: 'CAD',
    enabled: true,
    isArchived: false,
    alias: 'shop',
    terminalUrl: 'https://bullpay.ca/a/shop/pos',
  ),
);

Future<_StubPaymentPageCubit> _pumpPage(
  WidgetTester tester,
  PaymentPageState state,
) async {
  final cubit = _StubPaymentPageCubit(state);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: BlocProvider<PaymentPageCubit>.value(
        value: cubit,
        child: const PaymentPageEditorScreen(),
      ),
    ),
  );
  await tester.pump();
  return cubit;
}

Future<_StubPosCubit> _pumpPos(WidgetTester tester, PosState state) async {
  final cubit = _StubPosCubit(state);
  addTearDown(cubit.close);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.themeData(AppThemeType.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: BlocProvider<PosCubit>.value(
        value: cubit,
        child: const PosProvisioningScreen(),
      ),
    ),
  );
  await tester.pump();
  return cubit;
}

class _StubPaymentPageCubit extends Cubit<PaymentPageState>
    implements PaymentPageCubit {
  _StubPaymentPageCubit(super.initialState);

  final List<bool> setOnlineCalls = [];

  @override
  Future<void> load() async {}

  @override
  Future<void> setOnline(bool online) async => setOnlineCalls.add(online);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubPosCubit extends Cubit<PosState> implements PosCubit {
  _StubPosCubit(super.initialState);

  final List<bool> setOnlineCalls = [];

  @override
  Future<void> load() async {}

  @override
  Future<void> setOnline(bool online) async => setOnlineCalls.add(online);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
