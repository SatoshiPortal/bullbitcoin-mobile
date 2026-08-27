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
import 'package:bb_mobile/features/bullnym/domain/repositories/bullnym_repository.dart';
import 'package:bb_mobile/features/bullnym/domain/usecases/bullnym_usecases.dart';
import 'package:meta/meta.dart';

export 'package:bb_mobile/features/bullnym/domain/bullnym_backup.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_fiat_settlement.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_fallback_supervision.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_get_paid_transaction.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_invoice_quote.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_recovery_address.dart';
export 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';
export 'package:bb_mobile/features/bullnym/presentation/bullnym_failure_l10n.dart';

final class BullnymFacade {
  final GetBullnymVersionUsecase _getVersion;
  final RegisterBullnymUsecase _register;
  final DeleteBullnymRegistrationUsecase _deleteRegistration;
  final LookupBullnymRegistrationUsecase _lookupRegistration;
  final GetDonationPageUsecase _getDonationPage;
  final SaveDonationPageUsecase _saveDonationPage;
  final ArchiveDonationPageUsecase _archiveDonationPage;
  final GetSupportedCurrenciesUsecase _getSupportedCurrencies;
  final LookupRecoveryAddressUsecase _lookupRecoveryAddress;
  final RegisterRecoveryAddressUsecase _registerRecoveryAddress;
  final CreateInvoiceUsecase _createInvoice;
  final CancelInvoiceUsecase _cancelInvoice;
  final ListInvoicesUsecase _listInvoices;
  final ListFallbackSupervisionUsecase _listFallbackSupervision;
  final ListGetPaidTransactionsUsecase _listGetPaidTransactions;
  final GetInvoiceStatusUsecase _getInvoiceStatus;
  final GetInvoiceQuoteUsecase _getInvoiceQuote;
  final GetFiatSettlementUsecase _getFiatSettlement;
  final SetFiatSettlementUsecase _setFiatSettlement;
  final FetchBullnymBackupUsecase _fetchBackup;
  final StoreBullnymBackupUsecase _storeBackup;
  final DeleteBullnymBackupUsecase _deleteBackup;

  const BullnymFacade._(
    this._getVersion,
    this._register,
    this._deleteRegistration,
    this._lookupRegistration,
    this._getDonationPage,
    this._saveDonationPage,
    this._archiveDonationPage,
    this._getSupportedCurrencies,
    this._lookupRecoveryAddress,
    this._registerRecoveryAddress,
    this._createInvoice,
    this._cancelInvoice,
    this._listInvoices,
    this._listFallbackSupervision,
    this._listGetPaidTransactions,
    this._getInvoiceStatus,
    this._getInvoiceQuote,
    this._getFiatSettlement,
    this._setFiatSettlement,
    this._fetchBackup,
    this._storeBackup,
    this._deleteBackup,
  );

  factory BullnymFacade.create(
    BullnymRepository repository,
    BullnymAuthenticator authenticator,
  ) => BullnymFacade._(
    GetBullnymVersionUsecase(repository),
    RegisterBullnymUsecase(repository, authenticator),
    DeleteBullnymRegistrationUsecase(repository, authenticator),
    LookupBullnymRegistrationUsecase(repository, authenticator),
    GetDonationPageUsecase(repository),
    SaveDonationPageUsecase(repository, authenticator),
    ArchiveDonationPageUsecase(repository, authenticator),
    GetSupportedCurrenciesUsecase(repository),
    LookupRecoveryAddressUsecase(repository, authenticator),
    RegisterRecoveryAddressUsecase(repository, authenticator),
    CreateInvoiceUsecase(repository, authenticator),
    CancelInvoiceUsecase(repository, authenticator),
    ListInvoicesUsecase(repository, authenticator),
    ListFallbackSupervisionUsecase(repository, authenticator),
    ListGetPaidTransactionsUsecase(repository, authenticator),
    GetInvoiceStatusUsecase(repository),
    GetInvoiceQuoteUsecase(repository),
    GetFiatSettlementUsecase(repository, authenticator),
    SetFiatSettlementUsecase(repository, authenticator),
    FetchBullnymBackupUsecase(repository, authenticator),
    StoreBullnymBackupUsecase(repository, authenticator),
    DeleteBullnymBackupUsecase(repository, authenticator),
  );

  @useResult
  Future<Result<BullnymVersionInfo, BullnymFailure>> getVersion() =>
      _getVersion.execute();

