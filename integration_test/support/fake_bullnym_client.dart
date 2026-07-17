import 'dart:convert';

import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_auth_signer.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_donation_page.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_failure.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_invoice_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';

enum FakeBullnymMode {
  live,
  inactiveWithPreviousNym,
  registrationMissing,
  serverUnreachable,
}

/// Donation-page fault modes for the payment-page/POS recovery matrix.
enum FakeDonationPageMode { normal, missing, archived, serverUnreachable }

/// Point-of-sale fault modes. Independent of both
/// [FakeBullnymMode] and [FakeDonationPageMode] so a single instance can hold a
/// live page (102) while the POS (103) surface is driven through its own
/// heal/provision faults. Applied only to `kind='pos'` calls;
/// `kind='payment_page'` calls stay on [donationPageMode].
enum FakePosMode {
  /// GET returns the stored pos row (or NotFound if none saved); writes succeed.
  normal,

  /// GET always throws DonationPageNotFound (pos row purged / never created).
  missing,

  /// GET returns the stored pos row marked archived.
  archived,

  /// A kind=pos save/archive fails with AuthError - the pre-release pay2
  /// fail-closed emulation (KR-2/DG-P7): the old server rebuilds the signed
  /// message without `kind`, so the signature never verifies.
  saveAuthError,

  /// Every kind=pos call fails with a retryable server error.
  serverUnreachable,
}

/// Invoice fault modes for the §9/F11 matrix. Independent of the page/pos
/// modes so a single instance drives the invoice lifecycle while the other
/// surfaces stay live. The `*Once` reuse modes fire on the first matching
/// create then clear themselves, so the create usecase's single
/// regenerate-and-retry succeeds (SPEC-INV-01 PF variant).
enum FakeInvoiceMode {
  /// Create/list/status/cancel behave normally against the in-memory store.
  normal,

  /// Status/cancel of any id throw `InvoiceNotFound` (foreign/unknown id).
  notFound,

  /// The first create carrying a BTC rail throws `BitcoinAddressAlreadyUsed`,
  /// then clears to [normal].
  reusedBitcoinAddressOnce,

  /// The first create carrying a Liquid rail throws
  /// `LiquidAddressAlreadyUsed`, then clears to [normal].
  reusedLiquidAddressOnce,

  /// Every signed call fails with `AuthError` (wrong-key / clock-skew device).
  authError,

  /// Every create/list fails with a rate-limit rejection.
  rateLimited,

  /// Every call fails with a retryable server error.
  serverUnreachable,

  /// The signed routes are absent (`features.invoices=false` / pre-flag pay2):
  /// create/cancel/list 404 so the feature fails CLOSED, never silent success.
  featureDisabled,
}

class _FakeInvoice {
  final String id;
  final String ownerNpub;
  final String? nymOwner;
  final BullnymCreateInvoiceFields fields;
  final int createdAtUnix;
  final int expiresAtUnix;
  String status = 'unpaid';

  _FakeInvoice({
    required this.id,
    required this.ownerNpub,
    required this.nymOwner,
    required this.fields,
    required this.createdAtUnix,
    required this.expiresAtUnix,
  });
}

class _FakeInvoiceCreateRecord {
  final String invoiceId;
  final String fingerprint;

  const _FakeInvoiceCreateRecord(this.invoiceId, this.fingerprint);
}

/// In-memory [BullnymClientPort] for L1 tests (HARNESS §2.2). It survives
/// local app-state resets, records register and donation-page write calls, and
/// is toggle-driven so a single instance can drive the DG-3 heal matrix (live /
/// lapsed / missing / unreachable).
class FakeBullnymClient implements BullnymClientPort {
  FakeBullnymMode mode = FakeBullnymMode.live;
  FakeDonationPageMode donationPageMode = FakeDonationPageMode.normal;
  FakePosMode posMode = FakePosMode.normal;
  FakeInvoiceMode invoiceMode = FakeInvoiceMode.normal;
  String nym = 'alice';

  final List<String> registeredNyms = [];
  final List<BullnymSaveDonationPageRequest> saveDonationPageCalls = [];
  final List<BullnymArchiveDonationPageRequest> archiveDonationPageCalls = [];
  final Map<String, BullnymBackupHead> _backups = {};

