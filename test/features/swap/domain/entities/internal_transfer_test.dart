import 'package:flutter_test/flutter_test.dart';
import 'package:bb_mobile/features/swap/domain/entities/internal_transfer.dart';
import 'package:swaps/order_swaps.dart';
import 'package:primitives/primitives.dart';

import '../../internal_transfer_fixture.dart';

void main() {
  InternalTransfer board(
    String amount, {
    String source = 'bitcoin',
    bool stale = false,
    int minimum = 50000,
    bool unknown = false,
  }) => InternalTransfer(
    from: transferWallet(id: source, unknown: unknown),
    to: arkTransferWallet,
    ark: transferContext(stale: stale, minimum: minimum),
    rawAmount: amount,
  );

  test('minimum comes from the server, including a changed minimum', () {
    expect(board('20000').failure, isA<SwapAmountOutOfBoundsFailure>());
    expect(board('49999').failure, isA<SwapAmountOutOfBoundsFailure>());
    expect(board('50000').failure, isNull);
    expect(
      board('50000', minimum: 60000).failure,
      isA<SwapAmountOutOfBoundsFailure>(),
    );
  });
  test('Board permits only the currently bound host source', () {
    expect(
      board('100000', source: 'another-bitcoin').failure,
      isA<SwapUnsupportedNetworkFailure>(),
    );
    expect(board('100000').failure, isNull);
  });
  test('unknown balances and stale native data stay unavailable', () {
    expect(
      board('100000', unknown: true).failure,
      isA<SwapInvalidStateFailure>(),
    );
    expect(
      board('100000', stale: true).failure,
      isA<SwapUnsupportedNetworkFailure>(),
    );
    expect(board('184251').failure, isA<SwapAmountOutOfBoundsFailure>());
  });
  test('amount input rejects invalid and out-of-supply values', () {
    for (final raw in ['', '0', '-1', '1.5', ' 100000', '2100000000000001']) {
      expect(board(raw).failure, isA<SwapValidationFailure>(), reason: raw);
    }
  });
  test('cooperative Ark to Bitcoin is supported; Liquid pairs are not', () {
    final ark = transferContext();
    InternalTransfer to(TransferWallet target) => InternalTransfer(
      from: arkTransferWallet,
      to: target,
      ark: ark,
      rawAmount: '1000',
    );
    expect(to(transferWallet()).failure, isNull);
    expect(
      to(transferWallet(kind: TransferWalletKind.liquid)).failure,
      isA<SwapUnsupportedNetworkFailure>(),
    );
    expect(
      to(transferWallet(network: BitcoinNetwork.mainnet)).failure,
      isA<SwapUnsupportedNetworkFailure>(),
    );
    expect(to(arkTransferWallet).failure, isA<SwapUnsupportedNetworkFailure>());
  });
}
