import 'dart:convert';

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
import 'package:crypto/crypto.dart';

const _currencies = {'ARS', 'CAD', 'COP', 'CRC', 'EUR', 'MXN', 'USD'};

final class BullnymProtocolException implements Exception {
  final BullnymFailure failure;

  const BullnymProtocolException(this.failure);
}

final class BullnymResponseDecoder {
  final Uri trustedPublicOrigin;

  const BullnymResponseDecoder(this.trustedPublicOrigin);

  BullnymVersionInfo version(Map<String, dynamic> json) => BullnymVersionInfo(
    publicNamePolicy: JsonReader(json).optionalString('public_name_policy'),
  );

  BullnymRegisterResult registration(Map<String, dynamic> json) {
    final r = JsonReader(json);
    return BullnymRegisterResult(
      nym: r.string('nym'),
      lightningAddress: r.string('lightning_address'),
      quota: json.containsKey('quota') ? _quota(json['quota']) : null,
    );
  }

  BullnymLookupResult lookup(Map<String, dynamic> json) {
    final r = JsonReader(json);
    final nym = r.string('nym');
    final policy = r.optionalString('public_name_policy');
    if (policy != bullnymPermanentNamesV1Policy) {
      return BullnymLookupResult(
        nym: nym,
        active: r.boolean('active'),
        lightningAddress: r.optionalString('lightning_address'),
      );
    }
    if (!json.containsKey('alias')) _invalid('Missing permanent alias');
    final online = r.boolean('lightning_address_online');
    if (json.containsKey('active') && r.boolean('active') != online) {
      _invalid('Inconsistent lookup status');
    }
    return BullnymLookupResult(
      nym: nym,
      active: online,
      lightningAddress: r.optionalString('lightning_address'),
      publicNameStatus: BullnymPublicNameStatus(
        nym: _publicName(nym),
        alias: _optionalPublicName(json['alias']),
        lightningAddressOnline: online,
        publicNamePolicy: policy!,
        quota: _quota(json['quota']),
      ),
    );
  }

  BullnymDonationPage donationPage(Map<String, dynamic> json) {
    final r = JsonReader(json);
    final nym = _publicName(r.string('nym'));
    final alias = _optionalPublicName(json['alias']);
    final kind = r.string('kind');
    late final BullnymPublicUrl publicUrl;
    try {
      publicUrl = BullnymPublicUrl(
        value: r.string('public_url'),
        trustedOrigin: trustedPublicOrigin,
        nym: nym,
        alias: alias,
        kind: kind,
      );
    } on ArgumentError {
      _invalid('Untrusted public URL');
    }
    return BullnymDonationPage(
      nym: nym.value,
      header: r.string('header'),
      description: r.string('description'),
      displayCurrency: r.string('display_currency'),
      website: r.optionalString('website'),
      twitter: r.optionalString('twitter'),
      instagram: r.optionalString('instagram'),
      kind: kind,
      enabled: r.boolean('enabled'),
      isArchived: r.boolean('is_archived'),
      avatarSha256: r.optionalString('avatar_sha256'),
      ogSha256: r.optionalString('og_sha256'),
      alias: alias?.value,
      publicUrl: publicUrl.value,
    );
  }

  BullnymSupportedCurrencies currencies(Map<String, dynamic> json) {
    final raw = JsonReader(json).list('currencies');
    final seen = <String>{};
    final values = <BullnymSupportedCurrency>[];
    for (final item in raw) {
      final r = JsonReader.object(item, 'currency');
      final code = r.string('code');
      final precision = r.nonNegativeInt('precision');
      final expected = const {
        'ARS': 2,
        'CAD': 2,
        'COP': 2,
        'CRC': 2,
        'EUR': 2,
        'MXN': 2,
        'USD': 2,
      }[code];
      if (expected == null || precision != expected || !seen.add(code)) {
        _invalid('Invalid supported currency');
      }
      values.add(BullnymSupportedCurrency(code: code, precision: precision));
    }
    return BullnymSupportedCurrencies(List.unmodifiable(values));
  }

  BullnymRecoveryAddressLookupResult recoveryAddress(
    Map<String, dynamic> json,
  ) {
    final r = JsonReader(json);
    _version(r, 'version', bullnymRecoveryAddressContractVersion);
    final registered = r.boolean('recovery_address_registered');
    final address = r.optionalString('btc_address');
    final commitment = r.optionalInt('commitment_version');
    final signedAt = r.optionalInt('signed_at_unix');
    final validRegistered =
        address != null &&
        address.isNotEmpty &&
        address == address.trim() &&
        !address.contains('\u0000') &&
        commitment != null &&
        commitment > 0 &&
        signedAt != null &&
        signedAt >= 0;
    final validAbsent =
        address == null && commitment == null && signedAt == null;
    if ((registered && !validRegistered) || (!registered && !validAbsent)) {
      _invalid('Inconsistent recovery address');
    }
    return BullnymRecoveryAddressLookupResult(
      version: bullnymRecoveryAddressContractVersion,
      isRegistered: registered,
      btcAddress: address,
      commitmentVersion: commitment,
      signedAtUnix: signedAt,
    );
  }

