import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_fallback_supervision.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice_quote.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_public_names.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_recovery_address.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';

/// A hand fake [BullnymClientPort] for pos unit tests: it records the
/// donation-page write calls (so zero-write / coexistence assertions are
/// possible) and lets a test seed a stored row or inject typed failures per
/// method. Mirrors the payment_page test double so the pos feature keeps its own
/// support (it does not import payment_page).
class RecordingBullnymClient implements BullnymClientPort {
  final List<BullnymSaveDonationPageRequest> saveCalls = [];
  final List<BullnymArchiveDonationPageRequest> archiveCalls = [];
  final List<String> getKinds = [];
  final Map<String, BullnymBackupHead> _backups = {};
  int getDonationPageCalls = 0;

  BullnymDonationPage? storedPage;
  BullnymFailure? getError;
  BullnymFailure? saveError;
  BullnymFailure? archiveError;
  BullnymFailure? currenciesError;

  List<BullnymSupportedCurrency> currencies = const [
    BullnymSupportedCurrency(code: 'CAD', precision: 2),
    BullnymSupportedCurrency(code: 'USD', precision: 2),
  ];

  int get totalWriteCalls => saveCalls.length + archiveCalls.length;

  String _backupKey(BullnymBackupStream stream, String npubHex) =>
      '${stream.wireName}|$npubHex';

  @override
  Future<Result<BullnymVersionInfo, BullnymFailure>> getVersion() async =>
      const Ok(
        BullnymVersionInfo(publicNamePolicy: bullnymPermanentNamesV1Policy),
      );

  @override
  Future<Result<BullnymRegisterResult, BullnymFailure>> register(
    BullnymRegisterRequest request,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<void, BullnymFailure>> deleteRegistration(
    BullnymDeleteRegistrationRequest request,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<Result<BullnymLookupResult, BullnymFailure>> lookupRegistration({
    required String npubHex,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<BullnymBackupHead> fetchBackup(
    BullnymBackupFetchRequest request,
  ) async {
    return _backups[_backupKey(request.stream, request.npubHex)] ??
        BullnymBackupHead.absent(generation: 0, etag: null);
  }

  @override
  Future<BullnymBackupStoreReceipt> storeBackup(
    BullnymBackupStoreRequest request,
  ) async {
    final key = _backupKey(request.stream, request.npubHex);
    final current = _backups[key];
    if (request.expectedEtag != current?.etag) throw _backupConflict();
    final etag = computeWalletBackupEtag(
      stream: request.stream,
      npubHex: request.npubHex,
      generation: request.generation,
      ciphertextSha256: request.ciphertextSha256,
    );
    _backups[key] = BullnymBackupHead.present(
      generation: request.generation,
      etag: etag,
      ciphertext: request.ciphertext,
      ciphertextSha256: request.ciphertextSha256,
      updatedAtSecs: request.timestamp,
    );
    return BullnymBackupStoreReceipt(
      generation: request.generation,
      etag: etag,
    );
  }

  @override
  Future<BullnymBackupDeleteReceipt> deleteBackup(
    BullnymBackupDeleteRequest request,
  ) async {
    final key = _backupKey(request.stream, request.npubHex);
    final current = _backups[key];
    if (request.expectedEtag != current?.etag) throw _backupConflict();
    final etag = computeWalletBackupEtag(
      stream: request.stream,
      npubHex: request.npubHex,
      generation: request.generation,
      ciphertextSha256: '',
    );
    _backups[key] = BullnymBackupHead.absent(
      generation: request.generation,
      etag: etag,
    );
    return BullnymBackupDeleteReceipt(
      generation: request.generation,
      etag: etag,
    );
  }

  @override
  Future<Result<BullnymDonationPage, BullnymFailure>> getDonationPage({
    required String nym,
    required String kind,
  }) async {
    getDonationPageCalls += 1;
    getKinds.add(kind);
    final error = getError;
    if (error != null) return Err(error);
    final page = storedPage;
    if (page == null) {
      return const Err(
        BullnymFailure.serverRejectedRequest(
          code: 'DonationPageNotFound',
          logMessage: 'no donation page',
          statusCode: 200,
          retryable: false,
        ),
      );
    }
    return Ok(page);
  }

  @override
  Future<Result<BullnymDonationPage, BullnymFailure>> saveDonationPage(
    BullnymSaveDonationPageRequest request,
  ) async {
    saveCalls.add(request);
    final error = saveError;
    if (error != null) return Err(error);
    return Ok(_viewFromSave(request));
  }

  @override
  Future<Result<BullnymDonationPage, BullnymFailure>> archiveDonationPage(
    BullnymArchiveDonationPageRequest request,
  ) async {
    archiveCalls.add(request);
    final error = archiveError;
    if (error != null) return Err(error);
    final page = storedPage;
    return Ok(
      BullnymDonationPage(
        nym: request.nym,
        header: page?.header ?? 'My Till',
        description: page?.description ?? '',
        displayCurrency: page?.displayCurrency ?? 'CAD',
        kind: request.kind,
        posMode: false,
        enabled: page?.enabled ?? true,
        isArchived: true,
        alias: page?.alias,
        publicUrl: page?.publicUrl ?? 'https://bullpay.ca/${request.nym}/pos',
      ),
    );
  }

  @override
  Future<Result<BullnymSupportedCurrencies, BullnymFailure>>
  getSupportedCurrencies() async {
    final error = currenciesError;
    if (error != null) return Err(error);
    return Ok(BullnymSupportedCurrencies(currencies: currencies));
  }

  @override
  Future<Result<BullnymRecoveryAddressLookupResult, BullnymFailure>>
  lookupRecoveryAddress({required BullnymAuthSigner signer}) async =>
      const Ok(BullnymRecoveryAddressLookupResult.unregistered());

  @override
  Future<Result<BullnymRecoveryAddressRegistrationResult, BullnymFailure>>
  registerRecoveryAddress({
    required BullnymAuthSigner signer,
    required String btcAddress,
  }) async => const Ok(
    BullnymRecoveryAddressRegistrationResult(
      version: bullnymRecoveryAddressContractVersion,
      isRegistered: true,
      signedAtUnix: 0,
    ),
  );

  // Invoice surface — not exercised by the pos donation-page tests.
  @override
  Future<Result<BullnymCreateInvoiceResponse, BullnymFailure>> createInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required BullnymCreateInvoiceFields fields,
  }) => throw UnimplementedError();

  @override
  Future<Result<BullnymCancelInvoiceResponse, BullnymFailure>> cancelInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required String invoiceId,
  }) => throw UnimplementedError();

