import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fallback_supervision.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_get_paid_transaction.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice_quote.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_recovery_address.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
import 'package:bb_mobile/features/bullnym/domain/bullpay_signing.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/archive_donation_page_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/delete_bullnym_registration_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/delete_bullnym_backup_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/fetch_bullnym_backup_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/get_donation_page_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/get_bullnym_version_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/get_supported_currencies_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/lookup_bullnym_registration_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/register_bullnym_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/save_donation_page_usecase.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/store_bullnym_backup_usecase.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
export 'package:bb_mobile/core/backup/authenticated_backup_cipher.dart'
    show AuthenticatedBackupCiphertext;
export 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_fallback_supervision.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_get_paid_transaction.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_invoice_quote.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_recovery_address.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
export 'package:bb_mobile/features/bullnym/presentation/bullnym_failure_l10n.dart';

class BullnymFacade {
  final BullnymClientPort _client;
  final GetBullnymVersionUsecase _getVersion;
  final RegisterBullnymUsecase _register;
  final DeleteBullnymRegistrationUsecase _deleteRegistration;
  final LookupBullnymRegistrationUsecase _lookupRegistration;
  final FetchBullnymBackupUsecase _fetchBackup;
  final StoreBullnymBackupUsecase _storeBackup;
  final DeleteBullnymBackupUsecase _deleteBackup;
  final GetDonationPageUsecase _getDonationPage;
  final SaveDonationPageUsecase _saveDonationPage;
  final ArchiveDonationPageUsecase _archiveDonationPage;
  final GetSupportedCurrenciesUsecase _getSupportedCurrencies;

  BullnymFacade({
    required BullnymClientPort client,
    int Function() nowSecs = currentBullpayTimestampSecs,
  }) : _client = client,
       _getVersion = GetBullnymVersionUsecase(client),
       _register = RegisterBullnymUsecase(client, nowSecs),
       _deleteRegistration = DeleteBullnymRegistrationUsecase(client, nowSecs),
       _lookupRegistration = LookupBullnymRegistrationUsecase(client),
       _fetchBackup = FetchBullnymBackupUsecase(client, nowSecs),
       _storeBackup = StoreBullnymBackupUsecase(client, nowSecs),
       _deleteBackup = DeleteBullnymBackupUsecase(client, nowSecs),
       _getDonationPage = GetDonationPageUsecase(client),
       _saveDonationPage = SaveDonationPageUsecase(client, nowSecs),
       _archiveDonationPage = ArchiveDonationPageUsecase(client, nowSecs),
       _getSupportedCurrencies = GetSupportedCurrenciesUsecase(client);

  @useResult
  Future<Result<BullnymVersionInfo, BullnymFailure>> getVersion() {
    return _getVersion.execute();
  }

  @useResult
  Future<Result<BullnymRegisterResult, BullnymFailure>> register({
    required BullnymAuthSigner signer,
    required String nym,
    required String ctDescriptor,
    required String verificationNpubHex,
  }) {
    return _register.execute(
      signer: signer,
      nym: nym,
      ctDescriptor: ctDescriptor,
      verificationNpubHex: verificationNpubHex,
    );
  }

  @useResult
  Future<Result<void, BullnymFailure>> deleteRegistration({
    required BullnymAuthSigner signer,
    required String nym,
  }) {
    return _deleteRegistration.execute(signer: signer, nym: nym);
  }

  @useResult
  Future<Result<BullnymLookupResult, BullnymFailure>> lookupRegistration({
    required String npubHex,
  }) {
    return _lookupRegistration.execute(npubHex: npubHex);
  }

  Future<BullnymBackupHead> fetchBackup({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
  }) => _fetchBackup.execute(signer: signer, stream: stream);

  Future<BullnymBackupStoreReceipt> storeBackup({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
    required BullnymBackupHead currentHead,
    required AuthenticatedBackupCiphertext ciphertext,
  }) => _storeBackup.execute(
    signer: signer,
    stream: stream,
    currentHead: currentHead,
    ciphertext: ciphertext,
  );