  BullnymRecoveryAddressRegistrationResult recoveryAddressReceipt(
    Map<String, dynamic> json,
    int expectedTimestamp,
  ) {
    final r = JsonReader(json);
    _version(r, 'version', bullnymRecoveryAddressContractVersion);
    final registered = r.boolean('recovery_address_registered');
    final timestamp = r.nonNegativeInt('signed_at_unix');
    if (!registered || timestamp != expectedTimestamp) {
      _invalid('Inconsistent recovery address receipt');
    }
    return BullnymRecoveryAddressRegistrationResult(
      version: bullnymRecoveryAddressContractVersion,
      isRegistered: true,
      signedAtUnix: timestamp,
    );
  }

  BullnymBackupHead backupHead(
    Map<String, dynamic> json, {
    required BullnymBackupStream stream,
    required String npubHex,
  }) {
    final r = JsonReader(json);
    _version(r, 'version', 1);
    final found = r.boolean('found');
    final generation = r.nonNegativeInt('generation');
    final etag = r.optionalString('etag');
    if (!found) {
      final updatedAt = r.optionalInt('updated_at');
      if (json['ciphertext'] != null ||
          json['ciphertext_sha256'] != null ||
          json['ciphertext_bytes'] != null ||
          (generation == 0
              ? etag != null || updatedAt != null
              : etag == null || updatedAt == null || updatedAt < 0) ||
          (generation > 0 &&
              etag !=
                  computeBullnymBackupEtag(
                    stream: stream,
                    npubHex: npubHex,
                    generation: generation,
                    ciphertextSha256: '',
                  ))) {
        _invalid('Inconsistent absent backup');
      }
      return BullnymBackupHead.absent(generation: generation, etag: etag);
    }
    final value = r.string('ciphertext');
    final hash = r.string('ciphertext_sha256');
    final bytes = r.nonNegativeInt('ciphertext_bytes');
    final updatedAt = r.nonNegativeInt('updated_at');
    late final BullnymBackupCiphertext ciphertext;
    try {
      ciphertext = BullnymBackupCiphertext(value);
    } on ArgumentError {
      _invalid('Invalid backup ciphertext');
    }
    final decoded = base64.decode(ciphertext.value);
    final expectedEtag = computeBullnymBackupEtag(
      stream: stream,
      npubHex: npubHex,
      generation: generation,
      ciphertextSha256: hash,
    );
    if (generation <= 0 ||
        etag == null ||
        decoded.length != bytes ||
        sha256.convert(decoded).toString() != hash ||
        etag != expectedEtag) {
      _invalid('Inconsistent backup');
    }
    return BullnymBackupHead.present(
      generation: generation,
      etag: etag,
      ciphertext: ciphertext,
      ciphertextSha256: hash,
      updatedAtSecs: updatedAt,
    );
  }

  BullnymBackupStoreReceipt backupStoreReceipt(
    Map<String, dynamic> json, {
    required int generation,
  }) {
    final r = JsonReader(json);
    _version(r, 'version', 1);
    if (r.nonNegativeInt('generation') != generation) {
      _invalid('Inconsistent backup generation');
    }
    return BullnymBackupStoreReceipt(generation, r.string('etag'));
  }

  BullnymBackupDeleteReceipt backupDeleteReceipt(
    Map<String, dynamic> json, {
    required int generation,
  }) {
    final r = JsonReader(json);
    _version(r, 'version', 1);
    if (r.nonNegativeInt('generation') != generation) {
      _invalid('Inconsistent backup generation');
    }
    return BullnymBackupDeleteReceipt(generation, r.string('etag'));
  }

  BullnymFiatSettlementConfiguration fiatSettlement(Map<String, dynamic> json) {
    final r = JsonReader(json);
    _version(r, 'version', bullnymFiatSettlementContractVersion);
    final seen = <BullnymFiatSettlementProduct>{};
    final settings = <BullnymFiatSettlementSetting>[];
    for (final item in r.list('settings')) {
      final entry = JsonReader.object(item, 'setting');
      final product = BullnymFiatSettlementProduct.fromWire(
        entry.string('product'),
      );
      if (product == null) continue;
      final percentage = entry.positiveInt('fiat_percentage');
      final currency = entry.string('fiat_currency');
      if (percentage > 100 ||
          !_currencies.contains(currency) ||
          !seen.add(product)) {
        _invalid('Invalid fiat settlement setting');
      }
      settings.add(
        BullnymFiatSettlementSetting(
          product: product,
          fiatPercentage: percentage,
          fiatCurrency: currency,
        ),
      );
    }
    return BullnymFiatSettlementConfiguration(
      settings: List.unmodifiable(settings),
      credentialStatus: BullnymCredentialStatus.fromWire(
        r.optionalString('credential_status'),
      ),
    );
  }

