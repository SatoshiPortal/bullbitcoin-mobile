import 'package:primitives/primitives.dart' show BitcoinUnit;
import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;
import 'package:bb_mobile/features/send/domain/usecases/get_send_exchange_rate_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_policy.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_utxo.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/calculate_bitcoin_absolute_fees_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_usecase.dart';
import 'package:bb_mobile/core/wallet/domain/usecases/get_wallet_utxos_usecase.dart';
import 'package:bb_mobile/features/send/domain/pending_bitcoin_transaction.dart';
import 'package:bb_mobile/features/send/domain/bitcoin_recipient_list_policy.dart';
import 'package:bb_mobile/features/send/domain/send_failure.dart';
import 'package:bb_mobile/features/send/domain/usecases/detect_bitcoin_string_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_bitcoin_signing_plan_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/get_pending_bitcoin_transaction_usecase.dart';
import 'package:bb_mobile/features/send/domain/usecases/validate_pending_bitcoin_transaction_usecase.dart';
import 'package:meta/meta.dart';

final class RestoredPendingBitcoinTransaction {
  final PendingBitcoinTransaction transaction;
  final Wallet wallet;
  final List<PaymentRequest?> paymentRequests;
  final List<WalletUtxo> utxos;
  final List<WalletUtxo> selectedUtxos;
  final BitcoinSigningPlan? signingPlan;
  final BitcoinPolicyMaturity policyMaturity;
  final int? absoluteFeesSat;
  final String? fiatCurrencyCode;
  final double? exchangeRate;

  RestoredPendingBitcoinTransaction({
    required this.transaction,
    required this.wallet,
    required Iterable<PaymentRequest?> paymentRequests,
    required Iterable<WalletUtxo> utxos,
    required Iterable<WalletUtxo> selectedUtxos,
    this.signingPlan,
    this.policyMaturity = const BitcoinPolicyMaturity.empty(),
    this.absoluteFeesSat,
    this.fiatCurrencyCode,
    this.exchangeRate,
  }) : paymentRequests = List.unmodifiable(paymentRequests),
       utxos = List.unmodifiable(utxos),
       selectedUtxos = List.unmodifiable(selectedUtxos);

  PaymentRequest? get paymentRequest => paymentRequests.first;
}

class RestorePendingBitcoinTransactionUsecase {
  final GetPendingBitcoinTransactionUsecase
  _getPendingBitcoinTransactionUsecase;
  final GetWalletUsecase _getWalletUsecase;
  final GetWalletUtxosUsecase _getWalletUtxosUsecase;
  final DetectBitcoinStringUsecase _detectBitcoinStringUsecase;
  final ValidatePendingBitcoinTransactionUsecase
  _validatePendingBitcoinTransactionUsecase;
  final GetBitcoinSigningPlanUsecase _getBitcoinSigningPlanUsecase;
  final CalculateBitcoinAbsoluteFeesUsecase
  _calculateBitcoinAbsoluteFeesUsecase;
  final GetSendExchangeRateUsecase _getSendExchangeRateUsecase;

  const RestorePendingBitcoinTransactionUsecase(
    this._getPendingBitcoinTransactionUsecase,
    this._getWalletUsecase,
    this._getWalletUtxosUsecase,
    this._detectBitcoinStringUsecase,
    this._validatePendingBitcoinTransactionUsecase,
    this._getBitcoinSigningPlanUsecase,
    this._calculateBitcoinAbsoluteFeesUsecase,
    this._getSendExchangeRateUsecase,
  );

