import 'package:bb_mobile/core/exchange/domain/entity/virtual_iban_recipient.dart';

/// Repository contract for Virtual IBAN (Confidential SEPA) operations.
abstract class VirtualIbanRepository {
  /// Gets the user's Virtual IBAN details.
  /// Returns null if no Virtual IBAN has been created yet.
  Future<VirtualIbanRecipient?> getVirtualIbanDetails();

  /// Creates a Virtual IBAN for the user.
  /// Returns the created Virtual IBAN recipient.
  Future<VirtualIbanRecipient> createVirtualIban();

  /// Creates an FR_PAYEE recipient from a Virtual IBAN.
  /// This is needed when making withdrawals to the user's own Virtual IBAN.
  Future<VirtualIbanRecipient> createFrPayeeRecipient({required String iban});
}