  BullnymFallbackSupervisionResponse fallbackSupervision(
    Map<String, dynamic> json,
  ) {
    final r = JsonReader(json);
    final items = <BullnymFallbackSupervisionItem>[];
    for (final item in r.list('items')) {
      final entry = JsonReader.object(item, 'fallback item');
      final invoice = JsonReader.object(entry.value('invoice'), 'invoice');
      items.add(
        BullnymFallbackSupervisionItem(
          invoiceId: entry.string('invoice_id'),
          nym: entry.string('nym'),
          recoveryStatus: entry.string('recovery_status'),
          userLockAmountSat: entry.nonNegativeInt('user_lock_amount_sat'),
          serverLockAmountSat: entry.nonNegativeInt('server_lock_amount_sat'),
          lockupAddress: entry.string('lockup_address'),
          refundAddress: entry.optionalString('refund_address'),
          refundTxid: entry.optionalString('refund_txid'),
          swapCreatedAtUnix: entry.nonNegativeInt('swap_created_at_unix'),
          swapUpdatedAtUnix: entry.nonNegativeInt('swap_updated_at_unix'),
          invoice: BullnymFallbackInvoiceContext(
            status: invoice.string('status'),
            amountSat: invoice.nonNegativeInt('amount_sat'),
            fiatAmountMinor: invoice.optionalInt('fiat_amount_minor'),
            fiatCurrency: invoice.optionalString('fiat_currency'),
            publicDescription: invoice.optionalString('public_description'),
            invoiceNumber: invoice.optionalString('invoice_number'),
            createdAtUnix: invoice.nonNegativeInt('created_at_unix'),
          ),
        ),
      );
    }
    final count = r.nonNegativeInt('count');
    if (count != items.length || items.length > 100) {
      _invalid('Inconsistent fallback count');
    }
    return BullnymFallbackSupervisionResponse(
      items: List.unmodifiable(items),
      count: count,
      hasMore: r.boolean('has_more'),
    );
  }

  BullnymCreateInvoiceResponse createdInvoice(Map<String, dynamic> json) {
    final r = JsonReader(json);
    return BullnymCreateInvoiceResponse(
      r.string('invoice_id'),
      r.string('invoice_url'),
    );
  }

  BullnymCancelInvoiceResponse cancelledInvoice(Map<String, dynamic> json) {
    final r = JsonReader(json);
    return BullnymCancelInvoiceResponse(
      r.string('invoice_id'),
      r.string('status'),
    );
  }

  BullnymListInvoicesResponse invoices(Map<String, dynamic> json) {
    final r = JsonReader(json);
    final items = [
      for (final item in r.list('invoices'))
        _invoiceListItem(JsonReader.object(item, 'invoice')),
    ];
    return BullnymListInvoicesResponse(
      invoices: List.unmodifiable(items),
      page: r.nonNegativeInt('page'),
      pageSize: r.nonNegativeInt('pageSize'),
      hasMore: r.boolean('has_more'),
    );
  }

  BullnymInvoiceListItem _invoiceListItem(JsonReader r) =>
      BullnymInvoiceListItem(
        id: r.string('id'),
        nymOwner: r.optionalString('nym_owner'),
        origin: r.string('origin'),
        status: r.string('status'),
        presentationStatus: r.optionalString('presentation_status'),
        pricingMode: r.string('pricing_mode'),
        settlementStatus: r.string('settlement_status'),
        amountSat: r.nonNegativeInt('amount_sat'),
        remainingAmountSat: r.nonNegativeInt('remaining_amount_sat'),
        acceptingPayments: r.optionalBool('accepting_payments'),
        topUpAllowed: r.optionalBool('top_up_allowed'),
        fiatAmountMinor: r.optionalInt('fiat_amount_minor'),
        fiatCurrency: _optionalCurrency(r.optionalString('fiat_currency')),
        memo: r.optionalString('memo'),
        acceptBtc: r.boolean('accept_btc'),
        acceptLn: r.boolean('accept_ln'),
        acceptLiquid: r.boolean('accept_liquid'),
        bitcoinAddress: r.optionalString('bitcoin_address'),
        liquidAddress: r.optionalString('liquid_address'),
        createdAtUnix: r.nonNegativeInt('created_at_unix'),
        expiresAtUnix: r.nonNegativeInt('expires_at_unix'),
        paidVia: r.optionalString('paid_via'),
        paidAtUnix: r.optionalInt('paid_at_unix'),
        paidAmountSat: r.optionalInt('paid_amount_sat'),
        paymentSummary: _paymentSummary(r.value('payment_summary')),
      );