  @useResult
  Future<Result<RestoredPendingBitcoinTransaction, SendFailure>> execute(
    String id,
  ) async {
    final PendingBitcoinTransaction stored;
    switch (await _getPendingBitcoinTransactionUsecase.execute(id)) {
      case Ok(value: final value?):
        stored = value;
      case Ok(value: null):
        return const Err(SendStoredTransactionInvalidFailure());
      case Err(:final failure):
        return Err(failure);
    }

    try {
      final wallet = await _getWalletUsecase.execute(stored.walletId);
      if (wallet == null || !wallet.isBitcoin) {
        return const Err(SendStoredTransactionInvalidFailure());
      }
      final utxos = await _getWalletUtxosUsecase.execute(walletId: wallet.id);
      final selectedUtxos = utxos
          .where(
            (utxo) =>
                (!stored.isDraft || !utxo.isFrozen) &&
                stored.selectedOutpoints.contains('${utxo.txId}:${utxo.vout}'),
          )
          .toList(growable: false);
      final paymentRequests = [
        for (final recipient in stored.recipients)
          await _detectRecipient(recipient.recipient),
      ];
      final (fiatCurrencyCode, exchangeRate) = await _restoreFiatRate(
        stored.amountCurrencyCode,
      );
      if (stored.isDraft) {
        const recipientPolicy = BitcoinRecipientListPolicy();
        final primary = paymentRequests.first;
        final validPrimary =
            (primary is BitcoinPaymentRequest ||
                (primary is Bip21PaymentRequest &&
                    primary.network.isBitcoin)) &&
            recipientPolicy.networkIsTestnet(primary) == wallet.isTestnet &&
            (!stored.isSweep || recipientPolicy.supports(primary));
        return Ok(
          RestoredPendingBitcoinTransaction(
            transaction: stored,
            wallet: wallet,
            paymentRequests: [
              for (final (index, request) in paymentRequests.indexed)
                validPrimary &&
                        (index == 0 ||
                            (request != null &&
                                recipientPolicy.compatibleAdditionalAddress(
                                      request: request,
                                      primaryNetworkIsTestnet: wallet.isTestnet,
                                      isSweep: stored.isSweep,
                                    ) !=
                                    null))
                    ? request
                    : null,
            ],
            utxos: utxos,
            selectedUtxos: selectedUtxos,
            fiatCurrencyCode: fiatCurrencyCode,
            exchangeRate: exchangeRate,
          ),
        );
      }
      if (paymentRequests.any((request) => request == null)) {
        return const Err(SendStoredTransactionInvalidFailure());
      }

      final ValidatedPendingBitcoinTransaction validation;
      switch (await _validatePendingBitcoinTransactionUsecase.execute(stored)) {
        case Ok(:final value):
          validation = value;
        case Err(:final failure):
          return Err(failure);
      }
      final validated = validation.transaction;
      final BitcoinSigningPlanDetails signingPlanDetails;
      final details = validation.details == null
          ? await _getBitcoinSigningPlanUsecase.execute(
              wallet: wallet,
              psbt: validated.psbt,
              selection: validated.policySelection,
              allowSpentWalletInputs: true,
              allowFrozenWalletInputs: true,
            )
          : Ok<BitcoinSigningPlanDetails, SendFailure>(validation.details!);
      switch (details) {
        case Ok(:final value):
          signingPlanDetails = value;
        case Err(:final failure):
          return Err(
            failure is SendUnexpectedFailure
                ? failure
                : const SendStoredTransactionInvalidFailure(),
          );
      }
      final absoluteFeesSat = await _calculateBitcoinAbsoluteFeesUsecase
          .execute(psbt: validated.psbt!);
      return Ok(
        RestoredPendingBitcoinTransaction(
          transaction: validated,
          wallet: wallet,
          paymentRequests: paymentRequests,
          utxos: utxos,
          selectedUtxos: selectedUtxos,
          signingPlan: signingPlanDetails.plan,
          policyMaturity: signingPlanDetails.maturity,
          absoluteFeesSat: absoluteFeesSat,
          fiatCurrencyCode: fiatCurrencyCode,
          exchangeRate: exchangeRate,
        ),
      );
    } on Exception {
      return const Err(SendUnexpectedFailure());
    }
  }

  Future<PaymentRequest?> _detectRecipient(String recipient) async {
    if (recipient.isEmpty) return null;
    try {
      return await _detectBitcoinStringUsecase.execute(data: recipient);
    } on Exception {
      return null;
    } on String {
      return null;
    }
  }

  Future<(String?, double?)> _restoreFiatRate(String currencyCode) async {
    if (currencyCode.isEmpty ||
        currencyCode == BitcoinUnit.btc.code ||
        currencyCode == BitcoinUnit.sats.code) {
      return (null, null);
    }
    final exchangeRate = await _getSendExchangeRateUsecase.execute(
      currencyCode: currencyCode,
    );
    return (
      currencyCode,
      switch (exchangeRate) {
        Ok(:final value) => value,
        Err() => null,
      },
    );
  }
}
