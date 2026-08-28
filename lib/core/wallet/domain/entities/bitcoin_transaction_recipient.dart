import 'package:primitives/primitives.dart' show Sats;

final class BitcoinTransactionRecipient {
  final String address;
  final Sats? amountSat;

  BitcoinTransactionRecipient.fixed({
    required this.address,
    required Sats amountSat,
  }) : amountSat = amountSat {
    if (address.isEmpty) {
      throw ArgumentError.value(address, 'address', 'Address cannot be empty');
    }
    if (amountSat == Sats.zero) {
      throw ArgumentError.value(
        amountSat,
        'amountSat',
        'Amount must be greater than zero',
      );
    }
  }

  BitcoinTransactionRecipient.remainder({required this.address})
    : amountSat = null {
    if (address.isEmpty) {
      throw ArgumentError.value(address, 'address', 'Address cannot be empty');
    }
  }

  bool get receivesRemainder => amountSat == null;
}

void validateBitcoinTransactionRecipients(
  List<BitcoinTransactionRecipient> recipients,
) {
  if (recipients.isEmpty) {
    throw ArgumentError('At least one recipient is required');
  }
  if (recipients.where((recipient) => recipient.receivesRemainder).length > 1) {
    throw ArgumentError('Only one recipient can receive the remainder');
  }
}
