import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fallback_supervision.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_get_paid_transaction.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice_quote.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_recovery_address.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
import 'package:meta/meta.dart';

abstract interface class BullnymClientPort {
  @useResult
  Future<Result<BullnymBackupHead, BullnymFailure>> fetchBackup(
    BullnymBackupFetchRequest request,
  );

  @useResult
  Future<Result<BullnymBackupStoreReceipt, BullnymFailure>> storeBackup(
    BullnymBackupStoreRequest request,
  );

  @useResult
  Future<Result<BullnymBackupDeleteReceipt, BullnymFailure>> deleteBackup(
    BullnymBackupDeleteRequest request,
  );

  /// Public capability read. Missing/unknown policy is a valid old-server
  /// response and leaves permanent-name behavior disabled.
  @useResult
  Future<Result<BullnymVersionInfo, BullnymFailure>> getVersion();

  @useResult
  Future<Result<BullnymRegisterResult, BullnymFailure>> register(
    BullnymRegisterRequest request,
  );

  @useResult
  Future<Result<void, BullnymFailure>> deleteRegistration(
    BullnymDeleteRegistrationRequest request,
  );

  @useResult
  Future<Result<BullnymLookupResult, BullnymFailure>> lookupRegistration({
    required String npubHex,
  });

  /// Public read of the current donation-page row for `nym`/`kind`. Returns a
  /// server-rejected failure with code `DonationPageNotFound` when absent.
  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> getDonationPage({
    required String nym,
    required String kind,
  });

  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> saveDonationPage(
    BullnymSaveDonationPageRequest request,
  );

  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> archiveDonationPage(
    BullnymArchiveDonationPageRequest request,
  );

  @useResult
  Future<Result<BullnymSupportedCurrencies, BullnymFailure>>
  getSupportedCurrencies();

  /// Private, merchant-authenticated read of the one immutable Bitcoin
  /// fallback destination. The signed action is identity-wide (empty nym).
  @useResult
  Future<Result<BullnymRecoveryAddressLookupResult, BullnymFailure>>
  lookupRecoveryAddress({required BullnymAuthSigner signer});

  /// Register the one Bitcoin fallback destination selected from the current
  /// default wallet. No descriptor or key material is accepted by this API.
  @useResult
  Future<Result<BullnymRecoveryAddressRegistrationResult, BullnymFailure>>
  registerRecoveryAddress({
    required BullnymAuthSigner signer,
    required String btcAddress,
  });

  /// Create a Schnorr-signed recipient invoice. `nym == null` (v1 default)
  /// targets the UNLINKED endpoint `POST /api/v1/invoices` and signs
  /// `nym_or_empty=""`; a non-null nym targets the linked
  /// `POST /api/v1/:nym/invoices`. The client signs the `invoice-create`
  /// action with [signer] at the point of the call.
  @useResult
  Future<Result<BullnymCreateInvoiceResponse, BullnymFailure>> createInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required BullnymCreateInvoiceFields fields,
  });

  /// Cancel an invoice by id (signed `invoice-cancel`). `nym == null` hits the
  /// unlinked `DELETE /api/v1/invoices/:id`. Ownership is enforced server-side
  /// against the signing npub (a non-owner surfaces as `InvoiceNotFound`).
  @useResult
  Future<Result<BullnymCancelInvoiceResponse, BullnymFailure>> cancelInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required String invoiceId,
  });

  /// List the signing npub's invoices (signed `invoice-list`,
  /// `GET /api/v1/invoices`). The list is npub-wide (both linked and unlinked
  /// rows); `nym_or_empty` is ALWAYS empty in the signed bytes.
  @useResult
  Future<Result<BullnymListInvoicesResponse, BullnymFailure>> listInvoices({
    required BullnymAuthSigner signer,
    required int page,
    required int pageSize,
    String? status,
  });

  /// Authenticated, npub-wide and strictly read-only automatic-fallback
  /// projection. The action signs an empty nym and zero payload fields.
  @useResult
  Future<Result<BullnymFallbackSupervisionResponse, BullnymFailure>>
  listFallbackSupervision({required BullnymAuthSigner signer});

  /// Authenticated identity-wide payment-evidence history. The cursor remains
  /// opaque and the signed nym slot is always empty.
  @useResult
  Future<Result<BullnymGetPaidTransactionPage, BullnymFailure>>
  listGetPaidTransactions({
    required BullnymAuthSigner signer,
    required String cursor,
    required int limit,
  });

  /// Public, UNSIGNED status/detail poll by id
  /// (`GET /api/v1/invoices/:id/status`). Anyone holding the id can poll it.
  @useResult
  Future<Result<BullnymInvoiceStatus, BullnymFailure>> getInvoiceStatus({
    required String invoiceId,
  });

  /// Explicit public payer demand for one selected fiat quote rail. Status
  /// GETs remain pure and never create a provider obligation.
  @useResult
  Future<Result<BullnymPayerDemandQuoteResponse, BullnymFailure>>
  getInvoiceQuote({
    required String invoiceId,
    required BullnymPayerQuoteRail rail,
  });

  /// Private, merchant-authenticated read of the current per-product
  /// fiat-settlement configuration (signed `fiat-settlement-get`, empty nym).
  @useResult
  Future<Result<BullnymFiatSettlementConfiguration, BullnymFailure>>
  getFiatSettlementConfiguration({required BullnymAuthSigner signer});

  /// Set (or, with [fiatPercentage] == 0, disable) one product's fiat
  /// settlement (signed `fiat-settlement-set`, empty nym). The scoped
  /// `SELL_TO_FIAT_BALANCE` [apiKey] is supplied ONLY when the server has no
  /// active stored credential; it is injected into the request at this final
  /// transport boundary and never held elsewhere. When [fiatPercentage] is 0
  /// the [fiatCurrency] and [apiKey] must be null (Bitcoin-only / disable).
  @useResult
  Future<Result<BullnymFiatSettlementConfiguration, BullnymFailure>>
  setFiatSettlement({
    required BullnymAuthSigner signer,
    required BullnymFiatSettlementProduct product,
    required int fiatPercentage,
    String? fiatCurrency,
    String? apiKey,
  });
}

final class BullnymBackupFetchRequest {
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

final class BullnymBackupStoreRequest {
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

final class BullnymBackupDeleteRequest {
  final BullnymBackupStream stream;
  final String npubHex;
  final int generation;
  final String expectedEtag;
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
  final String verificationNpubHex;
  final String npubHex;
  final String signatureHex;
  final int timestamp;

  const BullnymRegisterRequest({
    required this.nym,
    required this.ctDescriptor,
    required this.verificationNpubHex,
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
