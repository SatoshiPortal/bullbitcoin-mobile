import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup.dart';
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
import 'package:bb_mobile/features/bullnym/domain/bullnym_signing.dart';
import 'package:meta/meta.dart';

abstract interface class BullnymRepository {
  @useResult
  Future<Result<BullnymVersionInfo, BullnymFailure>> getVersion();

  @useResult
  Future<Result<BullnymRegisterResult, BullnymFailure>> register({
    required BullnymAuthentication auth,
    required String nym,
    required String ctDescriptor,
    required String verificationNpubHex,
  });

  @useResult
  Future<Result<void, BullnymFailure>> deleteRegistration({
    required BullnymAuthentication auth,
    required String nym,
  });

  @useResult
  Future<Result<BullnymLookupResult, BullnymFailure>> lookupRegistration(
    String npubHex,
  );

  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> getDonationPage({
    required String nym,
    required String kind,
  });

  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> saveDonationPage({
    required BullnymAuthentication auth,
    required String nym,
    required String ctDescriptor,
    required String header,
    required String description,
    required String displayCurrency,
    required String website,
    required String twitter,
    required String instagram,
    required bool enabled,
    required String kind,
    required BullnymAliasIntent aliasIntent,
  });

  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> archiveDonationPage({
    required BullnymAuthentication auth,
    required String nym,
    required String kind,
  });

  @useResult
  Future<Result<BullnymSupportedCurrencies, BullnymFailure>>
  getSupportedCurrencies();

  @useResult
  Future<Result<BullnymRecoveryAddressLookupResult, BullnymFailure>>
  lookupRecoveryAddress(BullnymAuthentication auth);

  @useResult
  Future<Result<BullnymRecoveryAddressRegistrationResult, BullnymFailure>>
  registerRecoveryAddress({
    required BullnymAuthentication auth,
    required String btcAddress,
  });

  @useResult
  Future<Result<BullnymCreateInvoiceResponse, BullnymFailure>> createInvoice({
    required BullnymAuthentication auth,
    required String? nym,
    required BullnymCreateInvoiceFields fields,
  });

  @useResult
  Future<Result<BullnymCancelInvoiceResponse, BullnymFailure>> cancelInvoice({
    required BullnymAuthentication auth,
    required String? nym,
    required String invoiceId,
  });

  @useResult
  Future<Result<BullnymListInvoicesResponse, BullnymFailure>> listInvoices({
    required BullnymAuthentication auth,
    required int page,
    required int pageSize,
    required String? status,
  });

  @useResult
  Future<Result<BullnymFallbackSupervisionResponse, BullnymFailure>>
  listFallbackSupervision(BullnymAuthentication auth);

  @useResult
  Future<Result<BullnymGetPaidTransactionPage, BullnymFailure>>
  listGetPaidTransactions({
    required BullnymAuthentication auth,
    required String cursor,
    required int limit,
  });

  @useResult
  Future<Result<BullnymInvoiceStatus, BullnymFailure>> getInvoiceStatus(
    String invoiceId,
  );

  @useResult
  Future<Result<BullnymPayerDemandQuoteResponse, BullnymFailure>>
  getInvoiceQuote({
    required String invoiceId,
    required BullnymPayerQuoteRail rail,
  });

  @useResult
  Future<Result<BullnymFiatSettlementConfiguration, BullnymFailure>>
  getFiatSettlementConfiguration(BullnymAuthentication auth);

  @useResult
  Future<Result<BullnymFiatSettlementConfiguration, BullnymFailure>>
  setFiatSettlement({
    required BullnymAuthentication auth,
    required BullnymFiatSettlementProduct product,
    required int fiatPercentage,
    required String? fiatCurrency,
    required String? apiKey,
  });

  @useResult
  Future<Result<BullnymBackupHead, BullnymFailure>> fetchBackup({
    required BullnymAuthentication auth,
    required BullnymBackupStream stream,
  });

  @useResult
  Future<Result<BullnymBackupStoreReceipt, BullnymFailure>> storeBackup({
    required BullnymAuthentication auth,
    required BullnymBackupStream stream,
    required int generation,
    required String? expectedEtag,
    required BullnymBackupCiphertext ciphertext,
    required String ciphertextSha256,
  });

  @useResult
  Future<Result<BullnymBackupDeleteReceipt, BullnymFailure>> deleteBackup({
    required BullnymAuthentication auth,
    required BullnymBackupStream stream,
    required int generation,
    required String expectedEtag,
  });
}
