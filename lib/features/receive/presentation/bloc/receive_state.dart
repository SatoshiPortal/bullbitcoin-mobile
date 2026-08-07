part of 'receive_bloc.dart';

enum ReceiveType { bitcoin, lightning, liquid }

@freezed
abstract class ReceiveState with _$ReceiveState {
  const factory ReceiveState({
    ReceiveType? type,
    Wallet? wallet,
    @Default([]) List<Wallet> wallets,
    BitcoinUnit? bitcoinUnit,
    @Default([]) List<String> fiatCurrencyCodes,
    @Default('') String fiatCurrencyCode,
    @Default(0) double exchangeRate,
    @Default('') String inputAmountCurrencyCode,
    @Default('') String inputAmount,
    int? confirmedAmountSat,
    WalletAddress? bitcoinAddress,
    LnReceiveSwap? lightningSwap,
    SwapLimits? swapLimits,
    WalletAddress? liquidAddress,
    @Default('') String note,
    PayjoinReceiverSession? payjoin,
    // The global payjoin setting as last read by the bloc. Tri-state on
    // purpose: null = settings not fetched yet (treat as "may become
    // enabled", keep waiting), false = disabled (never wait for a payjoin),
    // true = enabled (wait until a session or an exception exists). See
    // [isPayjoinLoading] for why this must be part of the state.
    bool? payjoinGloballyEnabled,
    // The receiver's anti-probing minimum (sats) as last read from settings.
    // Null until the first settings fetch resolves. Used only to explain a
    // below-minimum decline on the payjoin-in-progress screen — the decline
    // itself happens in PayjoinRepositoryImpl before any negotiation.
    int? payjoinMinAmountSat,
    @Default(false) bool isBroadcastingOriginalTransaction,
    ReceivePayjoinException? receivePayjoinException,
    WalletTransaction? tx,
    Object? error,
    AmountException? amountException,
    @Default(false) bool creatingSwap,
  }) = _ReceiveState;
  const ReceiveState._();

  List<String> get inputAmountCurrencyCodes {
    return [BitcoinUnit.btc.code, BitcoinUnit.sats.code, ...fiatCurrencyCodes];
  }

  bool get swapLimitsFetched => swapLimits != null;
  bool get isInputAmountFiat => ![
    BitcoinUnit.btc.code,
    BitcoinUnit.sats.code,
  ].contains(inputAmountCurrencyCode);

  int get inputAmountSat {
    int amountSat = 0;

    if (inputAmount.isNotEmpty) {
      if (isInputAmountFiat) {
        final amountFiat = double.tryParse(inputAmount) ?? 0;
        amountSat = ConvertAmount.fiatToSats(amountFiat, exchangeRate);
      } else if (inputAmountCurrencyCode == BitcoinUnit.sats.code) {
        amountSat = int.tryParse(inputAmount) ?? 0;
      } else {
        final amountBtc = double.tryParse(inputAmount) ?? 0;
        amountSat = ConvertAmount.btcToSats(amountBtc);
      }
    }

    return amountSat;
  }

  double get inputAmountBtc => ConvertAmount.satsToBtc(inputAmountSat);

  double get inputAmountFiat {
    return ConvertAmount.btcToFiat(inputAmountBtc, exchangeRate);
  }

  // The QR code data should always show the full payment request when all parameters are available,
  //  this way the QR code doesn't change from an address only QR to a BIP21 uri with payjoin parameters while loading.
  String get qrData => paymentRequest;

  // The clipboard data should permit the user to copy just the address or invoice
  // from the moment it is available and not wait for the full payment request like payjoin
  // parameters. Once the full payment request is available, it should be copied instead of
  // just the address or invoice of course.
  String get clipboardData =>
      paymentRequest.isEmpty ? addressOrInvoiceOnly : paymentRequest;

  String get lightningInvoiceNormalized {
    final invoice = lightningSwap?.invoice;

    if (invoice == null) return '';

    return invoice.trim().toUpperCase();
  }

