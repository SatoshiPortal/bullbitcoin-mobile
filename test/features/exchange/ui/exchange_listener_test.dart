import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_state.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_listener.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Cubit extends MockCubit<ExchangeState> implements ExchangeCubit {}

const _summary = UserSummary(
  userNumber: 1,
  groups: [],
  profile: UserProfile(firstName: 'Test', lastName: 'User'),
  email: 'test@example.invalid',
  balances: [],
  dca: UserDca(isActive: false),
  autoBuy: UserAutoBuy(isActive: false, addresses: UserAutoBuyAddresses()),
);

void main() {
  testWidgets(
    'socket is suspended while hidden and reconnects only on resume',
    (tester) async {
      final cubit = _Cubit();
      when(
        () => cubit.state,
      ).thenReturn(const ExchangeState(userSummary: _summary));
      when(() => cubit.reconnectWebSocket()).thenAnswer((_) async {});
      when(() => cubit.fetchUserSummary()).thenAnswer((_) async {});
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(
        BlocProvider<ExchangeCubit>.value(
          value: cubit,
          child: const ExchangeListener(child: SizedBox()),
        ),
      );
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      verify(() => cubit.disconnectWebSocket()).called(1);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      verifyNever(() => cubit.reconnectWebSocket());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      verify(() => cubit.reconnectWebSocket()).called(1);
      verify(() => cubit.fetchUserSummary()).called(1);
      await tester.pumpWidget(const SizedBox());
      await cubit.close();
    },
  );
}