  BullnymMerchantPaymentSummary? _paymentSummary(Object? value) {
    if (value == null) return null;
    final r = JsonReader.object(value, 'payment_summary');
    final count = r.nonNegativeInt('logical_payment_count');
    final lateCount = r.nonNegativeInt('late_payment_count');
    if (r.boolean('multiple_payments') != (count > 1) ||
        r.boolean('has_late_payment') != (lateCount > 0)) {
      _invalid('Inconsistent payment summary');
    }
    final first = r.optionalInt('first_payment_at_unix');
    final last = r.optionalInt('last_payment_at_unix');
    if ((first != null && first < 0) ||
        (last != null && last < 0) ||
        (first != null && last != null && first > last)) {
      _invalid('Inconsistent payment timestamps');
    }
    final reasons = r.list('attention_reasons');
    if (reasons.any((reason) => reason is! String || reason.isEmpty)) {
      _invalid('Invalid payment attention reasons');
    }
    return BullnymMerchantPaymentSummary(
      observedAmountSat: r.nonNegativeInt('observed_amount_sat'),
      creditedAmountSat: r.nonNegativeInt('credited_amount_sat'),
      remainingAmountSat: r.nonNegativeInt('remaining_amount_sat'),
      excessAmountSat: r.nonNegativeInt('excess_amount_sat'),
      logicalPaymentCount: count,
      multiplePayments: count > 1,
      latePaymentCount: lateCount,
      hasLatePayment: lateCount > 0,
      firstPaymentAtUnix: first,
      lastPaymentAtUnix: last,
      acceptingPayments: r.boolean('accepting_payments'),
      topUpAllowed: r.boolean('top_up_allowed'),
      requiresMerchantAction: r.boolean('requires_merchant_action'),
      attentionReasons: List.unmodifiable(reasons.cast<String>()),
      fiat: _fiatSummary(r.value('fiat')),
    );
  }

  BullnymMerchantFiatPaymentSummary? _fiatSummary(Object? value) {
    if (value == null) return null;
    final r = JsonReader.object(value, 'fiat summary');
    return BullnymMerchantFiatPaymentSummary(
      currency: _currency(r.string('currency')),
      targetAmountMinor: r.nonNegativeInt('target_amount_minor'),
      creditedAmountMinor: r.nonNegativeInt('credited_amount_minor'),
      remainingAmountMinor: r.nonNegativeInt('remaining_amount_minor'),
    );
  }