  // The payment request can be an address, invoice or bip21 URI depending on
  // the type of receive and some set parameters. It waits for all data to
  // be available before returning anything.
  String get paymentRequest {
    switch (type) {
      case ReceiveType.bitcoin:
        if (bitcoinAddress == null || isPayjoinLoading) {
          // Wait for the address and also for the payjoin in case not only the
          // address should be shown.
          return '';
        }
        if (confirmedAmountSat == null && note.isEmpty && !canPayjoin) {
          return bitcoinAddress!.address;
        }

        Uri bip21Uri = Uri(
          scheme: 'bitcoin',
          path: bitcoinAddress!.address,
          queryParameters: {
            if (confirmedAmountBtc > 0) 'amount': confirmedAmountBtc.toString(),
            if (note.isNotEmpty) 'message': note,
          },
        );

        // Add payjoin parameters if available
        if (canPayjoin) {
          final pjUri = Uri.parse(payjoin!.pjUri);
          final queryParameters = {
            if (bip21Uri.queryParameters.isNotEmpty)
              ...bip21Uri.queryParameters,
            if (pjUri.queryParameters['pjos'] != null)
              'pjos': pjUri.queryParameters['pjos'],
            'pj': pjUri.queryParameters['pj'],
          };
          bip21Uri = bip21Uri.replace(queryParameters: queryParameters);
        }
        return bip21Uri.toString();
      case ReceiveType.lightning:
        return lightningInvoiceNormalized;
      case ReceiveType.liquid:
        if (liquidAddress == null) return '';

        if (confirmedAmountSat == null && note.isEmpty) {
          return liquidAddress!.address;
        }
        final bip21Uri = Uri(
          scheme: 'liquidnetwork',
          path: liquidAddress!.address,
          queryParameters: {
            if (confirmedAmountBtc > 0) 'amount': confirmedAmountBtc.toString(),
            if (note.isNotEmpty) 'message': note,
            'assetid':
                wallet != null && wallet!.network == Network.liquidMainnet
                ? AssetConstants.lbtcMainnet
                : AssetConstants.lbtcTestnet,
          },
        );
        return bip21Uri.toString();
      case _:
        return '';
    }
  }

  String get addressOrInvoiceOnly {
    switch (type) {
      case ReceiveType.bitcoin:
        return bitcoinAddress?.address ?? '';
      case ReceiveType.lightning:
        return lightningInvoiceNormalized;
      case ReceiveType.liquid:
        return liquidAddress?.address ?? '';
      case _:
        return '';
    }
  }

  double get confirmedAmountBtc =>
      ConvertAmount.satsToBtc(confirmedAmountSat ?? 0);

  double get confirmedAmountFiat {
    return ConvertAmount.btcToFiat(confirmedAmountBtc, exchangeRate);
  }

  String get formattedConfirmedAmountFiat {
    return FormatAmount.fiat(confirmedAmountFiat, fiatCurrencyCode);
  }

  String get formattedAmountInputEquivalent {
    if (isInputAmountFiat) {
      // If the input is in fiat, the equivalent should be in bitcoin
      if (bitcoinUnit == null) {
        return '';
      } else if (bitcoinUnit == BitcoinUnit.sats) {
        return FormatAmount.sats(inputAmountSat);
      } else {
        return FormatAmount.btc(inputAmountBtc);
      }
    } else {
      return FormatAmount.fiat(inputAmountFiat, fiatCurrencyCode);
    }
  }

  bool get isBitcoin {
    switch (type) {
      case ReceiveType.bitcoin:
        return true;
      case ReceiveType.lightning:
        return lightningSwap != null &&
            lightningSwap!.type == SwapType.lightningToBitcoin;
      case ReceiveType.liquid:
        return false;
      case _:
        return false;
    }
  }

  bool get isPaymentInProgress {
    switch (type) {
      case ReceiveType.bitcoin:
        // From the moment the payjoin request is received, it can be broadcasted,
        // so we consider it in progress since it is a valid transaction from the sender
        // and the user can choose to broadcast it.
        return payjoin != null && payjoin!.status == PayjoinStatus.requested;
      case ReceiveType.lightning:
        return lightningSwap != null &&
            lightningSwap!.status == SwapStatus.paid;
      case ReceiveType.liquid:
        return false;
      case _:
        return false;
    }
  }

  bool get isPaymentReceived {
    switch (type) {
      case ReceiveType.bitcoin:
        return tx != null;
      case ReceiveType.lightning:
        return lightningSwap != null &&
            lightningSwap!.status == SwapStatus.completed;
      case ReceiveType.liquid:
        return tx != null;
      case _:
        return false;
    }
  }

