import 'package:bb_mobile/core/swaps/data/repository/boltz_swap_repository.dart';
import 'package:bb_mobile/core/swaps/domain/entity/swap.dart';
import 'package:bull_swap/bull_swap.dart';
import 'package:primitives/primitives.dart';

class BoltzOrderSwapBridge {
  final SwapProviderResolver _resolver;
  final BoltzSwapRepository _boltz;
  final DateTime Function() _now;

  BoltzOrderSwapBridge(this._resolver, this._boltz, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  Future<OrderSwap?> createIfActive({
    required OrderSwapRecord record,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
    required String destinationAddress,
    required String? fallbackAddress,
  }) async {
    final active = await _resolver.resolveActive();
    if (active.config.kind != SwapProviderKind.boltz) return null;

    final environment = record.environment == OrderSwapEnvironment.testnet
        ? SwapEnvironment.testnet
        : SwapEnvironment.mainnet;
    final inNet = _toSwapNetwork(inNetwork);
    final outNet = _toSwapNetwork(outNetwork);

    final Result<CreatedSwap, SwapFailure> result;
    if (outNet == SwapNetwork.lightning) {
      result = await active.createLnSend(
        fromNetwork: inNet,
        invoice: destinationAddress,
        refundAddress: fallbackAddress ?? '',
        sourceWalletId: record.sourceWalletId,
        environment: environment,
      );
    } else if (inNet == SwapNetwork.lightning) {
      result = await active.createLnReceive(
        toNetwork: outNet,
        amountSat: amountSat,
        payoutAddress: destinationAddress,
        destinationWalletId: record.destinationWalletId,
        environment: environment,
      );
    } else {
      result = await active.createChainSwap(
        fromNetwork: inNet,
        toNetwork: outNet,
        amountSat: amountSat,
        isInAmountFixed: isInAmountFixed,
        payoutAddress: destinationAddress,
        refundAddress: fallbackAddress ?? '',
        sourceWalletId: record.sourceWalletId,
        destinationWalletId: record.destinationWalletId,
        environment: environment,
      );
    }

    final created = switch (result) {
      Ok(:final value) => value,
      // Surface the typed failure (not a stringly Exception) so the repository
      // maps the true network/validation cause instead of parking the order in
      // creationUnknown as a storage error.
      Err(:final failure) => throw failure,
    };
    return _toOrderSwap(created, inNetwork, outNetwork, amountSat);
  }

  Future<OrderSwapQuote?> quoteIfActive({
    required OrderSwapEnvironment environment,
    required BigInt amountSat,
    required bool isInAmountFixed,
    required OrderSwapNetwork inNetwork,
    required OrderSwapNetwork outNetwork,
  }) async {
    final active = await _resolver.resolveActive();
    if (active.config.kind != SwapProviderKind.boltz) return null;

    final env = environment == OrderSwapEnvironment.testnet
        ? SwapEnvironment.testnet
        : SwapEnvironment.mainnet;
    final result = await active.quote(
      inNetwork: _toSwapNetwork(inNetwork),
      outNetwork: _toSwapNetwork(outNetwork),
      amountSat: amountSat,
      isInAmountFixed: isInAmountFixed,
      environment: env,
    );
    final quote = switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    return _toOrderSwapQuote(quote, inNetwork, outNetwork);
  }

  Future<OrderSwap?> refreshIfBoltz(OrderSwapRecord record) async {
    final orderId = record.orderId;
    final previous = record.order;
    if (orderId == null || previous == null) return null;

    final Swap swap;
    try {
      swap = await _boltz.getSwap(swapId: orderId);
    } catch (_) {
      return null;
    }

    final environment = record.environment == OrderSwapEnvironment.testnet
        ? SwapEnvironment.testnet
        : SwapEnvironment.mainnet;
    if (swap.type.isSubmarine && swap.status == SwapStatus.canCoop) {
      await _tryCoopSign(swap);
    } else if (swap.status == SwapStatus.claimable) {
      await _tryClaim(orderId, environment);
    } else if (swap.status == SwapStatus.refundable) {
      await _tryRefund(orderId, environment);
    }
    return _withStatus(previous, swap.status);
  }

  Future<void> _tryRefund(String swapId, SwapEnvironment environment) async {
    final active = await _resolver.resolveActive();
    if (active is! ClaimRefundCapable) return;
    try {
      await (active as ClaimRefundCapable).refund(
        swapId,
        environment: environment,
      );
    } catch (_) {
      // Retried on the next refresh; a transient failure is not fatal.
    }
  }

  Future<void> _tryCoopSign(Swap swap) async {
    try {
      // Persist the send-swap preimage before cooperating: it is the
      // proof-of-payment for a completed send and must be stored even if the
      // coop close itself later fails.
      if (swap is LnSendSwap && swap.preimage == null) {
        final preimage = await _boltz.getSendSwapPreimage(swapId: swap.id);
        if (preimage != null) {
          await _boltz.updateSwapFields(swap.id, preimage: preimage);
        }
      }
      switch (swap.type) {
        case SwapType.bitcoinToLightning:
          await _boltz.coopSignBitcoinToLightningSwap(swapId: swap.id);
        case SwapType.liquidToLightning:
          await _boltz.coopSignLiquidToLightningSwap(swapId: swap.id);
        default:
          return;
      }
    } catch (_) {
      // Retried on the next refresh; a transient failure is not fatal.
    }
  }

  OrderSwapQuote _toOrderSwapQuote(
    SwapQuote quote,
    OrderSwapNetwork inNetwork,
    OrderSwapNetwork outNetwork,
  ) {
    final payin = quote.payinAmountSat;
    final feeBasisPoints = payin > BigInt.zero
        ? (quote.feesSat * BigInt.from(10000) ~/ payin).toInt()
        : 0;
    return OrderSwapQuote(
      inAmountSat: quote.payinAmountSat,
      outAmountSat: quote.payoutAmountSat,
      inNetwork: inNetwork,
      outNetwork: outNetwork,
      inCurrency: _currency(inNetwork),
      outCurrency: _currency(outNetwork),
      feeBasisPoints: feeBasisPoints,
      warnings: const [],
    );
  }

  Future<void> _tryClaim(String swapId, SwapEnvironment environment) async {
    final active = await _resolver.resolveActive();
    if (active is! ClaimRefundCapable) return;
    try {
      await (active as ClaimRefundCapable).claim(
        swapId,
        environment: environment,
      );
    } catch (_) {
      // Claim is retried on the next refresh; a transient failure is not fatal.
    }
  }

  OrderSwap _toOrderSwap(
    CreatedSwap created,
    OrderSwapNetwork inNetwork,
    OrderSwapNetwork outNetwork,
    BigInt requestedAmountSat,
  ) {
    final now = _now();
    final payin = created.payinAmountSat > BigInt.zero
        ? created.payinAmountSat
        : requestedAmountSat;
    final payout = created.payoutAmountSat > BigInt.zero
        ? created.payoutAmountSat
        : requestedAmountSat;
    final deadline =
        created.expiresAt != null && created.expiresAt!.isAfter(now)
        ? created.expiresAt!
        : now.add(const Duration(hours: 1));
    return OrderSwap(
      orderId: created.swapId,
      orderNumber: 0,
      inNetwork: inNetwork,
      outNetwork: outNetwork,
      payinAmountSat: payin,
      payoutAmountSat: payout,
      payinCurrency: _currency(inNetwork),
      payoutCurrency: _currency(outNetwork),
      payinMethod: _method(inNetwork),
      payoutMethod: _method(outNetwork),
      orderType: 'swap',
      orderStatus: 'pending',
      payinStatus: 'pending',
      payoutStatus: 'pending',
      messageCode: 'OK',
      bitcoinAddress: inNetwork == OrderSwapNetwork.bitcoin
          ? created.payinAddress
          : null,
      liquidAddress: inNetwork == OrderSwapNetwork.liquid
          ? created.payinAddress
          : null,
      lightningInvoice: created.payinInvoice,
      createdAt: now,
      confirmationDeadline: deadline,
    );
  }

  OrderSwap _withStatus(OrderSwap order, SwapStatus status) {
    final (orderStatus, payinStatus, payoutStatus) = switch (status) {
      SwapStatus.pending => ('pending', 'pending', 'pending'),
      SwapStatus.paid => ('pending', 'completed', 'pending'),
      SwapStatus.claimable ||
      SwapStatus.canCoop => ('pending', 'completed', 'pending'),
      SwapStatus.completed => ('completed', 'completed', 'completed'),
      SwapStatus.refunded => ('refunded', 'completed', 'refunded'),
      SwapStatus.expired => ('expired', 'pending', 'pending'),
      SwapStatus.refundable => ('failed', 'completed', 'failed'),
      SwapStatus.failed => ('failed', 'failed', 'failed'),
    };
    return OrderSwap(
      orderId: order.orderId,
      orderNumber: order.orderNumber,
      inNetwork: order.inNetwork,
      outNetwork: order.outNetwork,
      payinAmountSat: order.payinAmountSat,
      payoutAmountSat: order.payoutAmountSat,
      payinCurrency: order.payinCurrency,
      payoutCurrency: order.payoutCurrency,
      payinMethod: order.payinMethod,
      payoutMethod: order.payoutMethod,
      orderType: order.orderType,
      orderStatus: orderStatus,
      payinStatus: payinStatus,
      payoutStatus: payoutStatus,
      messageCode: order.messageCode,
      bitcoinAddress: order.bitcoinAddress,
      liquidAddress: order.liquidAddress,
      lightningInvoice: order.lightningInvoice,
      bitcoinTransactionId: order.bitcoinTransactionId,
      liquidTransactionId: order.liquidTransactionId,
      createdAt: order.createdAt,
      confirmationDeadline: order.confirmationDeadline,
      completedAt: order.completedAt,
      sentAt: order.sentAt,
    );
  }

  SwapNetwork _toSwapNetwork(OrderSwapNetwork network) => switch (network) {
    OrderSwapNetwork.bitcoin => SwapNetwork.bitcoin,
    OrderSwapNetwork.liquid => SwapNetwork.liquid,
    OrderSwapNetwork.lightning => SwapNetwork.lightning,
  };

  String _currency(OrderSwapNetwork network) => switch (network) {
    OrderSwapNetwork.bitcoin => 'BTC',
    OrderSwapNetwork.liquid => 'L-BTC',
    OrderSwapNetwork.lightning => 'LN-BTC',
  };

  String _method(OrderSwapNetwork network) =>
      network == OrderSwapNetwork.lightning ? 'lightning' : 'onchain';
}
