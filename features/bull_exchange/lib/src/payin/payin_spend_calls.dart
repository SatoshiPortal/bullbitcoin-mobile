import 'dart:async';

import 'package:bull_exchange/src/exchange_answers.dart';
import 'package:bull_exchange/src/payin/payin_runner.dart';
import 'package:bull_exchange/src/payin/payin_spend_answers.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:bull_payjoin/bull_payjoin.dart';
import 'package:clock/clock.dart';
import 'package:exchange/exchange.dart';
import 'package:exchange/steps.dart';
import 'package:fees/fees.dart';
import 'package:labels/labels.dart';
import 'package:primitives/primitives.dart';
import 'package:spend/payjoin.dart';
import 'package:spend/spend.dart';
import 'package:secrets/secrets.dart';
import 'package:spend/fee_preview.dart';
import 'package:sync/sync.dart'
    show BitcoinTx, Coin, WalletKey, decodeLiquidPset;
import 'package:sync/write.dart' show WalletNativeRuntime;

import 'spend_options.dart';
import 'spend_options_runner.dart';

/// The wallet side of a sell or pay payin. [coins] lists a wallet's coins
/// (null when it can't).
typedef PayinWalletServices = ({
  Spend spend,
  Fees fees,
  PayjoinPolicyAccess payjoinPolicy,
  PayjoinSender payjoinSender,
  PayjoinSessions payjoinSessions,
  Labels labels,
  Future<List<Coin>?> Function(String walletId) coins,
});

/// A wallet's coins read through the inventory: only a wallet this device
/// signs for, null when it can't be read.
Future<List<Coin>?> Function(String walletId) walletCoinsOf(
  WalletInventory inventory,
  WalletNativeRuntime native,
) => (walletId) async {
  switch (await inventory.readWallet(walletId)) {
    case Ok(
      value: WalletRegistration(
        :final id,
        :final network,
        signer: WalletSigner.local,
      ),
    ):
      switch (await native.wallet(WalletKey(id: id, network: network))) {
        case Ok(:final value):
          return switch (await value.unspent()) {
            Ok(:final value) => value.toList(),
            Err() => null,
          };
        case Err():
          return null;
      }
    case Ok() || Err():
      return null;
  }
};

/// The spend options' calls of [session] over the wallet [services]: the
/// fee estimates of the session's network, the coins and unsigned previews
/// of the payin to the quoted deposit.
SpendOptionsCalls spendOptionsCallsOf(
  ExchangeSession session,
  PayinWalletServices services,
) {
  final bitcoin = session.environment == ExchangeEnvironment.testnet
      ? BitcoinNetwork.testnet
      : BitcoinNetwork.mainnet;
  final previews = SpendFeePreview();
  List<BitcoinTransactionRecipient> recipients(SpendPreviewShape shape) => [
    BitcoinTransactionRecipient.fixed(
      address: shape.target.address,
      amountSat: Sats.fromInt(shape.target.amountSat),
    ),
  ];
  return (
    fees: () async => switch (await services.fees.estimate(bitcoin)) {
      Ok(:final value) => value,
      Err() => null,
    },
    coins: services.coins,
    presets: (shape, fees) async {
      switch (await services.spend.previewBitcoinFeePresets(
        walletId: shape.walletId,
        recipients: recipients(shape),
        presets: fees,
        replaceByFee: shape.replaceByFee,
        selectedInputs: shape.coins,
      )) {
        case Ok(:final value):
          return {
            for (final MapEntry(key: selection, value: preview)
                in value.entries)
              selection: previews.project(preview),
          };
        case Err():
          return const {};
      }
    },
    custom: (shape, fee) async {
      switch (await services.spend.previewBitcoinFee(
        walletId: shape.walletId,
        recipients: recipients(shape),
        networkFee: fee,
        replaceByFee: shape.replaceByFee,
        selectedInputs: shape.coins,
      )) {
        case Ok(:final value):
          return previews.project(value);
        case Err():
          return const BitcoinFeePreviewSlot();
      }
    },
  );
}