  /// Whether the payjoin flow owns navigation for this receive, so the
  /// shell's generic "payment received → transaction details" listener must
  /// defer: the payjoin-in-progress screen lives on the root navigator and
  /// stays mounted over the receive shell, so without this the generic
  /// listener would whisk the user off the payjoin screen the instant the
  /// address watcher sees the (possibly fallback) transaction — before they
  /// can read why a payjoin did or didn't happen. `started` is deliberately
  /// excluded: a fresh receiver session with no request yet means a plain
  /// send to this address, unrelated to payjoin, which must still navigate
  /// via the generic listener.
  bool get isPayjoinFlowOwningNavigation {
    final receiver = payjoin;
    if (type != ReceiveType.bitcoin || receiver == null) return false;
    if (receiver.status == PayjoinStatus.started) return false;
    return !(receiver.status == PayjoinStatus.expired &&
        !receiver.hasOriginalTransaction);
  }

  /// True when the payjoin session resolved via the plain-broadcast fallback
  /// specifically because the sender's amount fell below the configured
  /// anti-probing minimum. Exact, not a heuristic: the repository declines
  /// below-minimum requests before any negotiation is attempted, so no other
  /// abort path is reachable for such an amount.
  bool get isPayjoinBelowMinimum {
    final amountSat = payjoin?.amountSat;
    final minAmountSat = payjoinMinAmountSat;
    return payjoin?.isAborted == true &&
        amountSat != null &&
        minAmountSat != null &&
        amountSat < minAmountSat;
  }

  bool get isPayjoinLoading {
    if (type == ReceiveType.bitcoin) {
      // Gated on [payjoinGloballyEnabled]: when payjoin is disabled in
      // settings, ReceiveBloc never creates a session and never sets an
      // exception (see _onBitcoinStarted), so [payjoin] stays null forever
      // and this getter must not keep reporting "still loading"
      // indefinitely — otherwise [paymentRequest] (which waits on this so
      // the QR doesn't flip from address-only to a pj= BIP21 mid-display)
      // never resolves and the receive QR never renders at all. Payjoin is
      // disabled by default, so without this gate that would be the state
      // of every fresh install. `null` (settings not read yet) still
      // counts as loading: the fetch resolves within the same handler that
      // would create the session.
      //
      // Also gated on [hasUtxos]: ReceiveBloc only creates a session for a
      // wallet with a balance to contribute (unconfirmed counts, see
      // ReceiveBloc._isPayjoinEligible — a payjoin proposal needs at least
      // one UTXO), so an empty wallet would otherwise hit the exact same
      // "stuck loading forever" bug as the disabled case.
      return wallet != null &&
          wallet!.signsLocally &&
          (payjoinGloballyEnabled ?? true) &&
          hasUtxos &&
          payjoin == null &&
          receivePayjoinException == null;
    }
    return false;
  }

  /// True when payjoin is enabled globally and this wallet can sign
  /// locally, but it has no balance yet — so ReceiveBloc did not
  /// create a payjoin receiver session (see ReceiveBloc._isPayjoinEligible).
  /// Lets the receive screen explain why payjoin isn't active despite being
  /// turned on, instead of silently doing nothing.
  bool get isPayjoinAwaitingFunds {
    if (type != ReceiveType.bitcoin) return false;
    return wallet != null &&
        wallet!.signsLocally &&
        payjoinGloballyEnabled == true &&
        !hasUtxos &&
        payjoin == null;
  }

  bool get isPayjoinAvailable {
    if (type == ReceiveType.bitcoin) {
      return wallet != null && wallet!.signsLocally && payjoin != null;
    }
    return false;
  }

  // Total balance, unconfirmed included: the contribution path draws from
  // BDK's listUnspent (which includes unconfirmed outputs), so an unconfirmed
  // UTXO is contributable — gating on confirmations would only delay payjoin
  // activation on fresh wallets (see ReceiveBloc._isPayjoinEligible).
  bool get hasUtxos => (wallet?.balanceSat ?? BigInt.zero) > BigInt.zero;

  /// Whether a payjoin on/off toggle should be offered on the receive screen
  /// for this wallet: it must be a bitcoin receive with a locally-signing,
  /// funded wallet (the only case where flipping the setting actually changes
  /// anything — a watch-only or empty wallet can never payjoin regardless).
  /// The toggle reflects/controls the GLOBAL [payjoinGloballyEnabled] setting.
  bool get isPayjoinToggleable =>
      type == ReceiveType.bitcoin &&
      wallet != null &&
      wallet!.signsLocally &&
      hasUtxos;

