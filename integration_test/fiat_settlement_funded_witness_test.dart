import 'package:bb_mobile/core/exchange/data/datasources/bullbitcoin_api_key_datasource.dart';
import 'package:bb_mobile/core/exchange/data/models/scoped_api_key_model.dart';
import 'package:bb_mobile/core/settings/domain/get_settings_usecase.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/data/repositories/wallet_repository.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/create_default_wallets_usecase.dart';
import 'package:bb_mobile/features/fiat_settlement/public/fiat_settlement_facade.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_settlement.dart';
import 'package:bb_mobile/features/get_paid/domain/get_paid_transaction.dart';
import 'package:bb_mobile/features/get_paid/domain/list_get_paid_transactions_usecase.dart';
import 'package:bb_mobile/features/invoices/domain/entities/private_invoice_presentation.dart';
import 'package:bb_mobile/features/invoices/public/invoices_facade.dart';
import 'package:bb_mobile/features/lightning_address/public/lightning_address_facade.dart';
import 'package:bb_mobile/features/payment_page/public/payment_page_facade.dart';
import 'package:bb_mobile/features/pos/public/pos_facade.dart';
import 'package:bb_mobile/features/test_wallet_backup/domain/usecases/get_mnemonic_from_fingerprint_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'support/fiat_witness_support.dart';

// SPEC-FIAT-WITNESS - the FUNDED fiat-settlement witness. It is the client-side
// driver for the settlement-visibility phases of the full integration
// certification: it registers a fresh identity, creates a Get Paid product,
// configures fiat settlement, publishes the pay target to the coordinator, and
// then OBSERVES the REAL Bullnym history projection until settled fiat data
// renders. This is the first-ever rendering of real settled fiat data on the
// merchant surface.
//
// It NEVER pays and NEVER sends. Paying a tiny real amount is done externally by
// the guarded payer under the coordinator (which reads ready.json and pays the
// published target). The spec only drives the app side and reads history. It
// must pass no-payment-guard.sh (no send/broadcast/pay surfaces).
//
// Driven by dart-defines (set by the getpaid-e2e fiat-witness lane):
//   FIAT_WITNESS_PRODUCT   payment_page | pos | lightning_address | invoice
//   FIAT_WITNESS_MODE      fiat100 | mixed50 | below_min
//   FIAT_WITNESS_RUN_ID    run identity (fresh nym `fw<runId>`)
//   FIAT_WITNESS_HANDSHAKE_DIR  file handshake dir (must exist)
//   FIAT_WITNESS_AMOUNT_SAT     invoice / hint amount for the payer
//   BULLNYM_BASE_URL            staging Bullnym base (consumed by app config)
//   FIAT_STAGING_SCOPED_KEY_FILE  mode-600 real key handoff (synthetic-eligible
//                                 fallback only when the provider is the fixture)
// With none set, the single test self-skips (the spec still compiles).

