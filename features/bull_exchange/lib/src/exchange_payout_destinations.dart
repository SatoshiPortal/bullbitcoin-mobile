import 'package:address_view/payment_destination.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter/widgets.dart';

import 'default_wallets/default_wallets_payout_fields.dart';

/// Exchange forms use the same parser, scanner and viewer as Wallet and Send.
PaymentDestinationType _destinationType(WalletAddressType type) =>
    switch (type) {
      WalletAddressType.bitcoin => PaymentDestinationType.bitcoin,
      WalletAddressType.liquid => PaymentDestinationType.liquid,
      WalletAddressType.lightning => PaymentDestinationType.lightningAddress,
    };

TextInputType _keyboard(WalletAddressType type) =>
    type == WalletAddressType.lightning
    ? TextInputType.emailAddress
    : TextInputType.text;

/// Default payout and Auto Buy destinations.
final DefaultWalletsPayoutFields exchangePayoutFields = (
  validate: (type, raw) async => (await const PaymentDestinations().validate(
    raw,
    acceptedTypes: {_destinationType(type)},
  ))?.address,
  buildField:
      ({
        required type,
        required value,
        required hint,
        required enabled,
        required onChanged,
        required onValidationChanged,
      }) => PaymentDestinationField(
        value: value,
        hint: hint,
        acceptedTypes: {_destinationType(type)},
        keyboardType: _keyboard(type),
        enabled: enabled,
        onChanged: onChanged,
        onValidationChanged: onValidationChanged,
      ),
);

/// Buy, DCA and limit-order destinations; LNURL is accepted for on-chain
/// payouts.
Widget exchangePurchasePayoutField({
  required WalletAddressType type,
  required String value,
  required String label,
  required String hint,
  required bool enabled,
  required ValueChanged<String> onChanged,
  required ValueChanged<String?> onValidated,
}) => PaymentDestinationField(
  value: value,
  label: label,
  hint: hint,
  enabled: enabled,
  acceptedTypes: {_destinationType(type)},
  allowLnurl: type != WalletAddressType.lightning,
  keyboardType: _keyboard(type),
  onChanged: onChanged,
  onValidated: (destination) => onValidated(destination?.address),
);

/// Validates a Bitcoin destination for Buy.
Future<String?> validateExchangeBitcoinAddress(String raw) async =>
    (await const PaymentDestinations().validate(
      raw,
      acceptedTypes: const {PaymentDestinationType.bitcoin},
    ))?.address;
