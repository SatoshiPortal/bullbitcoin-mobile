import 'package:bull_exchange/testing.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../success_screen_back_harness.dart';

class _MockBuyBloc extends Mock implements BuyBloc {}

void main() {
  testWidgets('system back closes to the wallet home', (tester) async {
    final bloc = _MockBuyBloc();
    when(() => bloc.state).thenReturn(const BuyState());
    when(() => bloc.stream).thenAnswer((_) => const Stream.empty());

    await expectSystemBackClosesTo(
      tester,
      homeName: WalletRoute.walletHome.name,
      homePath: WalletRoute.walletHome.path,
      screen: BlocProvider<BuyBloc>.value(
        value: bloc,
        child: BuyAccelerateSuccessScreen(
          onClose: (context) => context.goNamed(WalletRoute.walletHome.name),
          openOrder: (_, _) {},
        ),
      ),
    );
  });
}
