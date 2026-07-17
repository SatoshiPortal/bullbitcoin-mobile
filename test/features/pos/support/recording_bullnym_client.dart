import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';
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

  String _backupKey(BullnymBackupStream stream, String npubHex) =>
      '${stream.wireName}|$npubHex';

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

  BullnymException _backupConflict() =>
      const BullnymException.serverRejectedRequest(
        code: 'BackupConflict',
        diagnosticReason: 'backup etag mismatch',
        statusCode: 409,
        retryable: false,
      );

  BullnymDonationPage? storedPage;
  BullnymException? getError;
  BullnymException? saveError;
  BullnymException? archiveError;
  BullnymException? currenciesError;

  List<BullnymSupportedCurrency> currencies = const [
    BullnymSupportedCurrency(code: 'CAD', precision: 2),
    BullnymSupportedCurrency(code: 'USD', precision: 2),
  ];

  int get totalWriteCalls => saveCalls.length + archiveCalls.length;

  String _backupKey(BullnymBackupStream stream, String npubHex) =>
      '${stream.wireName}|$npubHex';

  @override
  Future<BullnymRegisterResult> register(BullnymRegisterRequest request) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteRegistration(
    BullnymDeleteRegistrationRequest request,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<BullnymLookupResult> lookupRegistration({
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
  Future<BullnymDonationPage> getDonationPage({
    required String nym,
    required String kind,
  }) async {
    getDonationPageCalls += 1;
    getKinds.add(kind);
    final error = getError;
    if (error != null) throw error;
    final page = storedPage;
    if (page == null) {
      throw const BullnymException.serverRejectedRequest(
        code: 'DonationPageNotFound',
        diagnosticReason: 'no donation page',
        statusCode: 200,
        retryable: false,
      );
    }
    return page;
  }

  @override
  Future<BullnymDonationPage> saveDonationPage(
    BullnymSaveDonationPageRequest request,
  ) async {
    saveCalls.add(request);
    final error = saveError;
    if (error != null) throw error;
    return _viewFromSave(request);
  }

  @override
  Future<BullnymDonationPage> archiveDonationPage(
    BullnymArchiveDonationPageRequest request,
  ) async {
    archiveCalls.add(request);
    final error = archiveError;
    if (error != null) throw error;
    final page = storedPage;
    return BullnymDonationPage(
      nym: request.nym,
      header: page?.header ?? 'My Till',
      description: page?.description ?? '',
      displayCurrency: page?.displayCurrency ?? 'CAD',
      kind: request.kind,
      posMode: false,
      enabled: page?.enabled ?? true,
      isArchived: true,
      publicUrl: page?.publicUrl ?? 'https://bullpay.ca/${request.nym}/pos',
    );
  }

  @override
  Future<BullnymSupportedCurrencies> getSupportedCurrencies() async {
    final error = currenciesError;
    if (error != null) throw error;
    return BullnymSupportedCurrencies(currencies: currencies);
  }

  // Invoice surface — not exercised by the pos donation-page tests.
  @override
  Future<BullnymCreateInvoiceResponse> createInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required BullnymCreateInvoiceFields fields,
  }) => throw UnimplementedError();

  @override
  Future<BullnymCancelInvoiceResponse> cancelInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required String invoiceId,
  }) => throw UnimplementedError();

  @override
  Future<BullnymListInvoicesResponse> listInvoices({
    required BullnymAuthSigner signer,
    required int page,
    required int pageSize,
    String? status,
  }) => throw UnimplementedError();

  @override
  Future<BullnymInvoiceStatus> getInvoiceStatus({required String invoiceId}) =>
      throw UnimplementedError();

  BullnymException _backupConflict() =>
      const BullnymException.serverRejectedRequest(
        code: 'BackupConflict',
        diagnosticReason: 'backup etag mismatch',
        statusCode: 409,
        retryable: false,
      );

  BullnymDonationPage _viewFromSave(BullnymSaveDonationPageRequest request) {
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
      publicUrl: 'https://bullpay.ca/${request.nym}/pos',
    );
  }
}
