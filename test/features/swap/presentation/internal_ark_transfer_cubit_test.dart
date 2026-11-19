import 'dart:async';

import 'package:bb_mobile/features/swap/domain/entities/internal_transfer.dart';
import 'package:bb_mobile/features/swap/domain/usecases/load_internal_ark_transfer_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/review_internal_ark_transfer_usecase.dart';
import 'package:bb_mobile/features/swap/presentation/internal_ark_transfer_cubit.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bull_ark/bull_ark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../internal_transfer_fixture.dart';

void main() {
  test(
    'repeated Continue cannot issue concurrent or duplicate handoffs',
    () async {
      final context = transferContext();
      final pending = Completer<Result<ArkTransferContext, ArkFailure>>();
      var loads = 0;
      final loader = LoadInternalArkTransferUsecase(
        () => ArkTransferFacade(() {
          loads++;
          return loads == 1 ? Future.value(Ok(context)) : pending.future;
        }),
      );
      final cubit = InternalArkTransferCubit(
        loader,
        ReviewInternalArkTransferUsecase(
          loader,
          const WalletFacade(Stream.empty()),
        ),
      );
      addTearDown(cubit.close);
      await cubit.load();
      final transfer = InternalTransfer(
        from: transferWallet(),
        to: arkTransferWallet,
        ark: context,
        rawAmount: '100000',
      );
      final reviewing = cubit.review(transfer);
      await cubit.review(transfer);
      expect(loads, 2);
      expect(cubit.state.busy, isTrue);
      pending.complete(Ok(context));
      await reviewing;
      expect(cubit.state.handoff?.path, '/ark/board');
      await cubit.review(transfer);
      expect(loads, 2);
    },
  );

  test('a closed page discards an in-flight publication', () async {
    final pending = Completer<Result<ArkTransferContext, ArkFailure>>();
    final loader = LoadInternalArkTransferUsecase(
      () => ArkTransferFacade(() => pending.future),
    );
    final cubit = InternalArkTransferCubit(
      loader,
      ReviewInternalArkTransferUsecase(
        loader,
        const WalletFacade(Stream.empty()),
      ),
    );
    final loading = cubit.load();
    await cubit.close();
    pending.complete(Ok(transferContext()));
    await loading;
    expect(cubit.state.context, isNull);
  });
}