Future<void> main({bool isInitialized = false}) async {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  if (!isInitialized) await Bull.init();

  final skip = FiatWitnessConfig.skipReason();

  test(
    'funded fiat witness: real settlement visibility on the Get Paid history '
    'projection, driven per FIAT_WITNESS_PRODUCT / FIAT_WITNESS_MODE',
    () async {
      final config = FiatWitnessConfig.fromEnvironment();
      witnessCheckpoint('env_check', data: {
        'run_id': config.runId,
        'nym': config.nym,
        'product': config.product.wireId,
        'mode': config.mode.wireId,
        'handshake_dir': config.handshakeDir.path,
        'amount_sat': config.amountSat,
      });

      final environment =
          (await locator<GetSettingsUsecase>().execute()).environment;
      final network =
          environment.isMainnet ? 'liquid-mainnet' : 'liquid-testnet';

      // (1) Create the witness wallet on-device (fresh seed the app owns), then
      // CAPTURE its recovery material to a durable mode-0600 file BEFORE any
      // funds can arrive. Only the capture PATH + fingerprint are checkpointed.
      await locator<CreateDefaultWalletsUsecase>().execute();
      final defaultLiquid = await _defaultLiquidWallet(environment);
      final fingerprint = defaultLiquid.masterFingerprint;
      if (fingerprint.isEmpty) {
        fail('app-created wallet has no master fingerprint to capture');
      }
      final (mnemonicWords, passphrase) =
          await locator<GetMnemonicFromFingerprintUsecase>().execute(
        fingerprint,
      );
      final seedPath = await config.writeSeedCapture({
        'schema': 'fiat-witness-seed-capture/v1',
        'run_id': config.runId,
        'network': network,
        'master_fingerprint': fingerprint,
        'mnemonic_words': mnemonicWords,
        if (passphrase != null && passphrase.isNotEmpty) 'passphrase': passphrase,
        'captured_at': DateTime.now().toUtc().toIso8601String(),
      });
      witnessCheckpoint('seed_captured', data: {
        // Path + fingerprint only. The words live solely in the 0600 file.
        'seed_capture_file': seedPath,
        'master_fingerprint': fingerprint,
      });

      // (2) Register a fresh wallet-owned nym so the deployed identity gate
      // admits the fiat calls, then create the specific product and derive its
      // pay target.
      final registration = await locator<LightningAddressFacade>()
          .registerWalletOwned(nym: config.nym);
      final registeredNym = registration.registration.nym;
      witnessCheckpoint('nym_registered', data: {'nym': registeredNym});

      final payTarget = await _createProductAndResolveTarget(config);
      witnessCheckpoint('product_created', data: {
        'pay_target_kind': payTarget.kind,
      });

      // (3) Store the scoped key (real handoff preferred; synthetic-eligible
      // only when the provider is the fixture) and set fiat settlement per mode.
      final scopedKey = config.capturedScopedKey() ?? syntheticEligibleScopedKey;
      await locator<BullbitcoinApiKeyDatasource>().storeSellToFiatBalanceApiKey(
        ScopedApiKeyModel(userId: 'fiat-witness-user', key: scopedKey),
        isTestnet: environment.isTestnet,
      );
      final settlementProduct = _settlementProductFor(config.product);
      final setResult = await locator<FiatSettlementFacade>().set(
        product: settlementProduct,
        fiatPercentage: config.mode.fiatPercentage,
        currency: FiatCurrency.cad,
      );
      final configView = switch (setResult) {
        Ok(:final value) => value,
        Err(:final failure) =>
          fail('fiat settlement enable failed: $failure'),
      };
      final saved = configView.configFor(settlementProduct);
      expect(saved.fiatPercentage, config.mode.fiatPercentage);
      expect(saved.currency, FiatCurrency.cad);
      // ALWAYS: the config view never echoes the scoped key.
      expect(textLeaksScopedKey(configView.toString()), isFalse);
      witnessCheckpoint('fiat_configured', data: {
        'fiat_percentage': saved.fiatPercentage,
        'currency': FiatCurrency.cad.code,
      });

      // (4) Publish the pay target + run params for the coordinator, then wait
      // for the guarded payer to pay it.
      final readyAt = DateTime.now().toUtc();
      await config.writeJsonAtomic(config.readyFile, {
        'schema': 'fiat-witness-ready/v1',
        'run_id': config.runId,
        'nym': registeredNym,
        'product': config.product.wireId,
        'mode': config.mode.wireId,
        'network': network,
        'amount_sat': config.amountSat,
        'pay_target': payTarget.toJson(),
        'written_at': readyAt.toIso8601String(),
      });
      witnessCheckpoint('ready_published', data: {
        'ready_file': config.readyFile.path,
      });

      // Baseline the app's Liquid wallet balances (mixed mode observes a
      // product-wallet credit landing somewhere in the app's own wallets).
      final baselineBalances = await _liquidBalances(environment);

      // (5) Poll the REAL history pipeline until a matching transaction with a
      // server settlement classification appears.
      final firstTx = await _pollForSettledTransaction(
        config: config,
        expectedSource: _transactionSourceFor(config.product),
      );
      final firstSettlement = firstTx.settlement;
      if (firstSettlement == null) {
        fail('witnessed transaction carried no settlement classification');
      }
      witnessCheckpoint('transaction_observed', data: {
        'transaction_id': firstTx.transactionId,
        'settlement_kind': firstSettlement.kind.name,
      });

      // ALWAYS: an unavailable classification is never rendered as Bitcoin.
      _assertUnavailableNeverBitcoin(firstTx);

      final result = <String, Object?>{
        'schema': 'fiat-witness-result/v1',
        'run_id': config.runId,
        'nym': registeredNym,
        'product': config.product.wireId,
        'mode': config.mode.wireId,
        'network': network,
        'transaction_id': firstTx.transactionId,
        'first_settlement_kind': firstSettlement.kind.name,
        'ready_at': readyAt.toIso8601String(),
        'first_tx_at': DateTime.now().toUtc().toIso8601String(),
      };

      switch (config.mode) {
        case FiatWitnessMode.belowMin:
          // Below-minimum override: the tiny amount forces the server to settle
          // in Bitcoin and mark the conversion overridden(belowMinimum).
          expect(firstSettlement.kind, GetPaidSettlementKind.bitcoin);
          expect(
            firstSettlement.overrideReason,
            GetPaidFiatOverrideReason.belowMinimum,
          );
          result['override_reason'] = firstSettlement.overrideReason?.name;
          result['status'] = 'pass';
          witnessCheckpoint('below_min_asserted', status: 'ok', data: {
            'override_reason': firstSettlement.overrideReason?.name,
          });

        case FiatWitnessMode.fiat100:
          // Fiat-only: a fiat leg in CAD with a non-empty order id, pending at
          // first (amountMinor null), settling to amountMinor > 0.
          expect(firstSettlement.kind, GetPaidSettlementKind.fiat);
          final firstLeg = _firstFiatLeg(firstSettlement);
          expect(firstLeg.currency, FiatCurrency.cad.code);
          expect(firstLeg.orderId.trim(), isNotEmpty);
          result['fiat_order_id_redacted'] = redactOrderId(firstLeg.orderId);
          result['first_leg_status'] = firstLeg.status.name;
          result['first_leg_amount_minor'] = firstLeg.amountMinor;
          await _settleAndRecord(config, firstTx, result);

        case FiatWitnessMode.mixed50:
          // Mixed: BOTH a Bitcoin leg (amountSat > 0) and a fiat leg.
          expect(firstSettlement.kind, GetPaidSettlementKind.mixed);
          expect(firstSettlement.bitcoin, isNotEmpty);
          expect(firstSettlement.bitcoin.first.amountSat, greaterThan(0));
          final firstLeg = _firstFiatLeg(firstSettlement);
          expect(firstLeg.currency, FiatCurrency.cad.code);
          expect(firstLeg.orderId.trim(), isNotEmpty);
          result['bitcoin_leg_amount_sat'] =
              firstSettlement.bitcoin.first.amountSat;
          result['fiat_order_id_redacted'] = redactOrderId(firstLeg.orderId);
          // Best-effort: observe the Bitcoin-leg credit landing in an app
          // wallet. The payment already happened (the mixed row is visible), so
          // the credit lands about now; bound this short so it cannot eat into
          // the pending->settled poll below and overrun the test timeout.
          final credit = await _pollForBalanceCredit(
            environment: environment,
            baseline: baselineBalances,
            timeout: const Duration(minutes: 3),
            interval: config.pollInterval,
          );
          if (credit != null) {
            result['credited_wallet_id'] = credit.walletId;
            result['credited_delta_sat'] = credit.deltaSat.toString();
          } else {
            result['credited_wallet_id'] = null;
          }
          await _settleAndRecord(config, firstTx, result);
      }

      // ALWAYS: nothing observed leaks the scoped key.
      expect(textLeaksScopedKey(firstSettlement.toString()), isFalse);

      await config.writeJsonAtomic(config.resultFile, {
        ...result,
        'written_at': DateTime.now().toUtc().toIso8601String(),
      });
      witnessCheckpoint('result_written', status: '${result['status']}', data: {
        'result_file': config.resultFile.path,
      });

      // A PENDING-ONLY fiat outcome is a reported result, not a hard failure.
      final status = result['status'];
      expect(
        status,
        anyOf('pass', 'pending_only'),
        reason: 'witness ended in an unexpected state: $status',
      );
    },
    timeout: const Timeout(Duration(minutes: 35)),
    skip: skip,
  );
}

