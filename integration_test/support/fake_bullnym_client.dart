import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';

enum FakeBullnymMode {
  live,
  inactiveWithPreviousNym,
  registrationMissing,
  serverUnreachable,
}

/// Donation-page fault modes for the payment-page/POS recovery matrix.
enum FakeDonationPageMode {
  normal,
  missing,
  archived,
  serverUnreachable,
}

/// In-memory Bullnym boundary for Get Paid lifecycle tests.
///
/// The object intentionally survives local app-state wipes so tests can model
/// automatic remote recovery. Registration and backup faults share one mode;
/// donation-page faults are independent so product recovery cases can vary
/// page state without changing the nym lookup state.
class FakeBullnymClient implements BullnymClientPort {
  FakeBullnymMode mode = FakeBullnymMode.live;
  FakeDonationPageMode donationPageMode = FakeDonationPageMode.normal;
  String nym = 'alice';

  final List<String> registeredNyms = [];
  final List<BullnymSaveDonationPageRequest> saveDonationPageCalls = [];
  final List<BullnymArchiveDonationPageRequest> archiveDonationPageCalls = [];
  final Map<String, BullnymBackupHead> _backups = {};
  final Map<String, BullnymDonationPage> _pages = {};

  List<BullnymSupportedCurrency> supportedCurrencies = const [
    BullnymSupportedCurrency(code: 'CAD', precision: 2),
    BullnymSupportedCurrency(code: 'USD', precision: 2),
    BullnymSupportedCurrency(code: 'EUR', precision: 2),
  ];

  int get totalDonationWriteCalls =>
      saveDonationPageCalls.length + archiveDonationPageCalls.length;

  String get _lightningAddress => '$nym@example.invalid';

  String _backupKey(BullnymBackupStream stream, String npubHex) =>
      '${stream.wireName}|$npubHex';

  String _pageKey(String nym, String kind) => '$nym|$kind';

  @override
  Future<BullnymRegisterResult> register(BullnymRegisterRequest request) async {
    if (mode == FakeBullnymMode.serverUnreachable) throw _unavailable();
    registeredNyms.add(request.nym);
    nym = request.nym;
    mode = FakeBullnymMode.live;
    return BullnymRegisterResult(nym: nym, lightningAddress: _lightningAddress);
  }

  @override
  Future<void> deleteRegistration(
    BullnymDeleteRegistrationRequest request,
  ) async {}

  @override
  Future<BullnymLookupResult> lookupRegistration({
    required String npubHex,
  }) async {
    return switch (mode) {
      FakeBullnymMode.live => BullnymLookupResult(
        nym: nym,
        active: true,
        lightningAddress: _lightningAddress,
      ),
      FakeBullnymMode.inactiveWithPreviousNym => BullnymLookupResult(
        nym: nym,
        active: false,
      ),
      FakeBullnymMode.registrationMissing => throw _missing(),
      FakeBullnymMode.serverUnreachable => throw _unavailable(),
    };
  }

  @override
  Future<BullnymBackupHead> fetchBackup(
    BullnymBackupFetchRequest request,
  ) async {
    if (mode == FakeBullnymMode.serverUnreachable) throw _unavailable();
    return _backups[_backupKey(request.stream, request.npubHex)] ??
        BullnymBackupHead.absent(generation: 0, etag: null);
  }

  @override
  Future<BullnymBackupStoreReceipt> storeBackup(
    BullnymBackupStoreRequest request,
  ) async {
    if (mode == FakeBullnymMode.serverUnreachable) throw _unavailable();
    final key = _backupKey(request.stream, request.npubHex);
    final current = _backups[key];
    if (request.expectedEtag != current?.etag) throw _conflict();
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
    if (mode == FakeBullnymMode.serverUnreachable) throw _unavailable();
    final key = _backupKey(request.stream, request.npubHex);
    final current = _backups[key];
    if (request.expectedEtag != current?.etag) throw _conflict();
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
    if (donationPageMode == FakeDonationPageMode.serverUnreachable) {
      throw _serverUnreachable();
    }
    if (donationPageMode == FakeDonationPageMode.missing) {
      throw _notFound();
    }
    final page = _pages[_pageKey(nym, kind)];
    if (page == null) throw _notFound();
    if (donationPageMode == FakeDonationPageMode.archived) {
      return _copyWith(page, isArchived: true);
    }
    return page;
  }

  @override
  Future<BullnymDonationPage> saveDonationPage(
    BullnymSaveDonationPageRequest request,
  ) async {
    saveDonationPageCalls.add(request);
    if (donationPageMode == FakeDonationPageMode.serverUnreachable) {
      throw _serverUnreachable();
    }
    final page = BullnymDonationPage(
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
      publicUrl: 'https://example.invalid/${request.nym}',
    );
    _pages[_pageKey(request.nym, request.kind)] = page;
    return page;
  }

  @override
  Future<BullnymDonationPage> archiveDonationPage(
    BullnymArchiveDonationPageRequest request,
  ) async {
    archiveDonationPageCalls.add(request);
    if (donationPageMode == FakeDonationPageMode.serverUnreachable) {
      throw _serverUnreachable();
    }
    final key = _pageKey(request.nym, request.kind);
    final page = _pages[key];
    if (page == null || page.isArchived) throw _notFound();
    final archived = _copyWith(page, isArchived: true);
    _pages[key] = archived;
    return archived;
  }

  @override
  Future<BullnymSupportedCurrencies> getSupportedCurrencies() async {
    if (donationPageMode == FakeDonationPageMode.serverUnreachable) {
      throw _serverUnreachable();
    }
    return BullnymSupportedCurrencies(currencies: supportedCurrencies);
  }

  BullnymException _missing() => const BullnymException.serverRejectedRequest(
    code: 'NymNotFound',
    diagnosticReason: 'no registration for public key',
    statusCode: 404,
    retryable: false,
  );

  BullnymException _unavailable() =>
      const BullnymException.serverRejectedRequest(
        code: 'ServiceUnavailable',
        diagnosticReason: 'fake service unavailable',
        statusCode: 503,
        retryable: true,
      );

  BullnymException _conflict() => const BullnymException.serverRejectedRequest(
    code: 'BackupConflict',
    diagnosticReason: 'backup etag mismatch',
    statusCode: 409,
    retryable: false,
  );

  BullnymException _notFound() => const BullnymException.serverRejectedRequest(
    code: 'DonationPageNotFound',
    diagnosticReason: 'no donation page for nym',
    statusCode: 200,
    retryable: false,
  );

  BullnymException _serverUnreachable() =>
      const BullnymException.serverRejectedRequest(
        code: 'ServiceUnavailable',
        diagnosticReason: 'fake server unreachable',
        statusCode: 503,
        retryable: true,
      );

  BullnymDonationPage _copyWith(
    BullnymDonationPage page, {
    bool? isArchived,
  }) {
    return BullnymDonationPage(
      nym: page.nym,
      header: page.header,
      description: page.description,
      displayCurrency: page.displayCurrency,
      website: page.website,
      twitter: page.twitter,
      instagram: page.instagram,
      kind: page.kind,
      posMode: page.posMode,
      enabled: page.enabled,
      isArchived: isArchived ?? page.isArchived,
      avatarSha256: page.avatarSha256,
      ogSha256: page.ogSha256,
      publicUrl: page.publicUrl,
    );
  }
}
