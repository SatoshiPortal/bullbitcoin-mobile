import 'package:flutter_test/flutter_test.dart';
import 'package:swap_feature/src/presentation/transfer_bloc.dart';
import 'package:swap_feature/src/ui/swap_router.dart';

void main() {
  test('a late cross-chain funding txid cannot take over navigation', () {
    const before = TransferState(sendToExternal: true);
    const after = TransferState(sendToExternal: true, txId: 'funding');
    expect(shouldNavigateOnTransferBroadcast(before, after), isFalse);
  });
}