  @override
  Future<Result<BullnymListInvoicesResponse, BullnymFailure>> listInvoices({
    required BullnymAuthSigner signer,
    required int page,
    required int pageSize,
    String? status,
  }) => throw UnimplementedError();

  @override
  Future<Result<BullnymFallbackSupervisionResponse, BullnymFailure>>
  listFallbackSupervision({required BullnymAuthSigner signer}) =>
      throw UnimplementedError();

  @override
  Future<Result<BullnymInvoiceStatus, BullnymFailure>> getInvoiceStatus({
    required String invoiceId,
  }) => throw UnimplementedError();

  @override
  Future<Result<BullnymPayerDemandQuoteResponse, BullnymFailure>>
  getInvoiceQuote({
    required String invoiceId,
    required BullnymPayerQuoteRail rail,
  }) => throw UnimplementedError();

  BullnymException _backupConflict() =>
      const BullnymException.serverRejectedRequest(
        code: 'BackupConflict',
        diagnosticReason: 'backup etag mismatch',
        statusCode: 409,
        retryable: false,
      );

  BullnymDonationPage _viewFromSave(BullnymSaveDonationPageRequest request) {
    final alias = switch (request.aliasIntent) {
      BullnymAliasPreserve() => storedPage?.alias,
      BullnymAliasClaim(:final alias) => alias.value,
    };
    return BullnymDonationPage(
      nym: request.nym,
      header: request.header,
      description: request.description,
      displayCurrency: request.displayCurrency,
      website: request.website.isEmpty ? null : request.website,
      twitter: request.twitter.isEmpty ? null : request.twitter,
      instagram: request.instagram.isEmpty ? null : request.instagram,
      kind: request.kind,
      posMode: false,
      enabled: request.enabled,
      isArchived: false,
      alias: alias,
      publicUrl: alias == null
          ? 'https://bullpay.ca/${request.nym}/pos'
          : 'https://bullpay.ca/a/$alias/pos',
    );
  }
}