/// Liquid's network minimum relay fee (0.1 sat/vByte = 25 sat/kwu).
const _liquidFeeRate = RelativeFee(25);

/// The payin calls of [session] over the wallet [services]. An on-chain
/// payin is built as its [PayinSpendOptions] say (the fee, replace-by-fee
/// and coins picked on the review); it goes through payjoin when the user
/// kept payjoin on, the order published a payjoin URI and enough of the
/// order's window is left for a negotiation to finish.
PayinCalls payinCallsOf(
  Exchange exchange,
  ExchangeSession session,
  PayinWalletServices services,
) {
  final testnet = session.environment == ExchangeEnvironment.testnet;
  final bitcoin = testnet ? BitcoinNetwork.testnet : BitcoinNetwork.mainnet;
  final orders = exchange.orders(session.environment);

  Future<void> label(String txid, String walletId) async {
    try {
      await services.labels.store(
        NewLabel.tx(
          transactionId: txid,
          label: LabelSystem.exchangeSell.label,
          origin: walletId,
        ),
      );
    } on Object {
      log.warning('Could not label the exchange payin');
    }
  }

  Future<PayinBuildResult<PayinSpend>> buildBitcoin(
    PayinBuild<PayinSpend> effect,
    String address,
    int amountSat,
  ) async {
    final options = effect.spend.options;
    final fee = networkFeeOf(options.fee);
    final PreparedBitcoinSpend prepared;
    switch (await services.spend.prepareBitcoin(
      walletId: effect.walletId,
      recipients: [
        BitcoinTransactionRecipient.fixed(
          address: address,
          amountSat: Sats.fromInt(amountSat),
        ),
      ],
      networkFee: fee,
      selectedInputs: options.coins.isEmpty ? null : options.coins,
      replaceByFee: options.replaceByFee,
    )) {
      case Ok(:final value):
        prepared = value;
      case Err(:final failure):
        return PayinBuildFailed(payinBuildProblemOf(failure));
    }
    final bip21 = effect.order.payjoinBip21;
    final deadline = effect.order.confirmationDeadline;
    final window = bip21 == null || deadline == null
        ? null
        : PayjoinSessionWindow.forOrderDeadline(deadline, now: clock.now());
    if (bip21 != null && window != null && options.payjoin) {
      final String txid;
      try {
        txid = (await BitcoinTx.fromPsbt(prepared.unsignedPsbt)).txid;
      } on Object {
        return const PayinBuildFailed(PayinBuildProblem.unexpected);
      }
      return PayinBuildOk(
        PayinBuilt(
          effect.spend,
          txid,
          PayjoinPayin<PreparedBitcoinSpend>(
            prepared: prepared,
            bip21: bip21,
            amountSat: amountSat,
            feeRateSatPerVb: fee.isRelative
                ? fee.value.toDouble()
                : prepared.fee.value.toInt() / prepared.txSize,
            expiresAt: clock.now().add(window),
          ),
        ),
      );
    }
    switch (await services.spend.signBitcoin(prepared: prepared)) {
      case Ok(value: final signed):
        final txid = await _txidOfSigned(signed);
        if (txid == null) {
          return const PayinBuildFailed(PayinBuildProblem.unexpected);
        }
        return PayinBuildOk(
          PayinBuilt(
            effect.spend,
            txid,
            SignedBitcoinPayin<SignedBitcoinSpend>(signed),
          ),
        );
      case Err(:final failure):
        return PayinBuildFailed(payinBuildProblemOf(failure));
    }
  }

  Future<PayinBuildResult<PayinSpend>> buildLiquid(
    PayinBuild<PayinSpend> effect,
    String address,
    int amountSat,
  ) async {
    final PreparedLiquidSpend prepared;
    switch (await services.spend.prepareLiquid(
      walletId: effect.walletId,
      address: address,
      feeRate: _liquidFeeRate,
      amountSat: amountSat,
    )) {
      case Ok(:final value):
        prepared = value;
      case Err(:final failure):
        return PayinBuildFailed(payinBuildProblemOf(failure));
    }
    switch (await services.spend.signLiquid(prepared: prepared)) {
      case Ok(value: final signed):
        return switch (decodeLiquidPset(signed.signedPset)) {
          Ok(value: final decoded) => PayinBuildOk(
            PayinBuilt(
              effect.spend,
              decoded.txid,
              SignedLiquidPayin<SignedLiquidSpend>(signed),
            ),
          ),
          Err() => const PayinBuildFailed(PayinBuildProblem.unexpected),
        };
      case Err(:final failure):
        return PayinBuildFailed(payinBuildProblemOf(failure));
    }
  }

  Future<PayinBroadcastOutcome> sendPayjoin(
    PayinBuilt<PayinSpend> built,
    PayjoinPayin<PreparedBitcoinSpend> payin,
  ) async {
    final PreparedPayjoinOriginal original;
    switch (await preparePayjoinOriginal(
      spend: services.spend,
      prepared: payin.prepared,
      walletId: built.walletId,
      network: bitcoin,
    )) {
      case Ok(:final value):
        original = value;
      case Err(failure: SpendUnavailableFailure()):
        return const PayinBroadcastNotSent(PayinNotSentReason.walletBusy);
      case Err():
        return const PayinBroadcastRefused(PayinRefusal.payjoinNotStarted);
    }
    switch (await services.payjoinSender.start(
      StartPayjoinSender(
        walletId: built.walletId,
        network: bitcoin,
        bip21Uri: payin.bip21,
        unsignedOriginalPsbt: payin.prepared.unsignedPsbt,
        preparedOriginal: original,
        amount: Sats.fromInt(payin.amountSat),
        feeRate: FeeRate(payin.feeRateSatPerVb),
        expiresAt: payin.expiresAt,
      ),
    )) {
      case Ok(value: final sender):
        unawaited(label(sender.originalTxId, built.walletId));
        return PayinHandedToPayjoin(sender.id, sender.originalTxId);
      case Err(failure: PayjoinSpendBlockedFailure()):
        return const PayinBroadcastNotSent(PayinNotSentReason.walletBusy);
      case Err(failure: PayjoinPublicationUnknownFailure(:final originalTxId)):
        return PayinBroadcastOutcomeUnknown(originalTxId);
      case Err(:final failure):
        // The engine persists the session before posting it: a stored,
        // ongoing session of this wallet and amount is this payin in flight.
        switch (await services.payjoinSessions.byTransactionId(built.txid)) {
          case Ok(:final value):
            for (final kept in value) {
              if (kept is PayjoinSenderSession &&
                  kept.isOngoing &&
                  kept.walletId == built.walletId &&
                  kept.amountSat == payin.amountSat) {
                return PayinHandedToPayjoin(kept.id, kept.originalTxId);
              }
            }
            return failure is PayjoinSenderKeptFailure
                ? PayinBroadcastOutcomeUnknown(built.txid)
                : const PayinBroadcastRefused(PayinRefusal.payjoinNotStarted);
          case Err():
            return PayinBroadcastOutcomeUnknown(built.txid);
        }
    }
  }

  return (
    build: (effect) async {
      // The legacy Spend calls resolve internally by ID. This includes the
      // preparation used for signing and for the original Payjoin spend.
      if (effect.spend.walletAttempt != null) {
        return const PayinBuildFailed(PayinBuildProblem.notAuthorized);
      }
      final amountSat = (effect.order.payinAmount * 100000000).round();
      return switch (effect.target) {
        OnchainDeposit(:final address) => buildBitcoin(
          effect,
          address,
          amountSat,
        ),
        LiquidDeposit(:final address) => buildLiquid(
          effect,
          address,
          amountSat,
        ),
        // No app wallet pays a Lightning invoice (BitcoinRail.canBeAppWallet).
        LightningInvoiceDeposit() => const PayinBuildFailed(
          PayinBuildProblem.invalid,
        ),
      };
    },
    send: (built) async {
      if (built.spend.walletAttempt != null) {
        return const PayinBroadcastNotSent(PayinNotSentReason.walletBusy);
      }
      final payload = built.payload;
      final PayinBroadcastOutcome outcome = switch (payload) {
        SignedBitcoinPayin(signed: final SignedBitcoinSpend signed) =>
          payinBroadcastOf(
            await services.spend.broadcastBitcoin(signed),
            txid: built.txid,
          ),
        SignedLiquidPayin(signed: final SignedLiquidSpend signed) =>
          payinBroadcastOf(
            await services.spend.broadcastLiquid(signed),
            txid: built.txid,
          ),
        final PayjoinPayin<PreparedBitcoinSpend> payin => await sendPayjoin(
          built,
          payin,
        ),
        SignedBitcoinPayin() || SignedLiquidPayin() || PayjoinPayin() =>
          const PayinBroadcastRefused(PayinRefusal.nodeRejected),
      };
      if (outcome case PayinBroadcastAccepted(:final txid)) {
        unawaited(label(txid, built.walletId));
      }
      return outcome;
    },
    readOrder: (orderId) async => readOfResult(await orders.getOrder(orderId)),
    txSeen: (txid) async {
      switch (await services.payjoinSessions.byTransactionId(txid)) {
        case Ok(value: [final session, ...]):
          return switch (await services.payjoinSessions.visibleTransaction(
            session.id,
          )) {
            Ok(:final value) => value != null,
            Err() => null,
          };
        case Ok() || Err():
          return null;
      }
    },
    watchPayjoin: (sessionId) async* {
      switch (await services.payjoinSessions.byId(sessionId)) {
        case Ok(value: final session?):
          yield payjoinProgressOf(session);
          if (!session.isOngoing) return;
        case Ok():
          break;
        case Err():
          return;
      }
      await for (final result in services.payjoinSessions.watch(
        sessionIds: {sessionId},
      )) {
        switch (result) {
          case Ok(:final value):
            yield payjoinProgressOf(value);
          case Err():
            return;
        }
      }
    },
    retryPayjoin: (sessionId) async {
      if (await services.payjoinSender.retryProposal(sessionId) case Err()) {
        log.warning('Could not retry the payjoin proposal');
      }
    },
    journalUnknown: (orderId, network, txid) => exchange.journalUnknownPayin(
      session,
      orderId: orderId,
      network: network,
      txid: txid,
    ),
  );
}

