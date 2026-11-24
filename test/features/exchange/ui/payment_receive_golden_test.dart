import '../support/payin_ui_fixture.dart';

import 'package:bull_exchange/testing.dart';
import 'package:exchange/exchange.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:bb_mobile/localizations.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart' show BitcoinUnit;

class _PayBloc extends Mock implements PayBloc {}

class _SellBloc extends Mock implements SellBloc {}

class _PayOrder extends Mock implements FiatPaymentOrder {}

class _SellOrder extends Mock implements SellOrder {}

const _summary = UserSummary(
  userNumber: 1,
  groups: [],
  profile: UserProfile(firstName: 'Test', lastName: 'User'),
  email: 'test@example.com',
  balances: [],
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

final _recipient = RecipientViewModel(
  Recipient.create(
    recipientId: 'test-recipient',
    userId: 'user',
    userNbr: 1,
    isArchived: false,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
    details: InteracEmailCadDetails.create(
      email: 'test@example.com',
      name: 'test@example.com',
    ),
  ),
);

void _stubOrder(Order order) {
  when(() => order.orderNumber).thenReturn(123);
  when(() => order.payinMethod).thenReturn(OrderPaymentMethod.bitcoin);
  when(() => order.payoutMethod).thenReturn(OrderPaymentMethod.cadBalance);
  when(() => order.payinAmount).thenReturn(0.001);
  when(() => order.payoutAmount).thenReturn(50);
  when(() => order.payoutCurrency).thenReturn('CAD');
}

const _address = 'bc1q0000000000000000000000000000000000000';

Widget _payScreen() {
  final order = _PayOrder();
  _stubOrder(order);
  when(() => order.bitcoinAddress).thenReturn(_address);
  final bloc = _PayBloc();
  when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => bloc.state).thenReturn(
    PayPaymentState(
      selectedRecipient: _recipient,
      userSummary: _summary,
      amount: const FiatAmount(50),
      payOrder: order,
    ),
  );
  return RepositoryProvider.value(
    value: payinTestUi(),
    child: BlocProvider<PayBloc>.value(
      value: bloc,
      child: const PayReceivePaymentScreen(),
    ),
  );
}

Widget _sellScreen() {
  final order = _SellOrder();
  _stubOrder(order);
  when(() => order.bitcoinAddress).thenReturn(_address);
  final bloc = _SellBloc();
  when(() => bloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => bloc.state).thenReturn(
    SellPaymentState(
      userSummary: _summary,
      bitcoinUnit: BitcoinUnit.sats,
      orderAmount: const FiatAmount(50),
      fiatCurrency: FiatCurrency.cad,
      sellOrder: order,
    ),
  );
  return RepositoryProvider.value(
    value: payinTestUi(),
    child: BlocProvider<SellBloc>.value(
      value: bloc,
      child: const SellReceivePaymentScreen(),
    ),
  );
}

void main() {
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    await (FontLoader(
      'Golos Text',
    )..addFont(rootBundle.load('assets/fonts/GolosText.ttf'))).load();
  });

  for (final type in AppThemeType.values) {
    for (final (name, buildScreen) in [
      ('pay', _payScreen),
      ('sell', _sellScreen),
    ]) {
      testWidgets(
        '$name receive payment uses the shared field in ${type.name}',
        (tester) async {
          tester.view.physicalSize = const Size(390, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.themeData(type),
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: RepaintBoundary(
                key: const ValueKey('payment-receive'),
                child: buildScreen(),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final field = find.byType(BullCopyField);
          final context = tester.element(field);
          final container = tester.widget<Container>(
            find.descendant(of: field, matching: find.byType(Container)).first,
          );
          final decoration = container.decoration as BoxDecoration;
          expect(decoration.color, context.appColors.surface);
          expect(decoration.border, Border.all(color: context.bull.border));

          await expectLater(
            find.byKey(const ValueKey('payment-receive')),
            matchesGoldenFile('goldens/$name-receive-payment-${type.name}.png'),
          );
        },
      );
    }
  }
}
