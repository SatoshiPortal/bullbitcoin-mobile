import 'package:bb_mobile/features/swap/presentation/transfer_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TransferState.isExternalAddressBlocking', () {
    test('is false for internal transfers regardless of address error', () {
      const state = TransferState(
        sendToExternal: false,
        externalAddressError: 'Please enter a valid Liquid address',
      );
      expect(state.isExternalAddressBlocking, isFalse);
    });

    test('blocks when sending external with an empty address', () {
      const state = TransferState(sendToExternal: true, externalAddress: '');
      expect(state.isExternalAddressBlocking, isTrue);
    });

    test('blocks when the address is on the wrong (non-counter) network', () {
      const state = TransferState(
        sendToExternal: true,
        externalAddress: 'bc1qwrongnetwork',
        externalAddressError: 'Please enter a valid Liquid address',
      );
      expect(state.isExternalAddressBlocking, isTrue);
    });

    test('does not block for a valid counter-network address', () {
      const state = TransferState(
        sendToExternal: true,
        externalAddress: 'lq1qvalidliquidaddress',
      );
      expect(state.isExternalAddressBlocking, isFalse);
    });
  });
}