/// The txid of the signed transaction itself (SELL-12: not the unsigned
/// PSBT's, which differs for inputs whose signature is in the scriptSig).
Future<String?> _txidOfSigned(SignedBitcoinSpend signed) async {
  final raw = signed.signedTransaction.trim();
  try {
    if (raw.startsWith('cHNid')) return (await BitcoinTx.fromPsbt(raw)).txid;
    return (await BitcoinTx.fromBytes(_hexBytes(raw))).txid;
  } on Object {
    return null;
  }
}

List<int> _hexBytes(String hex) => [
  for (var i = 0; i + 1 < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];

/// The wallet fee of a payin's chosen [fee].
NetworkFee networkFeeOf(PayinFee fee) => switch (fee) {
  PayinFeeRate(:final satPerKwu) => NetworkFee.relativeSatPerKwu(satPerKwu),
  PayinFeeAbsolute(:final sats) => NetworkFee.absolute(sats),
  PayinFeeNetworkMinimum() => NetworkFeeRelayPolicy.minRelay,
};

/// The payin fee of a wallet [fee].
PayinFee payinFeeOf(NetworkFee fee) => switch (fee) {
  RelativeFee(:final satPerKwu) => PayinFeeRate(satPerKwu),
  AbsoluteFee(:final sats) => PayinFeeAbsolute(sats),
};