  // Server-side invoice state keyed by id; independent of the page/pos stores
  // and survives local app-state resets. `createInvoiceCalls` records the raw
  // create inputs (npub, nym slot, supplied addresses/blinding key) for the
  // payout-discipline and unlinked-nym assertions.
  final Map<String, _FakeInvoice> _invoices = {};
  final Map<String, _FakeInvoiceCreateRecord> _invoiceCreates = {};
  final List<({String npub, String? nym, BullnymCreateInvoiceFields fields})>
  createInvoiceCalls = [];
  int _nextInvoiceSeq = 1;

  // Server-side donation-page state keyed `(nym, kind)`; survives local
  // app-state resets.
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
  Future<Result<BullnymRegisterResult, BullnymFailure>> register(
    BullnymRegisterRequest request,
  ) async {
    registeredNyms.add(request.nym);
    if (mode == FakeBullnymMode.serverUnreachable) {
      return const Err(
        BullnymFailure.serverRejectedRequest(
          code: 'ServiceUnavailable',
          logMessage: 'fake service unreachable',
          statusCode: 503,
          retryable: true,
        ),
      );
    }
    nym = request.nym;
    mode = FakeBullnymMode.live;
    return Ok(
      BullnymRegisterResult(nym: nym, lightningAddress: _lightningAddress),
    );
  }

  @override
  Future<Result<void, BullnymFailure>> deleteRegistration(
    BullnymDeleteRegistrationRequest request,
  ) async => const Ok(null);

