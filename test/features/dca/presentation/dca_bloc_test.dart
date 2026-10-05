import 'dart:async';

import 'package:bb_mobile/core/exchange/domain/entity/order.dart';
import 'package:bb_mobile/core/exchange/domain/entity/user_summary.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/dca/domain/dca_failure.dart';
import 'package:bb_mobile/features/dca/domain/usecases/set_dca_usecase.dart';
import 'package:bb_mobile/features/dca/domain/usecases/start_dca_usecase.dart';
import 'package:bb_mobile/features/dca/presentation/dca_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockStartDcaUsecase extends Mock implements StartDcaUsecase {}

class MockSetDcaUsecase extends Mock implements SetDcaUsecase {}

void main() {
  test('retry clears the failure and loads the DCA form', () async {
    final startDca = MockStartDcaUsecase();
    final secondLoad = Completer<Result<DcaStartData, DcaFailure>>();
    var calls = 0;
    when(() => startDca.execute()).thenAnswer((_) {
      calls += 1;
      return calls == 1
          ? Future.value(const Err(DcaAccountUnavailableFailure()))
          : secondLoad.future;
    });
    final bloc = DcaBloc(
      startDcaUsecase: startDca,
      setDcaUsecase: MockSetDcaUsecase(),
    );

    final firstFailure = bloc.stream.firstWhere(
      (state) => state is DcaInitialState && state.failure != null,
    );
    bloc.add(const DcaEvent.started());
    await firstFailure;

    final loading = bloc.stream.firstWhere(
      (state) => state is DcaInitialState && state.failure == null,
    );
    bloc.add(const DcaEvent.started());
    await loading;

    final loaded = bloc.stream.firstWhere((state) => state is DcaBuyInputState);
    secondLoad.complete(
      const Ok((
        balances: <UserBalance>[],
        currency: FiatCurrency.cad,
        lightningAddress: null,
      )),
    );
    await loaded;

    verify(() => startDca.execute()).called(2);
    await bloc.close();
  });
}