  BullnymInvoiceStatus invoiceStatus(Map<String, dynamic> json) {
    final r = JsonReader(json);
    final pricingMode = r.string('pricing_mode');
    if (pricingMode != 'sat_fixed' && pricingMode != 'fiat_fixed') {
      _invalid('Invalid pricing mode');
    }
    final lightningPr = r.optionalString('lightning_pr');
    final lightningAmount = _optionalPositive(r, 'lightning_amount_sat');
    final liquidAddress = r.optionalString('liquid_address');
    final liquidAmount = _optionalPositive(r, 'liquid_amount_sat');
    final bitcoinAddress = r.optionalString('bitcoin_chain_address');
    final bitcoinAmount = _optionalPositive(r, 'bitcoin_chain_amount_sat');
    _instructionPair(lightningPr, lightningAmount);
    _instructionPair(liquidAddress, liquidAmount);
    _instructionPair(bitcoinAddress, bitcoinAmount);
    final bip21 = r.optionalString('bitcoin_chain_bip21');
    if ((bip21 != null && (bip21.trim().isEmpty || bitcoinAddress == null))) {
      _invalid('Invalid Bitcoin instruction');
    }
    final observations = <BullnymBitcoinDirectObservation>[];
    for (final item in r.list('bitcoin_direct_observations')) {
      final o = JsonReader.object(item, 'bitcoin observation');
      final rail = o.string('rail');
      if (rail != 'bitcoin') _invalid('Invalid observation rail');
      observations.add(
        BullnymBitcoinDirectObservation(
          source: o.string('source'),
          rail: rail,
          txid: o.string('txid'),
          vout: o.nonNegativeInt('vout'),
          address: o.string('address'),
          amountSat: o.nonNegativeInt('amount_sat'),
          confirmations: o.nonNegativeInt('confirmations'),
          blockHeight: o.optionalInt('block_height'),
          state: o.string('state'),
          firstSeenAtUnix: o.nonNegativeInt('first_seen_at_unix'),
          lastSeenAtUnix: o.nonNegativeInt('last_seen_at_unix'),
        ),
      );
    }
    return BullnymInvoiceStatus(
      status: r.string('status'),
      presentationStatus: r.optionalString('presentation_status'),
      pricingMode: pricingMode,
      settlementStatus: r.string('settlement_status'),
      amountSat: r.nonNegativeInt('amount_sat'),
      fiatAmountMinor: r.optionalInt('fiat_amount_minor'),
      fiatCurrency: _optionalCurrency(r.optionalString('fiat_currency')),
      remainingAmountSat: r.nonNegativeInt('remaining_amount_sat'),
      acceptingPayments: r.optionalBool('accepting_payments'),
      topUpAllowed: r.optionalBool('top_up_allowed'),
      paymentToleranceSat: r.nonNegativeInt('payment_tolerance_sat'),
      rateMinorPerBtc: r.optionalInt('rate_minor_per_btc'),
      creationRateMinorPerBtc: _tolerantPositive(
        r.value('creation_rate_minor_per_btc'),
      ),
      rateLocksUntilUnix: r.nonNegativeInt('rate_locks_until_unix'),
      expiresAtUnix: r.nonNegativeInt('expires_at_unix'),
      paidVia: r.optionalString('paid_via'),
      paidAtUnix: r.optionalInt('paid_at_unix'),
      paidAmountSat: r.optionalInt('paid_amount_sat'),
      lightningPr: lightningPr,
      lightningAmountSat: lightningAmount,
      liquidAddress: liquidAddress,
      liquidAmountSat: liquidAmount,
      bitcoinAddress: r.optionalString('bitcoin_address'),
      bitcoinChainAddress: bitcoinAddress,
      bitcoinChainBip21: bip21,
      bitcoinChainAmountSat: bitcoinAmount,
      acceptBtc: r.boolean('accept_btc'),
      acceptLn: r.boolean('accept_ln'),
      acceptLiquid: r.boolean('accept_liquid'),
      bitcoinDirectObservations: List.unmodifiable(observations),
      quoteRailAvailability: _quoteAvailability(
        r.value('quote_rail_availability'),
        required: pricingMode == 'fiat_fixed',
      ),
    );
  }

  BullnymPayerDemandQuoteResponse invoiceQuote(
    Map<String, dynamic> json, {
    required String invoiceId,
    required BullnymPayerQuoteRail rail,
  }) {
    final r = JsonReader(json);
    if (r.string('pricing_mode') != 'fiat_fixed' ||
        r.nonEmptyString('invoice_id') != invoiceId ||
        BullnymPayerQuoteRail.fromWire(r.string('selected_rail')) != rail) {
      _invalid('Quote identity mismatch');
    }
    final q = JsonReader.object(r.value('quote'), 'quote');
    final created = q.nonNegativeInt('created_at_unix');
    final expires = q.nonNegativeInt('expires_at_unix');
    final observed = q.nonNegativeInt('rate_observed_at_unix');
    final fetched = q.nonNegativeInt('rate_fetched_at_unix');
    final fresh = q.nonNegativeInt('rate_fresh_until_unix');
    final face = q.positiveInt('fiat_face_amount_minor');
    final target = q.positiveInt('fiat_target_amount_minor');
    if (target > face ||
        expires - created != 300 ||
        observed >= fresh ||
        fetched >= fresh) {
      _invalid('Inconsistent quote evidence');
    }
    final quote = BullnymFiatQuote(
      quoteVersionId: q.nonEmptyString('quote_version_id'),
      versionNumber: q.positiveInt('version_number'),
      fiatFaceAmountMinor: face,
      fiatTargetAmountMinor: target,
      fiatCurrency: _currency(q.string('fiat_currency')),
      rateMinorPerBtc: q.positiveInt('rate_minor_per_btc'),
      rateSource: q.nonEmptyString('rate_source'),
      rateObservedAtUnix: observed,
      rateFetchedAtUnix: fetched,
      rateFreshUntilUnix: fresh,
      merchantAmountSat: q.positiveInt('merchant_amount_sat'),
      createdAtUnix: created,
      expiresAtUnix: expires,
    );
    return BullnymPayerDemandQuoteResponse(
      invoiceId: invoiceId,
      selectedRail: rail,
      quote: quote,
      instruction: _quoteInstruction(
        JsonReader.object(r.value('instruction'), 'instruction'),
        rail,
        quote.merchantAmountSat,
      ),
    );
  }