// ===== product creation + pay target =======================================

class _PayTarget {
  final String kind;
  final String value;
  final String? invoiceId;

  const _PayTarget({required this.kind, required this.value, this.invoiceId});

  Map<String, Object?> toJson() => {
    'kind': kind,
    'value': value,
    if (invoiceId != null) 'invoice_id': invoiceId,
  };
}

Future<_PayTarget> _createProductAndResolveTarget(
  FiatWitnessConfig config,
) async {
  switch (config.product) {
    case FiatWitnessProduct.lightningAddress:
      // The registration already provisioned the Lightning Address; re-read it
      // to publish the canonical address string.
      final status =
          await locator<LightningAddressFacade>().lookupWalletOwnedRegistration();
      final address = status.lightningAddress;
      if (address == null || address.isEmpty) {
        fail('Lightning Address registration returned no address');
      }
      return _PayTarget(kind: 'lightning_address', value: address);

    case FiatWitnessProduct.paymentPage:
      final page = await locator<PaymentPageFacade>().save(
        SavePaymentPageCommand(
          header: 'Fiat witness ${config.runId}',
          description: 'Authorized funded settlement-visibility witness',
          displayCurrency: 'CAD',
          website: 'https://bullbitcoin.com',
        ),
      );
      expect(page.isActive, isTrue);
      expect(page.publicUrl, isNotEmpty);
      return _PayTarget(kind: 'payment_page_url', value: page.publicUrl);

    case FiatWitnessProduct.pos:
      final terminal = await locator<PosFacade>().provision(
        PosProvisionCommand(
          label: 'Fiat witness ${config.runId}',
          displayCurrency: 'CAD',
        ),
      );
      expect(terminal.isActive, isTrue);
      expect(terminal.terminalUrl, isNotEmpty);
      return _PayTarget(kind: 'pos_url', value: terminal.terminalUrl);

    case FiatWitnessProduct.invoice:
      final created = await locator<InvoicesFacade>().create(
        CreateInvoiceCommand(
          amountSat: config.amountSat,
          presentation: PrivateInvoicePresentation(),
          acceptBtc: false,
          acceptLn: true,
          acceptLiquid: true,
        ),
      );
      final invoice = switch (created) {
        Ok(:final value) => value,
        Err(:final failure) => fail('invoice create failed: $failure'),
      };
      return _PayTarget(
        kind: 'invoice_url',
        value: invoice.privateLink.value,
        invoiceId: invoice.invoiceId.value,
      );
  }
}

