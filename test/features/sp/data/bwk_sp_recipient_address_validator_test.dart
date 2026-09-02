import 'package:bb_mobile/features/sp/data/bwk_sp_recipient_address_validator.dart';
import 'package:bb_mobile/features/sp/domain/ports/sp_recipient_address_validator_port.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bull_sdk/bwk.dart' as bwk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

void main() {
  test('maps a validated SP address to silentPayment', () async {
    final validator = BwkSpRecipientAddressValidator(
      validateRecipientAddress: ({required address, required network}) async {
        expect(address, 'sp1valid');
        expect(network, bwk.SpNetwork.bitcoin);
        return bwk.SpRecipientAddressKind.sp;
      },
    );

    final result = await validator.validateRecipientAddress(
      'sp1valid',
      BitcoinNetwork.mainnet,
    );

    expect((result as Ok).value, SpRecipientAddressType.silentPayment);
  });

  test('maps a validated standard address to standard', () async {
    final validator = BwkSpRecipientAddressValidator(
      validateRecipientAddress: ({required address, required network}) async =>
          bwk.SpRecipientAddressKind.standard,
    );

    final result = await validator.validateRecipientAddress(
      'bc1valid',
      BitcoinNetwork.mainnet,
    );

    expect((result as Ok).value, SpRecipientAddressType.standard);
  });

  test('maps wrong-network failures to SpAddressNetworkMismatch', () async {
    final validator = BwkSpRecipientAddressValidator(
      validateRecipientAddress: ({required address, required network}) async =>
          throw Exception('wrong network for address'),
    );

    final result = await validator.validateRecipientAddress(
      'bc1valid',
      BitcoinNetwork.testnet,
    );

    expect((result as Err).failure, isA<SpAddressNetworkMismatch>());
  });

  test('maps other validation failures to SpInvalidAddress', () async {
    final validator = BwkSpRecipientAddressValidator(
      validateRecipientAddress: ({required address, required network}) async =>
          throw Exception('invalid address'),
    );

    final result = await validator.validateRecipientAddress(
      'not-an-address',
      BitcoinNetwork.mainnet,
    );

    expect((result as Err).failure, isA<SpInvalidAddress>());
  });
}