  @override
  Future<Result<BullnymLookupResult, BullnymFailure>> lookupRegistration({
    required String npubHex,
  }) async {
    switch (mode) {
      case FakeBullnymMode.live:
        return Ok(
          BullnymLookupResult(
            nym: nym,
            active: true,
            lightningAddress: _lightningAddress,
          ),
        );
      case FakeBullnymMode.inactiveWithPreviousNym:
        return Ok(BullnymLookupResult(nym: nym, active: false));
      case FakeBullnymMode.registrationMissing:
        return const Err(
          BullnymFailure.serverRejectedRequest(
            code: 'NymNotFound',
            logMessage: 'no registration for npub',
            statusCode: 404,
            retryable: false,
          ),
        );
      case FakeBullnymMode.serverUnreachable:
        return const Err(
          BullnymFailure.serverRejectedRequest(
            code: 'ServiceUnavailable',
            logMessage: 'fake service unreachable',
            statusCode: 503,
            retryable: true,
          ),
        );
    }
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
  Future<Result<BullnymDonationPage, BullnymFailure>> getDonationPage({
    required String nym,
    required String kind,
  }) async {
    final isPos = kind == bullnymDonationPageKindPos;
    if (isPos) {
      if (posMode == FakePosMode.serverUnreachable) {
        return Err(_serverUnreachable());
      }
      if (posMode == FakePosMode.missing) return Err(_notFound());
    } else {
      if (donationPageMode == FakeDonationPageMode.serverUnreachable) {
        return Err(_serverUnreachable());
      }
      if (donationPageMode == FakeDonationPageMode.missing) {
        return Err(_notFound());
      }
    }
    final page = _pages[_pageKey(nym, kind)];
    if (page == null) return Err(_notFound());
    final archived = isPos
        ? posMode == FakePosMode.archived
        : donationPageMode == FakeDonationPageMode.archived;
    if (archived) return Ok(_copyWith(page, isArchived: true));
    return Ok(page);
  }

  @override
  Future<Result<BullnymDonationPage, BullnymFailure>> saveDonationPage(
    BullnymSaveDonationPageRequest request,
  ) async {
    saveDonationPageCalls.add(request);
    final isPos = request.kind == bullnymDonationPageKindPos;
    if (isPos) {
      // KR-1 server backstop: a kind=pos save has NO LA-cursor fallback, so a
      // descriptorless pos save is HARD-REJECTED here (never silently routed to
      // the LA wallet 101). The client must make an empty descriptor impossible.
      if (request.ctDescriptor.isEmpty) return Err(_donationPageInvalid());
      if (posMode == FakePosMode.serverUnreachable) {
        return Err(_serverUnreachable());
      }
      if (posMode == FakePosMode.saveAuthError) return Err(_authError());
    } else {
      if (donationPageMode == FakeDonationPageMode.serverUnreachable) {
        return Err(_serverUnreachable());
      }
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
      posMode: request.kind == bullnymDonationPageKindPos,
      enabled: request.enabled,
      isArchived: false,
      publicUrl: isPos
          ? 'https://example.invalid/${request.nym}/pos'
          : 'https://example.invalid/${request.nym}',
    );
    _pages[_pageKey(request.nym, request.kind)] = page;
    return Ok(page);
  }

  @override
  Future<Result<BullnymDonationPage, BullnymFailure>> archiveDonationPage(
    BullnymArchiveDonationPageRequest request,
  ) async {
    archiveDonationPageCalls.add(request);
    final isPos = request.kind == bullnymDonationPageKindPos;
    if (isPos) {
      if (posMode == FakePosMode.serverUnreachable) {
        return Err(_serverUnreachable());
      }
      if (posMode == FakePosMode.saveAuthError) return Err(_authError());
    } else {
      if (donationPageMode == FakeDonationPageMode.serverUnreachable) {
        return Err(_serverUnreachable());
      }
    }
    final key = _pageKey(request.nym, request.kind);
    final page = _pages[key];
    if (page == null || page.isArchived) {
      // Double-archive / archive-of-missing: the server preserves nothing to
      // archive and returns DonationPageNotFound.
      return Err(_notFound());
    }
    final archived = _copyWith(page, isArchived: true);
    _pages[key] = archived;
    return Ok(archived);
  }

  @override
  Future<Result<BullnymSupportedCurrencies, BullnymFailure>>
  getSupportedCurrencies() async {
    if (donationPageMode == FakeDonationPageMode.serverUnreachable) {
      return Err(_serverUnreachable());
    }
    return Ok(BullnymSupportedCurrencies(currencies: supportedCurrencies));
  }

  @override
  Future<Result<BullnymCreateInvoiceResponse, BullnymFailure>> createInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required BullnymCreateInvoiceFields fields,
  }) async {
    createInvoiceCalls.add((npub: signer.npubHex, nym: nym, fields: fields));
    if (invoiceMode == FakeInvoiceMode.featureDisabled) {
      return const Err(BullnymFailure.unexpectedHttpStatus(statusCode: 404));
    }
    if (invoiceMode == FakeInvoiceMode.serverUnreachable) {
      return Err(_serverUnreachable());
    }
    if (invoiceMode == FakeInvoiceMode.authError) return Err(_authError());
    if (invoiceMode == FakeInvoiceMode.rateLimited) {
      return Err(_invoiceRateLimited());
    }

    // Server echoes (create_invoice_inner): at least one rail, rail↔address
    // coherence, one-of amount, and the expiry window.
    if (!fields.acceptBtc && !fields.acceptLn && !fields.acceptLiquid) {
      return Err(_invalidAmount('at least one rail must be accepted'));
    }
    if (fields.acceptBtc &&
        (fields.bitcoinAddress == null || fields.bitcoinAddress!.isEmpty)) {
      return Err(_invalidAmount('accept_btc requires a bitcoin_address'));
    }
    if ((fields.acceptLn || fields.acceptLiquid) &&
        (fields.liquidAddress == null || fields.liquidAddress!.isEmpty)) {
      return Err(_invalidAmount('a liquid rail requires a liquid_address'));
    }
    if (fields.acceptLiquid &&
        (fields.liquidBlindingKeyHex == null ||
            fields.liquidBlindingKeyHex!.isEmpty)) {
      return Err(
        _invalidAmount('accept_liquid requires a liquid_blinding_key_hex'),
      );
    }
    final hasSat = fields.amountSat != null;
    final hasFiat =
        fields.fiatAmountMinor != null && fields.fiatCurrency != null;
    if (hasSat == hasFiat) {
      return Err(_invalidAmount('amount must be exactly one of sat or fiat'));
    }
    if (fields.clientRequestId.isEmpty ||
        fields.presentationEnvelope.length != 5500) {
      return Err(_invalidAmount('private presentation is invalid'));
    }

    final createKey = '${signer.npubHex}:${fields.clientRequestId}';
    final fingerprint = jsonEncode(buildInvoiceCreatePayloadFields(fields));
    final existing = _invoiceCreates[createKey];
    if (existing != null) {
      if (existing.fingerprint != fingerprint) {
        return const Err(
          BullnymFailure.serverRejectedRequest(
            code: 'InvoiceCreateConflict',
            logMessage: 'request id already used for another payload',
            statusCode: 409,
            retryable: false,
          ),
        );
      }
      return Ok(
        BullnymCreateInvoiceResponse(
          invoiceId: existing.invoiceId,
          invoiceUrl: _invoiceUrl(existing.invoiceId, nym),
        ),
      );
    }

    if (invoiceMode == FakeInvoiceMode.reusedBitcoinAddressOnce &&
        fields.acceptBtc) {
      invoiceMode = FakeInvoiceMode.normal;
      return Err(_bitcoinAddressAlreadyUsed());
    }
    if (invoiceMode == FakeInvoiceMode.reusedLiquidAddressOnce &&
        (fields.acceptLn || fields.acceptLiquid)) {
      invoiceMode = FakeInvoiceMode.normal;
      return Err(_liquidAddressAlreadyUsed());
    }

    final id = 'inv-${_nextInvoiceSeq++}';
    final createdAtUnix = fields.expiresAtUnix != null
        ? fields.expiresAtUnix! - 86400
        : 1710000000;
    _invoices[id] = _FakeInvoice(
      id: id,
      ownerNpub: signer.npubHex,
      nymOwner: nym,
      fields: fields,
      createdAtUnix: createdAtUnix,
      expiresAtUnix: fields.expiresAtUnix ?? createdAtUnix + 86400,
    );
    _invoiceCreates[createKey] = _FakeInvoiceCreateRecord(id, fingerprint);
    return Ok(
      BullnymCreateInvoiceResponse(
        invoiceId: id,
        invoiceUrl: _invoiceUrl(id, nym),
      ),
    );
  }

  @override
  Future<Result<BullnymCancelInvoiceResponse, BullnymFailure>> cancelInvoice({
    required BullnymAuthSigner signer,
    String? nym,
    required String invoiceId,
  }) async {
    if (invoiceMode == FakeInvoiceMode.featureDisabled) {
      return const Err(BullnymFailure.unexpectedHttpStatus(statusCode: 404));
    }
    if (invoiceMode == FakeInvoiceMode.serverUnreachable) {
      return Err(_serverUnreachable());
    }
    if (invoiceMode == FakeInvoiceMode.authError) return Err(_authError());
    final invoice = _invoices[invoiceId];
    // Ownership is server-side: a non-owner (or unknown id) is InvoiceNotFound.
    if (invoice == null ||
        invoice.ownerNpub != signer.npubHex ||
        invoiceMode == FakeInvoiceMode.notFound) {
      return Err(_invoiceNotFound());
    }
    // Cancel only flips an unpaid invoice; an already-terminal invoice returns
    // its existing status benignly.
    if (invoice.status == 'unpaid') invoice.status = 'cancelled';
    return Ok(
      BullnymCancelInvoiceResponse(
        invoiceId: invoiceId,
        status: invoice.status,
      ),
    );
  }

  @override
  Future<Result<BullnymListInvoicesResponse, BullnymFailure>> listInvoices({
    required BullnymAuthSigner signer,
    required int page,
    required int pageSize,
    String? status,
  }) async {
    if (invoiceMode == FakeInvoiceMode.featureDisabled) {
      return const Err(BullnymFailure.unexpectedHttpStatus(statusCode: 404));
    }
    if (invoiceMode == FakeInvoiceMode.serverUnreachable) {
      return Err(_serverUnreachable());
    }
    if (invoiceMode == FakeInvoiceMode.authError) return Err(_authError());
    if (invoiceMode == FakeInvoiceMode.rateLimited) {
      return Err(_invoiceRateLimited());
    }

    final owned =
        _invoices.values
            .where((i) => i.ownerNpub == signer.npubHex)
            .where(
              (i) => status == null || status.isEmpty || i.status == status,
            )
            .toList()
          ..sort((a, b) => b.createdAtUnix.compareTo(a.createdAtUnix));
    final start = (page - 1) * pageSize;
    final pageRows = start >= owned.length
        ? <_FakeInvoice>[]
        : owned.sublist(start, (start + pageSize).clamp(0, owned.length));
    return Ok(
      BullnymListInvoicesResponse(
        invoices: pageRows.map(_toListItem).toList(),
        page: page,
        pageSize: pageSize,
        hasMore: start + pageSize < owned.length,
      ),
    );
  }

  @override
  Future<Result<BullnymInvoiceStatus, BullnymFailure>> getInvoiceStatus({
    required String invoiceId,
  }) async {
    if (invoiceMode == FakeInvoiceMode.serverUnreachable) {
      return Err(_serverUnreachable());
    }
    final invoice = _invoices[invoiceId];
    if (invoice == null || invoiceMode == FakeInvoiceMode.notFound) {
      return Err(_invoiceNotFound());
    }
    final f = invoice.fields;
    return Ok(
      BullnymInvoiceStatus(
        status: invoice.status,
        pricingMode: f.amountSat != null ? 'sat' : 'fiat',
        settlementStatus: 'none',
        amountSat: f.amountSat ?? 0,
        fiatAmountMinor: f.fiatAmountMinor,
        fiatCurrency: f.fiatCurrency,
        remainingAmountSat: f.amountSat ?? 0,
        paymentToleranceSat: 0,
        rateMinorPerBtc: null,
        rateLocksUntilUnix: invoice.createdAtUnix,
        expiresAtUnix: invoice.expiresAtUnix,
        acceptBtc: f.acceptBtc,
        acceptLn: f.acceptLn,
        acceptLiquid: f.acceptLiquid,
        liquidAddress: f.liquidAddress,
        bitcoinAddress: f.bitcoinAddress,
        bitcoinDirectObservations: const [],
      ),
    );
  }

  BullnymInvoiceListItem _toListItem(_FakeInvoice i) {
    final f = i.fields;
    return BullnymInvoiceListItem(
      id: i.id,
      nymOwner: i.nymOwner,
      origin: 'wallet',
      status: i.status,
      presentationStatus: 'available',
      pricingMode: f.amountSat != null ? 'sat' : 'fiat',
      settlementStatus: 'none',
      amountSat: f.amountSat ?? 0,
      remainingAmountSat: f.amountSat ?? 0,
      fiatAmountMinor: f.fiatAmountMinor,
      fiatCurrency: f.fiatCurrency,
      memo: null,
      acceptBtc: f.acceptBtc,
      acceptLn: f.acceptLn,
      acceptLiquid: f.acceptLiquid,
      bitcoinAddress: f.bitcoinAddress,
      liquidAddress: f.liquidAddress,
      createdAtUnix: i.createdAtUnix,
      expiresAtUnix: i.expiresAtUnix,
    );
  }

  String _invoiceUrl(String invoiceId, String? nym) => nym == null
      ? 'https://example.invalid/invoice/$invoiceId'
      : 'https://example.invalid/$nym/i/$invoiceId';

  BullnymFailure _invoiceNotFound() =>
      const BullnymFailure.serverRejectedRequest(
        code: 'InvoiceNotFound',
        logMessage: 'invoice not found',
        statusCode: 200,
        retryable: false,
      );

  BullnymFailure _invalidAmount(String reason) =>
      BullnymFailure.serverRejectedRequest(
        code: 'InvalidAmount',
        logMessage: reason,
        statusCode: 200,
        retryable: false,
      );

  BullnymFailure _bitcoinAddressAlreadyUsed() =>
      const BullnymFailure.serverRejectedRequest(
        code: 'BitcoinAddressAlreadyUsed',
        logMessage: 'bitcoin address already assigned to an invoice',
        statusCode: 409,
        retryable: false,
      );

  BullnymFailure _liquidAddressAlreadyUsed() =>
      const BullnymFailure.serverRejectedRequest(
        code: 'LiquidAddressAlreadyUsed',
        logMessage: 'liquid address already assigned to an invoice',
        statusCode: 409,
        retryable: false,
      );

  BullnymFailure _invoiceRateLimited() =>
      const BullnymFailure.serverRejectedRequest(
        code: 'RateLimitedSender',
        logMessage: 'invoice create rate limit exceeded',
        statusCode: 200,
        retryable: true,
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

  BullnymFailure _notFound() => const BullnymFailure.serverRejectedRequest(
    code: 'DonationPageNotFound',
    logMessage: 'no donation page for nym',
    statusCode: 200,
    retryable: false,
  );

  BullnymFailure _serverUnreachable() =>
      const BullnymFailure.serverRejectedRequest(
        code: 'ServiceUnavailable',
        logMessage: 'fake server unreachable',
        statusCode: 503,
        retryable: true,
      );

  // The kind=pos server backstop for a descriptorless save (KR-1): the server
  // rejects it as invalid rather than falling back to any wallet.
  BullnymFailure _donationPageInvalid() =>
      const BullnymFailure.serverRejectedRequest(
        code: 'DonationPageInvalid',
        logMessage: 'kind=pos save requires a non-empty ct_descriptor',
        statusCode: 400,
        retryable: false,
      );

  // The pre-release-server fail-closed emulation (KR-2/DG-P7): signing over a
  // `kind` the old server does not rebuild yields a signature mismatch.
  BullnymFailure _authError() => const BullnymFailure.serverRejectedRequest(
    code: 'AuthError',
    logMessage: 'signature verification failed',
    statusCode: 401,
    retryable: false,
  );

  BullnymDonationPage _copyWith(BullnymDonationPage page, {bool? isArchived}) {
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