FiatSettlementProduct _settlementProductFor(FiatWitnessProduct product) =>
    switch (product) {
      FiatWitnessProduct.lightningAddress =>
        FiatSettlementProduct.lightningAddress,
      FiatWitnessProduct.paymentPage => FiatSettlementProduct.paymentPage,
      FiatWitnessProduct.pos => FiatSettlementProduct.pos,
      FiatWitnessProduct.invoice => FiatSettlementProduct.invoice,
    };

GetPaidTransactionSource _transactionSourceFor(FiatWitnessProduct product) =>
    switch (product) {
      FiatWitnessProduct.lightningAddress =>
        GetPaidTransactionSource.lightningAddress,
      FiatWitnessProduct.paymentPage => GetPaidTransactionSource.paymentPage,
      FiatWitnessProduct.pos => GetPaidTransactionSource.pointOfSale,
      FiatWitnessProduct.invoice => GetPaidTransactionSource.invoice,
    };

// ===== history observation ==================================================

Future<GetPaidTransaction> _pollForSettledTransaction({
  required FiatWitnessConfig config,
  required GetPaidTransactionSource expectedSource,
}) async {
  final deadline = DateTime.now().add(config.pollTimeout);
  var attempt = 0;
  while (true) {
    attempt++;
    final tx = await _fetchTargetTransaction(expectedSource);
    if (tx != null && tx.settlement != null) return tx;
    if (DateTime.now().isAfter(deadline)) {
      witnessCheckpoint('await_transaction', status: 'timeout', data: {
        'attempts': attempt,
        'source': expectedSource.name,
      });
      throw StateError(
        'no classified $expectedSource transaction within '
        '${config.pollTimeout.inSeconds}s',
      );
    }
    witnessCheckpoint('await_transaction', status: 'waiting', data: {
      'attempt': attempt,
      'found_unclassified': tx != null,
    });
    await Future<void>.delayed(config.pollInterval);
  }
}

/// The newest transaction matching [source], or null when none is present yet.
Future<GetPaidTransaction?> _fetchTargetTransaction(
  GetPaidTransactionSource source,
) async {
  final result =
      await locator<ListGetPaidTransactionsUsecase>().execute(cursor: '', limit: 50);
  final page = switch (result) {
    Ok(:final value) => value,
    Err(:final failure) => throw StateError('history read failed: $failure'),
  };
  GetPaidTransaction? newest;
  for (final tx in page.transactions) {
    if (tx.source != source) continue;
    if (newest == null || tx.receivedAt.isAfter(newest.receivedAt)) {
      newest = tx;
    }
  }
  return newest;
}