  BullnymGetPaidTransactionPage getPaidTransactions(
    Map<String, dynamic> json, {
    required String requestedCursor,
    required int requestedLimit,
  }) {
    final r = JsonReader(json);
    final transactions = <BullnymGetPaidTransaction>[];
    for (final item in r.list('transactions')) {
      final value = JsonReader.object(item, 'transaction');
      final source = BullnymGetPaidTransactionSource.fromWire(
        value.string('source'),
      );
      final rail = BullnymGetPaidTransactionRail.fromWire(value.string('rail'));
      final state = BullnymGetPaidSettlementState.fromWire(
        value.string('settlement_state'),
      );
      if (source == null || rail == null || state == null) {
        _invalid('Unknown transaction enum');
      }
      try {
        transactions.add(
          BullnymGetPaidTransaction(
            transactionId: value.string('transaction_id'),
            source: source,
            invoiceId: value.optionalString('invoice_id'),
            amountSat: value.integer('amount_sat'),
            receivedAtUnix: value.integer('received_at_unix'),
            rail: rail,
            settlementState: state,
            late: value.boolean('late'),
            comment: value.optionalString('comment'),
            settlement: decodeBullnymSettlement(value.json),
          ),
        );
      } on ArgumentError {
        _invalid('Invalid transaction');
      }
    }
    final cursor = r.optionalString('next_cursor');
    if (transactions.length > requestedLimit ||
        (transactions.isEmpty && cursor != null) ||
        cursor == requestedCursor) {
      _invalid('Invalid transaction page');
    }
    try {
      return BullnymGetPaidTransactionPage(
        transactions: transactions,
        nextCursor: cursor,
      );
    } on ArgumentError {
      _invalid('Invalid transaction page');
    }
  }

  int? _optionalPositive(JsonReader r, String key) {
    final value = r.optionalInt(key);
    if (value == null || value > 0) return value;
    _invalid('Invalid positive $key');
  }

  int? _tolerantPositive(Object? value) =>
      value is int && value > 0 ? value : null;

  void _instructionPair(String? payload, int? amount) {
    if ((payload != null && payload.trim().isEmpty) ||
        ((payload != null) != (amount != null))) {
      _invalid('Incomplete payer instruction');
    }
  }

  BullnymPayerQuoteRailAvailability? _quoteAvailability(
    Object? value, {
    required bool required,
  }) {
    if (value == null) {
      if (required) _invalid('Missing quote availability');
      return null;
    }
    if (value is! Map<String, dynamic>) {
      if (required) _invalid('Invalid quote availability');
      return null;
    }
    final r = JsonReader(value);
    if (!required &&
        (value['lightning'] is! bool ||
            value['liquid'] is! bool ||
            value['bitcoin'] is! bool)) {
      return null;
    }
    return BullnymPayerQuoteRailAvailability(
      lightning: r.boolean('lightning'),
      liquid: r.boolean('liquid'),
      bitcoin: r.boolean('bitcoin'),
    );
  }

  BullnymVersionedPayerInstruction _quoteInstruction(
    JsonReader r,
    BullnymPayerQuoteRail rail,
    int merchantAmount,
  ) {
    final kind = r.string('kind');
    final amount = r.positiveInt('payer_amount_sat');
    final instruction = switch ((kind, rail)) {
      ('lightning_boltz_reverse', BullnymPayerQuoteRail.lightning) =>
        BullnymLightningQuoteInstruction(
          quoteOfferId: r.nonEmptyString('quote_offer_id'),
          pr: r.nonEmptyString('pr'),
          payerAmountSat: amount,
        ),
      ('lightning_direct', BullnymPayerQuoteRail.lightning) =>
        BullnymLightningDirectQuoteInstruction(
          pr: r.nonEmptyString('pr'),
          payerAmountSat: amount,
        ),
      ('liquid_direct', BullnymPayerQuoteRail.liquid) =>
        BullnymLiquidQuoteInstruction(
          address: r.nonEmptyString('address'),
          payerAmountSat: amount,
        ),
      ('bitcoin_direct', BullnymPayerQuoteRail.bitcoin) =>
        BullnymBitcoinDirectQuoteInstruction(
          address: r.nonEmptyString('address'),
          bip21: r.nonEmptyString('bip21'),
          payerAmountSat: amount,
        ),
      ('bitcoin_boltz_chain', BullnymPayerQuoteRail.bitcoin) =>
        BullnymBitcoinBoltzQuoteInstruction(
          quoteOfferId: r.nonEmptyString('quote_offer_id'),
          address: r.nonEmptyString('address'),
          bip21: r.nonEmptyString('bip21'),
          payerAmountSat: amount,
        ),
      _ => _invalid('Instruction does not match quote rail'),
    };
    final direct =
        instruction is BullnymLiquidQuoteInstruction ||
        instruction is BullnymLightningDirectQuoteInstruction ||
        instruction is BullnymBitcoinDirectQuoteInstruction;
    if ((direct && amount != merchantAmount) ||
        (!direct && amount <= merchantAmount)) {
      _invalid('Invalid payer amount');
    }
    return instruction;
  }