  Future<BullnymBackupDeleteReceipt?> deleteBackup({
    required BullnymAuthSigner signer,
    required BullnymBackupStream stream,
    required BullnymBackupHead currentHead,
  }) => _deleteBackup.execute(
    signer: signer,
    stream: stream,
    currentHead: currentHead,
  );

  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> getDonationPage({
    required String nym,
    required String kind,
  }) {
    return _getDonationPage.execute(nym: nym, kind: kind);
  }

  // `kind` is surfaced (not pinned) so the future POS surface reuses this
  // client; the payment_page feature pins `kind = payment_page`.
  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> saveDonationPage({
    required BullnymAuthSigner signer,
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
    BullnymAliasIntent aliasIntent = const BullnymAliasIntent.preserve(),
  }) {
    return _saveDonationPage.execute(
      signer: signer,
      nym: nym,
      ctDescriptor: ctDescriptor,
      header: header,
      description: description,
      displayCurrency: displayCurrency,
      website: website,
      twitter: twitter,
      instagram: instagram,
      enabled: enabled,
      kind: kind,
      aliasIntent: aliasIntent,
    );
  }

  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> archiveDonationPage({
    required BullnymAuthSigner signer,
    required String nym,
    required String kind,
  }) {
    return _archiveDonationPage.execute(signer: signer, nym: nym, kind: kind);
  }

  @useResult
  Future<Result<BullnymSupportedCurrencies, BullnymFailure>>
  getSupportedCurrencies() {
    return _getSupportedCurrencies.execute();
  }

  @useResult
  Future<Result<BullnymRecoveryAddressLookupResult, BullnymFailure>>
  lookupRecoveryAddress({required BullnymAuthSigner signer}) {
    return _client.lookupRecoveryAddress(signer: signer);
  }

  @useResult
  Future<Result<BullnymRecoveryAddressRegistrationResult, BullnymFailure>>
  registerRecoveryAddress({
    required BullnymAuthSigner signer,
    required String btcAddress,
  }) {
    return _client.registerRecoveryAddress(
      signer: signer,
      btcAddress: btcAddress,
    );
  }

  // Invoice methods sign in the client (the `invoice-*` actions) and delegate
  // straight through. `nym` stays nullable (default null = the unlinked v1
  // path) so the facade is linked-capable when DG-I1 later flips it on.
  @useResult
  Future<Result<BullnymCreateInvoiceResponse, BullnymFailure>> createInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required BullnymCreateInvoiceFields fields,
  }) {
    return _client.createInvoice(signer: signer, nym: nym, fields: fields);
  }

  @useResult
  Future<Result<BullnymCancelInvoiceResponse, BullnymFailure>> cancelInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required String invoiceId,
  }) {
    return _client.cancelInvoice(
      signer: signer,
      nym: nym,
      invoiceId: invoiceId,
    );
  }

  @useResult
  Future<Result<BullnymListInvoicesResponse, BullnymFailure>> listInvoices({
    required BullnymAuthSigner signer,
    required int page,
    required int pageSize,
    String? status,
  }) {
    return _client.listInvoices(
      signer: signer,
      page: page,
      pageSize: pageSize,
      status: status,
    );
  }

  @useResult
  Future<Result<BullnymFallbackSupervisionResponse, BullnymFailure>>
  listFallbackSupervision({required BullnymAuthSigner signer}) {
    return _client.listFallbackSupervision(signer: signer);
  }

  @useResult
  Future<Result<BullnymGetPaidTransactionPage, BullnymFailure>>
  listGetPaidTransactions({
    required BullnymAuthSigner signer,
    required String cursor,
    required int limit,
  }) {
    return _client.listGetPaidTransactions(
      signer: signer,
      cursor: cursor,
      limit: limit,
    );
  }

  @useResult
  Future<Result<BullnymInvoiceStatus, BullnymFailure>> getInvoiceStatus({
    required String invoiceId,
  }) {
    return _client.getInvoiceStatus(invoiceId: invoiceId);
  }

  @useResult
  Future<Result<BullnymPayerDemandQuoteResponse, BullnymFailure>>
  getInvoiceQuote({
    required String invoiceId,
    required BullnymPayerQuoteRail rail,
  }) {
    return _client.getInvoiceQuote(invoiceId: invoiceId, rail: rail);
  }

  @override
  String toString() => 'BullnymFacade';
}