/// Polls the SAME history pipeline (W3: pending -> settled) until the fiat leg
/// reports settled with amountMinor > 0. Records the final state in [result];
/// a settle timeout is recorded as PENDING-ONLY, not a hard failure.
Future<void> _settleAndRecord(
  FiatWitnessConfig config,
  GetPaidTransaction firstTx,
  Map<String, Object?> result,
) async {
  final deadline = DateTime.now().add(config.settleTimeout);
  var attempt = 0;
  final source = firstTx.source;
  while (true) {
    attempt++;
    final tx = await _fetchTargetTransaction(source);
    final leg = tx?.settlement == null ? null : _firstFiatLegOrNull(tx!.settlement!);
    if (leg != null &&
        leg.status == GetPaidSettlementLegStatus.settled &&
        (leg.amountMinor ?? 0) > 0) {
      result['final_leg_status'] = leg.status.name;
      result['final_leg_amount_minor'] = leg.amountMinor;
      result['settled_at'] = DateTime.now().toUtc().toIso8601String();
      result['status'] = 'pass';
      witnessCheckpoint('fiat_settled', status: 'ok', data: {
        'amount_minor': leg.amountMinor,
        'attempts': attempt,
      });
      return;
    }
    if (DateTime.now().isAfter(deadline)) {
      result['final_leg_status'] = leg?.status.name;
      result['final_leg_amount_minor'] = leg?.amountMinor;
      result['status'] = 'pending_only';
      witnessCheckpoint('fiat_settled', status: 'pending_only', data: {
        'attempts': attempt,
        'last_leg_status': leg?.status.name,
      });
      return;
    }
    witnessCheckpoint('await_settled', status: 'waiting', data: {
      'attempt': attempt,
      'last_leg_status': leg?.status.name,
    });
    await Future<void>.delayed(config.pollInterval);
  }
}

GetPaidFiatSettlementLeg _firstFiatLeg(GetPaidSettlement settlement) {
  final leg = _firstFiatLegOrNull(settlement);
  if (leg == null) {
    fail('settlement carried no fiat leg (kind ${settlement.kind.name})');
  }
  return leg;
}

GetPaidFiatSettlementLeg? _firstFiatLegOrNull(GetPaidSettlement settlement) =>
    settlement.fiat.isEmpty ? null : settlement.fiat.first;

void _assertUnavailableNeverBitcoin(GetPaidTransaction tx) {
  final settlement = tx.settlement;
  if (settlement == null) return;
  if (settlement.kind == GetPaidSettlementKind.unavailable) {
    // An unavailable classification must never be dressed up as a Bitcoin leg.
    expect(settlement.bitcoin, isEmpty);
  }
}

// ===== wallet balance observation (mixed mode, best-effort) =================

class _BalanceCredit {
  final String walletId;
  final BigInt deltaSat;

  const _BalanceCredit({required this.walletId, required this.deltaSat});
}

Future<Map<String, BigInt>> _liquidBalances(Environment environment) async {
  final wallets = await locator<WalletRepository>().getWallets(
    environment: environment,
    onlyLiquid: true,
    sync: true,
  );
  return {for (final w in wallets) w.id: w.balanceSat};
}

Future<_BalanceCredit?> _pollForBalanceCredit({
  required Environment environment,
  required Map<String, BigInt> baseline,
  required Duration timeout,
  required Duration interval,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (true) {
    final current = await _liquidBalances(environment);
    for (final entry in current.entries) {
      final before = baseline[entry.key] ?? BigInt.zero;
      if (entry.value > before) {
        return _BalanceCredit(
          walletId: entry.key,
          deltaSat: entry.value - before,
        );
      }
    }
    if (DateTime.now().isAfter(deadline)) return null;
    await Future<void>.delayed(interval);
  }
}

Future<Wallet> _defaultLiquidWallet(Environment environment) async {
  final wallets = await locator<WalletRepository>().getWallets(
    environment: environment,
    onlyDefaults: true,
    onlyLiquid: true,
  );
  if (wallets.isEmpty) {
    throw StateError('no default Liquid wallet after create');
  }
  return wallets.first;
}
