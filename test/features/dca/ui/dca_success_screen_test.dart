import 'package:exchange/exchange.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:bb_mobile/features/dca/ui/screens/dca_success_screen.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../success_screen_back_harness.dart';

class _MockDcaBloc extends Mock implements DcaBloc {}

void main() {
  testWidgets('system back closes to the exchange home', (tester) async {
    final bloc = _MockDcaBloc();
    when(() => bloc.state).thenReturn(
      const DcaState.success(
        amount: 10,
        currency: FiatCurrency.cad,
        frequency: DcaBuyFrequency.weekly,
      ),
    );
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await expectSystemBackClosesTo(
      tester,
      homeName: ExchangeRoute.exchangeHome.name,
      homePath: ExchangeRoute.exchangeHome.path,
      screen: BlocProvider<DcaBloc>.value(
        value: bloc,
        child: const DcaSuccessScreen(),
      ),
    );
  });
}
