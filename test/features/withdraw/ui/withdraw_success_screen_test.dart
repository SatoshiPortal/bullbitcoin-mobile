import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/withdraw/presentation/withdraw_bloc.dart';
import 'package:bb_mobile/features/withdraw/ui/screens/withdraw_success_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../success_screen_back_harness.dart';

class _MockWithdrawBloc extends Mock implements WithdrawBloc {}

class _MockWithdrawOrder extends Mock implements WithdrawOrder {}

void main() {
  testWidgets('system back closes to the exchange home', (tester) async {
    final bloc = _MockWithdrawBloc();
    final order = _MockWithdrawOrder();
    when(() => order.orderId).thenReturn('order-1');
    when(() => bloc.state).thenReturn(WithdrawState.success(order: order));
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await expectSystemBackClosesTo(
      tester,
      homeName: ExchangeRoute.exchangeHome.name,
      homePath: ExchangeRoute.exchangeHome.path,
      screen: BlocProvider<WithdrawBloc>.value(
        value: bloc,
        child: const WithdrawSuccessScreen(),
      ),
    );
  });
}
