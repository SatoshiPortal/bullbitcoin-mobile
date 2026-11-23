import 'package:bb_mobile/features/swap/domain/entities/internal_transfer.dart';
import 'package:swaps/order_swaps.dart';
import 'package:bb_mobile/features/swap/domain/usecases/load_internal_ark_transfer_usecase.dart';
import 'package:bb_mobile/features/swap/domain/usecases/review_internal_ark_transfer_usecase.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart';
import 'package:bull_ark/bull_ark.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

import '../../internal_transfer_fixture.dart';

void main() {
  test(
    'Board hands off the bound source and amount, without reading an address',
    () async {
      final context = transferContext();
      var addresses = 0;
      final usecase = ReviewInternalArkTransferUsecase(
        LoadInternalArkTransferUsecase(
          () => ArkTransferFacade(() async => Ok(context)),
        ),
        WalletFacade(
          const Stream.empty(),
          receiveAddress: (_) async {
            addresses++;
            return const Ok('destination');
          },
        ),
      );
      final result = await usecase.execute(
        InternalTransfer(
          from: transferWallet(),
          to: arkTransferWallet,
          ark: context,
          rawAmount: '100000',
        ),
      );
      expect(result, isA<Ok<InternalArkTransferHandoff, SwapFailure>>());
      if (result case Ok(:final value)) {
        expect(value.path, '/ark/board');
        final entry = value.entry as ArkTransferBoardEntry;
        expect(entry.sourceWalletId, 'bitcoin');
        expect(entry.amount, Sats.fromInt(100000));
      }
      expect(addresses, 0);
    },
  );
  test(
    'cooperative payment uses the selected Bitcoin receive address',
    () async {
      final context = transferContext();
      final ids = <String>[];
      final usecase = ReviewInternalArkTransferUsecase(
        LoadInternalArkTransferUsecase(
          () => ArkTransferFacade(() async => Ok(context)),
        ),
        WalletFacade(
          const Stream.empty(),
          receiveAddress: (id) async {
            ids.add(id);
            return const Ok('bcrt1publicfixture');
          },
        ),
      );
      final result = await usecase.execute(
        InternalTransfer(
          from: arkTransferWallet,
          to: transferWallet(id: 'target'),
          ark: context,
          rawAmount: '1000',
        ),
      );
      if (result case Ok(:final value)) {
        expect(value.path, '/ark/review');
        final entry = value.entry as ArkTransferPaymentEntry;
        expect(entry.destination, 'bcrt1publicfixture');
        expect(entry.amount, Sats.fromInt(1000));
      } else {
        fail('Expected cooperative handoff');
      }
      expect(ids, ['target']);
    },
  );
  test(
    'a changed source invalidates the form before any destination lookup',
    () async {
      var addresses = 0;
      final usecase = ReviewInternalArkTransferUsecase(
        LoadInternalArkTransferUsecase(
          () => ArkTransferFacade(
            () async => Ok(transferContext(source: 'changed')),
          ),
        ),
        WalletFacade(
          const Stream.empty(),
          receiveAddress: (_) async {
            addresses++;
            return const Ok('unused');
          },
        ),
      );
      final result = await usecase.execute(
        InternalTransfer(
          from: transferWallet(),
          to: arkTransferWallet,
          ark: transferContext(),
          rawAmount: '100000',
        ),
      );
      expect(result, isA<Err<InternalArkTransferHandoff, SwapFailure>>());
      expect(addresses, 0);
    },
  );
  test('a new server minimum is checked again before handoff', () async {
    final usecase = ReviewInternalArkTransferUsecase(
      LoadInternalArkTransferUsecase(
        () =>
            ArkTransferFacade(() async => Ok(transferContext(minimum: 120000))),
      ),
      const WalletFacade(Stream.empty()),
    );
    final result = await usecase.execute(
      InternalTransfer(
        from: transferWallet(),
        to: arkTransferWallet,
        ark: transferContext(),
        rawAmount: '100000',
      ),
    );
    expect(
      result,
      isA<Err<InternalArkTransferHandoff, SwapFailure>>().having(
        (result) => result.failure,
        'real updated minimum',
        isA<SwapAmountOutOfBoundsFailure>().having(
          (failure) => failure.limitAmountSat,
          'minimum',
          BigInt.from(120000),
        ),
      ),
    );
  });
}