  String _currency(String value) {
    if (!_currencies.contains(value)) _invalid('Unsupported currency');
    return value;
  }

  String? _optionalCurrency(String? value) =>
      value == null ? null : _currency(value);

  BullnymQuota _quota(Object? value) {
    final r = JsonReader.object(value, 'quota');
    try {
      return BullnymQuota(
        used: r.nonNegativeInt('used'),
        cap: r.nonNegativeInt('cap'),
        remaining: r.nonNegativeInt('remaining'),
      );
    } on ArgumentError {
      _invalid('Inconsistent quota');
    }
  }

  BullnymPublicName _publicName(String value) {
    try {
      return BullnymPublicName(value);
    } on ArgumentError {
      _invalid('Invalid public name');
    }
  }

  BullnymPublicName? _optionalPublicName(Object? value) {
    if (value == null) return null;
    if (value is! String) _invalid('Invalid public name type');
    return _publicName(value);
  }

  void _version(JsonReader r, String key, int expected) {
    if (r.nonNegativeInt(key) != expected) _invalid('Unsupported version');
  }
}

BullnymGetPaidSettlement? decodeBullnymSettlement(Map<String, dynamic> json) {
  if (!json.containsKey('settlement_kind')) return null;
  try {
    final details = json['settlement_details'];
    final override = json['fiat_conversion'];
    return switch (json['settlement_kind']) {
      'bitcoin' => _bitcoinSettlement(details, override),
      'fiat' => _fiatSettlement(details, override),
      'mixed' => _mixedSettlement(details, override),
      _ => BullnymGetPaidSettlement.unavailable,
    };
  } on Exception {
    return BullnymGetPaidSettlement.unavailable;
  }
}

BullnymGetPaidSettlement _bitcoinSettlement(Object? details, Object? override) {
  if (details != null) return BullnymGetPaidSettlement.unavailable;
  if (override == null) {
    return const BullnymGetPaidSettlement(kind: BullnymSettlementKind.bitcoin);
  }
  if (override is! Map<String, dynamic> || override['status'] != 'overridden') {
    return BullnymGetPaidSettlement.unavailable;
  }
  return BullnymGetPaidSettlement(
    kind: BullnymSettlementKind.bitcoin,
    overrideReason: switch (override['reason']) {
      'below_minimum' => BullnymFiatConversionOverrideReason.belowMinimum,
      'invalid_split' => BullnymFiatConversionOverrideReason.invalidSplit,
      'conversion_unavailable' =>
        BullnymFiatConversionOverrideReason.conversionUnavailable,
      'ambiguous_create' => BullnymFiatConversionOverrideReason.ambiguousCreate,
      _ => BullnymFiatConversionOverrideReason.unknown,
    },
  );
}

BullnymGetPaidSettlement _fiatSettlement(Object? raw, Object? override) {
  if (override != null ||
      raw is! Map<String, dynamic> ||
      raw['kind'] != 'fiat' ||
      raw.containsKey('bitcoin')) {
    return BullnymGetPaidSettlement.unavailable;
  }
  final fiat = _fiatLegs(raw['fiat']);
  final percentage = _percentage(raw['fiat_percentage'], 100, 100);
  final creation = _creationRate(raw);
  if (fiat == null || fiat.isEmpty || percentage == -1 || creation == null) {
    return BullnymGetPaidSettlement.unavailable;
  }
  return BullnymGetPaidSettlement(
    kind: BullnymSettlementKind.fiat,
    fiat: fiat,
    fiatPercentage: percentage,
    creationRateMinorPerBtc: creation.$1,
    creationRateCurrency: creation.$2,
  );
}

BullnymGetPaidSettlement _mixedSettlement(Object? raw, Object? override) {
  if (override != null ||
      raw is! Map<String, dynamic> ||
      raw['kind'] != 'mixed') {
    return BullnymGetPaidSettlement.unavailable;
  }
  final fiat = _fiatLegs(raw['fiat']);
  final bitcoin = _bitcoinLegs(raw['bitcoin']);
  final percentage = _percentage(raw['fiat_percentage'], 1, 99);
  final creation = _creationRate(raw);
  if (fiat == null ||
      fiat.isEmpty ||
      bitcoin == null ||
      bitcoin.isEmpty ||
      percentage == -1 ||
      creation == null) {
    return BullnymGetPaidSettlement.unavailable;
  }
  return BullnymGetPaidSettlement(
    kind: BullnymSettlementKind.mixed,
    fiat: fiat,
    bitcoin: bitcoin,
    fiatPercentage: percentage,
    creationRateMinorPerBtc: creation.$1,
    creationRateCurrency: creation.$2,
  );
}

