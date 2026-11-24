import 'package:address_view/payment_destination.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter/services.dart' show TextInputType;

PaymentDestinationType _destinationType(WalletAddressType type) =>
    switch (type) {
      WalletAddressType.bitcoin => PaymentDestinationType.bitcoin,
      WalletAddressType.liquid => PaymentDestinationType.liquid,
      WalletAddressType.lightning => PaymentDestinationType.lightningAddress,
    };

/// Exchange forms use the same parser, scanner and viewer as Wallet and Send.
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
        keyboardType: type == WalletAddressType.lightning
            ? TextInputType.emailAddress
            : TextInputType.text,
        enabled: enabled,
        onChanged: onChanged,
        onValidationChanged: onValidationChanged,
      ),
);
