import 'package:meta/meta.dart';

/// The user's personal Fiat Republic account, which Confidential SEPA needs.
@immutable
sealed class VirtualIban {
  const VirtualIban();

  /// The account is usable only once Fiat Republic has issued all of its
  /// bank details; until then it is still being created.
  factory VirtualIban.fromBankDetails({
    String? iban,
    String? bicCode,
    String? bankAddress,
    String? ibanCountry,
  }) {
    final trimmedIban = iban?.trim() ?? '';
    final trimmedBicCode = bicCode?.trim() ?? '';
    final trimmedBankAddress = bankAddress?.trim() ?? '';
    if (trimmedIban.isEmpty ||
        trimmedBicCode.isEmpty ||
        trimmedBankAddress.isEmpty) {
      return const PendingVirtualIban();
    }
    return ActiveVirtualIban._(
      iban: trimmedIban,
      bicCode: trimmedBicCode,
      bankAddress: trimmedBankAddress,
      ibanCountry: ibanCountry?.trim(),
    );
  }
}

final class PendingVirtualIban extends VirtualIban {
  const PendingVirtualIban();
}

final class ActiveVirtualIban extends VirtualIban {
  final String iban;
  final String bicCode;
  final String bankAddress;
  final String? ibanCountry;

  const ActiveVirtualIban._({
    required this.iban,
    required this.bicCode,
    required this.bankAddress,
    this.ibanCountry,
  });
}