List<BullnymFiatSettlementLeg>? _fiatLegs(Object? raw) {
  if (raw is! List) return null;
  final values = <BullnymFiatSettlementLeg>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) return null;
    final currency = item['currency'];
    final orderId = item['order_id'];
    final status = switch (item['status']) {
      'pending' => BullnymSettlementLegStatus.pending,
      'settled' => BullnymSettlementLegStatus.settled,
      'unavailable' => BullnymSettlementLegStatus.unavailable,
      _ => null,
    };
    if (currency is! String ||
        !_currencies.contains(currency) ||
        orderId is! String ||
        !_canonicalUuid(orderId) ||
        status == null) {
      return null;
    }
    final amount = item['amount_minor'];
    if (status == BullnymSettlementLegStatus.settled
        ? amount is! int || amount <= 0
        : amount != null) {
      return null;
    }
    final quoted = _optionalPositiveValue(item['quoted_amount_minor']);
    final execution = _optionalPositiveValue(
      item['execution_rate_minor_per_btc'],
    );
    if (quoted == -1 || execution == -1) return null;
    values.add(
      BullnymFiatSettlementLeg(
        amountMinor: amount as int?,
        quotedAmountMinor: quoted,
        executionRateMinorPerBtc: execution,
        currency: currency,
        orderId: orderId,
        status: status,
      ),
    );
  }
  return List.unmodifiable(values);
}

List<BullnymBitcoinSettlementLeg>? _bitcoinLegs(Object? raw) {
  if (raw is! List) return null;
  final values = <BullnymBitcoinSettlementLeg>[];
  for (final item in raw) {
    if (item is! Map<String, dynamic>) return null;
    final amount = item['amount_sat'];
    final status = switch (item['status']) {
      'pending' => BullnymSettlementLegStatus.pending,
      'settled' => BullnymSettlementLegStatus.settled,
      'problem' => BullnymSettlementLegStatus.problem,
      _ => null,
    };
    if (amount is! int ||
        amount <= 0 ||
        item['network'] != 'liquid' ||
        status == null) {
      return null;
    }
    values.add(
      BullnymBitcoinSettlementLeg(
        amountSat: amount,
        network: 'liquid',
        status: status,
      ),
    );
  }
  return List.unmodifiable(values);
}

(int?, String?)? _creationRate(Map<String, dynamic> json) {
  final rate = json['creation_rate_minor_per_btc'];
  final currency = json['creation_rate_currency'];
  if (rate != null && (rate is! int || rate <= 0)) return null;
  if (currency != null &&
      (currency is! String || !_currencies.contains(currency))) {
    return null;
  }
  return (rate as int?, currency as String?);
}

int? _percentage(Object? value, int min, int max) {
  if (value == null) return null;
  return value is int && value >= min && value <= max ? value : -1;
}

int? _optionalPositiveValue(Object? value) {
  if (value == null) return null;
  return value is int && value > 0 ? value : -1;
}

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

bool _canonicalUuid(String value) =>
    value != '00000000-0000-0000-0000-000000000000' && _uuid.hasMatch(value);

final class JsonReader {
  final Map<String, dynamic> json;

  const JsonReader(this.json);

  factory JsonReader.object(Object? value, String field) {
    if (value is! Map<String, dynamic>) _invalid('Invalid $field object');
    return JsonReader(value);
  }

  Object? value(String key) => json[key];

  String string(String key) {
    final value = json[key];
    if (value is String) return value;
    _invalid('Invalid $key string');
  }

  String nonEmptyString(String key) {
    final value = string(key);
    if (value.trim().isNotEmpty) return value;
    _invalid('Empty $key');
  }

  String? optionalString(String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is String) return value;
    _invalid('Invalid $key string');
  }

  bool boolean(String key) {
    final value = json[key];
    if (value is bool) return value;
    _invalid('Invalid $key bool');
  }

  bool? optionalBool(String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is bool) return value;
    _invalid('Invalid $key bool');
  }

  int integer(String key) {
    final value = json[key];
    if (value is int) return value;
    _invalid('Invalid $key int');
  }

  int nonNegativeInt(String key) {
    final value = integer(key);
    if (value >= 0) return value;
    _invalid('Negative $key');
  }

  int positiveInt(String key) {
    final value = integer(key);
    if (value > 0) return value;
    _invalid('Non-positive $key');
  }

  int? optionalInt(String key) {
    final value = json[key];
    if (value == null) return null;
    if (value is int) return value;
    _invalid('Invalid $key int');
  }

  List<dynamic> list(String key) {
    final value = json[key];
    if (value is List<dynamic>) return value;
    _invalid('Invalid $key list');
  }
}

Never _invalid(
  String message, [
  BullnymRequestPhase phase = BullnymRequestPhase.read,
]) {
  throw BullnymProtocolException(
    BullnymInvalidResponseFailure(phase: phase, logMessage: message),
  );
}
