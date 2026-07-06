import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';

abstract interface class BullnymClientPort {
  Future<BullnymRegisterResult> register(BullnymRegisterRequest request);

  Future<void> deleteRegistration(BullnymDeleteRegistrationRequest request);

  Future<BullnymLookupResult> lookupRegistration({required String npubHex});

  Future<BullnymBackupHead> fetchBackup(BullnymBackupFetchRequest request);

  Future<BullnymBackupStoreReceipt> storeBackup(
    BullnymBackupStoreRequest request,
  );

  Future<BullnymBackupDeleteReceipt> deleteBackup(
    BullnymBackupDeleteRequest request,
  );

  /// Public read of the current donation-page row for `nym`/`kind`. Throws a
  /// `serverRejectedRequest` with code `DonationPageNotFound` when absent.
  Future<BullnymDonationPage> getDonationPage({
    required String nym,
    required String kind,
  });

  Future<BullnymDonationPage> saveDonationPage(
    BullnymSaveDonationPageRequest request,
  );

  Future<BullnymDonationPage> archiveDonationPage(
    BullnymArchiveDonationPageRequest request,
  );

  Future<BullnymSupportedCurrencies> getSupportedCurrencies();

  /// Create a Schnorr-signed recipient invoice. `nym == null` (v1 default)
  /// targets the UNLINKED endpoint `POST /api/v1/invoices` and signs
  /// `nym_or_empty=""`; a non-null nym targets the linked
  /// `POST /api/v1/:nym/invoices`. The client signs the `invoice-create`
  /// action with [signer] at the point of the call.
  Future<BullnymCreateInvoiceResponse> createInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required BullnymCreateInvoiceFields fields,
  });

  /// Cancel an invoice by id (signed `invoice-cancel`). `nym == null` hits the
  /// unlinked `DELETE /api/v1/invoices/:id`. Ownership is enforced server-side
  /// against the signing npub (a non-owner surfaces as `InvoiceNotFound`).
  Future<BullnymCancelInvoiceResponse> cancelInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required String invoiceId,
  });

  /// List the signing npub's invoices (signed `invoice-list`,
  /// `GET /api/v1/invoices`). The list is npub-wide (both linked and unlinked
  /// rows); `nym_or_empty` is ALWAYS empty in the signed bytes.
  Future<BullnymListInvoicesResponse> listInvoices({
    required BullnymAuthSigner signer,
    required int page,
    required int pageSize,
    String? status,
  });

  /// Public, UNSIGNED status/detail poll by id
  /// (`GET /api/v1/invoices/:id/status`). Anyone holding the id can poll it.
  Future<BullnymInvoiceStatus> getInvoiceStatus({required String invoiceId});
}

class BullnymBackupFetchRequest {
  final BullnymBackupStream stream;
  final String npubHex;
  final String signatureHex;
  final int timestamp;

  const BullnymBackupFetchRequest({
    required this.stream,
    required this.npubHex,
    required this.signatureHex,
    required this.timestamp,
  });
}

class BullnymBackupStoreRequest {
  final BullnymBackupStream stream;
  final String npubHex;
  final int generation;
  final String? expectedEtag;
  final AuthenticatedBackupCiphertext ciphertext;
  final String ciphertextSha256;
  final String signatureHex;
  final int timestamp;

  const BullnymBackupStoreRequest({
    required this.stream,
    required this.npubHex,
    required this.generation,
    required this.expectedEtag,
    required this.ciphertext,
    required this.ciphertextSha256,
    required this.signatureHex,
    required this.timestamp,
  });
}

class BullnymBackupDeleteRequest {
  final BullnymBackupStream stream;
  final String npubHex;
  final int generation;
  final String? expectedEtag;
  final String signatureHex;
  final int timestamp;

  const BullnymBackupDeleteRequest({
    required this.stream,
    required this.npubHex,
    required this.generation,
    required this.expectedEtag,
    required this.signatureHex,
    required this.timestamp,
  });
}

class BullnymRegisterRequest {
  final String nym;
  final String ctDescriptor;
  final String npubHex;
  final String signatureHex;
  final int timestamp;

  const BullnymRegisterRequest({
    required this.nym,
    required this.ctDescriptor,
    required this.npubHex,
    required this.signatureHex,
    required this.timestamp,
  });
}

class BullnymDeleteRegistrationRequest {
  final String nym;
  final String npubHex;
  final String signatureHex;
  final int timestamp;

  const BullnymDeleteRegistrationRequest({
    required this.nym,
    required this.npubHex,
    required this.signatureHex,
    required this.timestamp,
  });
}