  /// True when the user has entered a requested amount that is below the
  /// configured anti-probing minimum. The receiver would decline a payjoin
  /// for such an amount anyway (see PayjoinRepositoryImpl's below-minimum
  /// decline), so advertising a pj= endpoint for it is pointless — this lets
  /// [canPayjoin] drop the endpoint from the QR for this request without
  /// tearing down the underlying session (a larger amount, or clearing the
  /// amount, re-enables it immediately). Only gates once an amount is
  /// actually entered (> 0); a plain address / no-amount request is
  /// unaffected.
  bool get isRequestedAmountBelowPayjoinMinimum {
    final amountSat = confirmedAmountSat;
    final minAmountSat = payjoinMinAmountSat;
    return amountSat != null &&
        amountSat > 0 &&
        minAmountSat != null &&
        amountSat < minAmountSat;
  }

  // Payjoin is only useful if the wallet has UTXOs to contribute as inputs in
  // the receiver's BIP78 PSBT — without UTXOs the proposal cannot be built.
  // The per-address opt-out toggle was removed: the global payjoin setting
  // (ReceiveBloc only creates [payjoin] at all when it's enabled, see
  // _onBitcoinStarted) is now the only control. Also suppressed when the
  // requested amount is below the anti-probing minimum: the sender's payjoin
  // would be declined for it anyway, so the QR shouldn't advertise pj=.
  bool get canPayjoin =>
      payjoin != null && hasUtxos && !isRequestedAmountBelowPayjoinMinimum;

  /// A payjoin session exists (feature on, funded wallet) but the pj=
  /// endpoint is currently dropped from the QR solely because the requested
  /// amount is below the anti-probing minimum. Lets the receive screen
  /// explain the transient suppression rather than silently omitting pj=.
  bool get isPayjoinSuppressedByAmount =>
      payjoin != null && hasUtxos && isRequestedAmountBelowPayjoinMinimum;

  double get payjoinAmountFiat {
    final payjoinAmountSat = payjoin?.amountSat ?? 0;
    final payjoinAmountBtc = ConvertAmount.satsToBtc(payjoinAmountSat);
    return ConvertAmount.btcToFiat(payjoinAmountBtc, exchangeRate);
  }

  bool get isLightning => type == ReceiveType.lightning;

  bool get isInputAmountBelowLimit {
    if (isLightning && swapLimits != null) {
      return inputAmountSat < swapLimits!.min;
    }
    return false;
  }

  bool get isInputAmountAboveLimit {
    if (isLightning && swapLimits != null) {
      return inputAmountSat > swapLimits!.max;
    }
    return false;
  }

  LnReceiveSwap? get getSwap {
    if (type == ReceiveType.lightning) {
      return lightningSwap;
    }

    return null;
  }

  String get address => switch (type) {
    ReceiveType.bitcoin => bitcoinAddress?.address ?? '',
    ReceiveType.lightning => lightningSwap?.receiveAddress ?? '',
    ReceiveType.liquid => liquidAddress?.address ?? '',
    _ => '',
  };

  String get abbreviatedAddress => StringFormatting.truncateMiddle(address);

  String get txId => switch (type) {
    ReceiveType.lightning => lightningSwap?.receiveTxid ?? '',
    _ => tx?.txId ?? '',
  };
  String get abbreviatedTxId => StringFormatting.truncateMiddle(txId);

  Transaction get transaction =>
      Transaction(walletTransaction: tx, swap: lightningSwap, payjoin: payjoin);
}

class AmountException extends BullException {
  AmountException(super.message);
}

class BelowSwapLimitAmountException extends AmountException {
  final int limitAmountSat;
  BelowSwapLimitAmountException(this.limitAmountSat)
    : super('Amount below swap limit of ${FormatAmount.sats(limitAmountSat)}');
}

class AboveSwapLimitAmountException extends AmountException {
  final int limitAmountSat;
  AboveSwapLimitAmountException(this.limitAmountSat)
    : super('Amount above swap limit of ${FormatAmount.sats(limitAmountSat)}');
}

class AboveBitcoinProtocolLimitAmountException extends AmountException {
  final int limitAmountSat;
  AboveBitcoinProtocolLimitAmountException(this.limitAmountSat)
    : super(
        'Amount above Bitcoin protocol limit of ${FormatAmount.sats(limitAmountSat)}',
      );
}