  @useResult
  Future<Result<BullnymRegisterResult, BullnymFailure>> register({
    required String nym,
    required String ctDescriptor,
    required String verificationNpubHex,
  }) => _register.execute(
    nym: nym,
    ctDescriptor: ctDescriptor,
    verificationNpubHex: verificationNpubHex,
  );

  @useResult
  Future<Result<void, BullnymFailure>> deleteRegistration(String nym) =>
      _deleteRegistration.execute(nym);

  @useResult
  Future<Result<BullnymLookupResult, BullnymFailure>> lookupRegistration() =>
      _lookupRegistration.execute();

  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> getDonationPage({
    required String nym,
    required String kind,
  }) => _getDonationPage.execute(nym: nym, kind: kind);

  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> saveDonationPage({
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
  }) => _saveDonationPage.execute(
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

  @useResult
  Future<Result<BullnymDonationPage, BullnymFailure>> archiveDonationPage({
    required String nym,
    required String kind,
  }) => _archiveDonationPage.execute(nym: nym, kind: kind);

  @useResult
  Future<Result<BullnymSupportedCurrencies, BullnymFailure>>
  getSupportedCurrencies() => _getSupportedCurrencies.execute();

  @useResult
  Future<Result<BullnymRecoveryAddressLookupResult, BullnymFailure>>
  lookupRecoveryAddress() => _lookupRecoveryAddress.execute();

  @useResult
  Future<Result<BullnymRecoveryAddressRegistrationResult, BullnymFailure>>
  registerRecoveryAddress(String btcAddress) =>
      _registerRecoveryAddress.execute(btcAddress);

  @useResult
  Future<Result<BullnymCreateInvoiceResponse, BullnymFailure>> createInvoice({
    String? nym,
    required BullnymCreateInvoiceFields fields,
  }) => _createInvoice.execute(nym: nym, fields: fields);

  @useResult
  Future<Result<BullnymCancelInvoiceResponse, BullnymFailure>> cancelInvoice({
    String? nym,
    required String invoiceId,
  }) => _cancelInvoice.execute(nym: nym, invoiceId: invoiceId);

  @useResult
  Future<Result<BullnymListInvoicesResponse, BullnymFailure>> listInvoices({
    required int page,
    required int pageSize,
    String? status,
  }) => _listInvoices.execute(page: page, pageSize: pageSize, status: status);

  @useResult
  Future<Result<BullnymFallbackSupervisionResponse, BullnymFailure>>
  listFallbackSupervision() => _listFallbackSupervision.execute();

  @useResult
  Future<Result<BullnymGetPaidTransactionPage, BullnymFailure>>
  listGetPaidTransactions({required String cursor, required int limit}) =>
      _listGetPaidTransactions.execute(cursor: cursor, limit: limit);

  @useResult
  Future<Result<BullnymInvoiceStatus, BullnymFailure>> getInvoiceStatus(
    String invoiceId,
  ) => _getInvoiceStatus.execute(invoiceId);

  @useResult
  Future<Result<BullnymPayerDemandQuoteResponse, BullnymFailure>>
  getInvoiceQuote({
    required String invoiceId,
    required BullnymPayerQuoteRail rail,
  }) => _getInvoiceQuote.execute(invoiceId: invoiceId, rail: rail);

  @useResult
  Future<Result<BullnymFiatSettlementConfiguration, BullnymFailure>>
  getFiatSettlementConfiguration() => _getFiatSettlement.execute();

  @useResult
  Future<Result<BullnymFiatSettlementConfiguration, BullnymFailure>>
  setFiatSettlement({
    required BullnymFiatSettlementProduct product,
    required int fiatPercentage,
    String? fiatCurrency,
    String? apiKey,
  }) => _setFiatSettlement.execute(
    product: product,
    fiatPercentage: fiatPercentage,
    fiatCurrency: fiatCurrency,
    apiKey: apiKey,
  );

  @useResult
  Future<Result<BullnymBackupHead, BullnymFailure>> fetchBackup(
    BullnymBackupStream stream,
  ) => _fetchBackup.execute(stream);

  @useResult
  Future<Result<BullnymBackupStoreReceipt, BullnymFailure>> storeBackup({
    required BullnymBackupStream stream,
    required BullnymBackupHead currentHead,
    required BullnymBackupCiphertext ciphertext,
  }) => _storeBackup.execute(
    stream: stream,
    currentHead: currentHead,
    ciphertext: ciphertext,
  );

  @useResult
  Future<Result<BullnymBackupDeleteReceipt?, BullnymFailure>> deleteBackup({
    required BullnymBackupStream stream,
    required BullnymBackupHead currentHead,
  }) => _deleteBackup.execute(stream: stream, currentHead: currentHead);
}
