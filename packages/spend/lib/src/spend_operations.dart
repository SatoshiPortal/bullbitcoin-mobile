part of 'spend.dart';

final class _Spend extends _SpendPreviews {
  final WalletNativeRuntime _sync;
  final Secrets _secrets;
  final ArkFundingSigningGuard _arkFunding;
  final SpendCatalog _catalog;
  final _submittedConsolidations = Expando<bool>();

  _Spend(this._sync, this._secrets, this._arkFunding, this._catalog);

  Future<Result<SpendWallet, SpendFailure>> _resolve(String id) async {
    try {
      return await _catalog.resolve(id);
    } on Exception {
      return const Err(SpendUnavailableFailure());
    }
  }

  Future<Result<Wallet, SpendFailure>> _wallet(String id) async {
    switch (await _resolve(id)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.key.id != id) return const Err(SpendUnavailableFailure());
        return (await _sync.wallet(value.key)).mapErr(_syncFailure);
    }
  }

  Future<Result<void, SpendFailure>> _validateSelection(
    Wallet wallet,
    Set<Outpoint>? selected,
  ) async {
    if (selected == null || selected.isEmpty) return const Ok(null);
    switch (await wallet.unspent()) {
      case Err(:final failure):
        return Err(_syncFailure(failure));
      case Ok(:final value):
        final eligible = {
          for (final coin in value)
            if (!coin.frozen) coin.outpoint,
        };
        if (!eligible.containsAll(selected)) {
          return const Err(SpendSelectedInputsUnavailableFailure());
        }
        return (await _sync.checkUnreservedInputs(selected))
            .mapErr(_syncFailure);
    }
  }

  @override
  Future<Result<void, SpendFailure>> validateBitcoinSelection({
    required String walletId,
    Set<Outpoint>? selectedInputs,
  }) async {
    final selected = selectedInputs == null ? null : Set.of(selectedInputs);
    return switch (await _wallet(walletId)) {
      Ok(:final value) when value.key.network is BitcoinNetwork =>
        selected == null || selected.isEmpty
            ? _unselectedPreconditions()
            : _validateSelection(value, selected),
      Ok() => const Err(SpendNetworkMismatchFailure()),
      Err(:final failure) => Err(failure),
    };
  }

  /// Without a selection the wallet chooses its inputs; funding then reads the
  /// freezes and the protocol reservations, so both must be readable now.
  Future<Result<void, SpendFailure>> _unselectedPreconditions() async {
    if (await _sync.readFrozenOutpoints() case Err(:final failure)) {
      return Err(_syncFailure(failure));
    }
    return (await _sync.checkUnreservedInputs(const {})).mapErr(_syncFailure);
  }

  @override
  Future<Result<PreparedBitcoinSpend, SpendFailure>> prepareBitcoin({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    Set<Outpoint>? selectedInputs,
    bool selectedOnly = false,
    bool replaceByFee = true,
  }) async {
    final targets = List.of(recipients);
    if (targets.any(
      (target) =>
          (target.amountSat?.value ?? BigInt.zero) > Sats.maxBitcoinSupply,
    )) {
      return const Err(SpendInvalidRequestFailure());
    }
    final selected = selectedInputs == null || selectedInputs.isEmpty
        ? null
        : Set.of(selectedInputs);
    if (selectedOnly && selected == null) {
      return const Err(SpendNoSpendableInputsFailure());
    }
    final BitcoinSpendRequest request;
    try {
      request = BitcoinSpendRequest(
        recipients: [
          for (final target in targets)
            SpendRecipient(
              target.address,
              amountSat: target.amountSat?.value.toInt(),
            ),
        ],
        fee: switch (networkFee) {
          AbsoluteFee(:final sats) => SpendAbsoluteFee(sats),
          RelativeFee(:final satPerKwu) => SpendFeeRate(satPerKwu),
        },
        selected: selected?.toList(),
        selectedOnly: selectedOnly,
        replaceable: replaceByFee,
      );
    } on ArgumentError {
      return const Err(SpendInvalidRequestFailure());
    }
    switch (await _wallet(walletId)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final wallet):
        final network = wallet.key.network;
        if (network is! BitcoinNetwork) {
          return const Err(SpendNetworkMismatchFailure());
        }
        if (await _validateSelection(wallet, selected) case Err(
          :final failure,
        )) {
          return Err(failure);
        }
        final scripts = <Uint8List>[];
        for (final target in targets) {
          if (await validateAddress(target.address, network) case Err()) {
            return const Err(SpendNetworkMismatchFailure());
          }
          switch (bitcoinAddressScript(target.address, network)) {
            case Err():
              return const Err(SpendNetworkMismatchFailure());
            case Ok(:final value):
              scripts.add(value);
          }
        }
        final ownership = await wallet.ownership();
        if (ownership case Err(:final failure)) {
          return Err(_syncFailure(failure));
        }
        final owned = (ownership as Ok<OwnershipIndex, SyncFailure>).value;
        switch (await wallet.tx.build(request)) {
          case Err(:final failure):
            return Err(_syncFailure(failure));
          case Ok(value: final built):
            final fee = bitcoinPsbtFee(built.encoded);
            if (fee case Err(:final failure)) return Err(_syncFailure(failure));
            final amounts = await bitcoinRecipientAmounts(
              psbt: built.encoded,
              network: network,
              recipients: [
                for (final target in request.recipients)
                  (address: target.address, amountSat: target.amountSat),
              ],
            );
            if (amounts case Err(:final failure)) {
              return Err(_syncFailure(failure));
            }
            final values = (amounts as Ok<List<int>, SyncFailure>).value;
            final feeSat = (fee as Ok<int, SyncFailure>).value;
            if (feeSat < 0 || values.any((amount) => amount < 0)) {
              return const Err(SpendInvalidTransactionFailure());
            }
            try {
              return Ok(
                PreparedBitcoinSpend._(
                  built,
                  unsignedPsbt: built.encoded,
                  fee: Sats.fromInt(feeSat),
                  txSize: decodeBitcoinPsbt(built.encoded).vsize,
                  isToSelf: scripts.every(owned.ownsScript),
                  recipientAmountsSat: values.map(Sats.fromInt).toList(),
                ),
              );
            } on FormatException {
              return const Err(SpendInvalidTransactionFailure());
            }
        }
    }
  }

  @override
  Future<Result<PreparedLiquidSpend, SpendFailure>> prepareLiquid({
    required String walletId,
    required String address,
    required RelativeFee feeRate,
    int? amountSat,
    bool drain = false,
    Set<Outpoint>? selectedInputs,
  }) async {
    if (drain == (amountSat != null)) {
      return const Err(SpendInvalidRequestFailure());
    }
    final LiquidSpendRequest request;
    try {
      request = LiquidSpendRequest(
        address: address,
        amountSat: amountSat,
        fee: SpendFeeRate(feeRate.satPerKwu),
        selected: selectedInputs,
      );
    } on ArgumentError {
      return const Err(SpendInvalidRequestFailure());
    }
    switch (await _wallet(walletId)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final wallet):
        final network = wallet.key.network;
        if (network is! LiquidNetwork) {
          return const Err(SpendNetworkMismatchFailure());
        }
        switch (await liquidAddressNetwork(address)) {
          case Ok(:final value) when value == network:
            break;
          case _:
            return const Err(SpendNetworkMismatchFailure());
        }
        if (request.selected case final selected? when selected.isEmpty) {
          return const Err(SpendNoSpendableInputsFailure());
        }
        if (await _validateSelection(wallet, request.selected) case Err(
          :final failure,
        )) {
          return Err(failure);
        }
        switch (await wallet.tx.build(request)) {
          case Err(:final failure):
            return Err(_syncFailure(failure));
          case Ok(value: final built):
            final fee = await liquidPsetFees(built.encoded);
            final effect = await wallet.tx.liquidAmountToAddress(
              built.encoded,
              request.address,
            );
            return switch ((fee, effect)) {
              (Ok(value: final price), Ok(value: final amount))
                  when price.feeSat >= 0 && !amount.isNegative =>
                Ok(
                  PreparedLiquidSpend._(
                    built,
                    unsignedPset: built.encoded,
                    fee: Sats.fromInt(price.feeSat),
                    amountSent: Sats(amount),
                    discountedVsize: price.discountedVsize,
                  ),
                ),
              (Err(:final failure), _) ||
              (_, Err(:final failure)) => Err(_syncFailure(failure)),
              _ => const Err(SpendInvalidTransactionFailure()),
            };
        }
    }
  }

  Future<
    Result<({Fingerprint fingerprint, ScriptType scriptType}), SpendFailure>
  >
  _signer(UnsignedSpend built) async {
    final handle = await _sync.wallet(built.key);
    switch (handle) {
      case Err(:final failure):
        return Err(_syncFailure(failure));
      case Ok(:final value) when value.generation != built.revision.generation:
        return const Err(SpendUnavailableFailure());
      case Ok():
        break;
    }
    final inputs = built.inputs.toSet();
    switch (await _sync.readFrozenOutpoints()) {
      case Err(:final failure):
        return Err(_syncFailure(failure));
      case Ok(:final value):
        if (value.any(inputs.contains)) {
          return const Err(SpendSelectedInputsUnavailableFailure());
        }
    }
    if (await _sync.checkUnreservedInputs(inputs) case Err(:final failure)) {
      return Err(_syncFailure(failure));
    }
    return switch (await _resolve(built.key.id)) {
      Err(:final failure) => Err(failure),
      Ok(:final value) when value.key != built.key => const Err(
        SpendNetworkMismatchFailure(),
      ),
      Ok(value: (key: _, signer: final signer?)) => Ok(signer),
      Ok() => const Err(SpendSigningRefusedFailure()),
    };
  }

  Future<Result<String, SpendFailure>> _signBitcoin(UnsignedSpend built) async {
    final network = built.key.network;
    if (network is! BitcoinNetwork) {
      return const Err(SpendNetworkMismatchFailure());
    }
    switch (await _signer(built)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final signer):
        if (await _arkFunding.admit(
              walletId: built.key.id,
              network: network,
              unsignedPsbt: built.encoded,
            )
            case Err()) {
          return const Err(SpendSigningRefusedFailure());
        }
        return switch (await _secrets.fetch(signer.fingerprint)) {
          Err() => const Err(SpendSigningRefusedFailure()),
          Ok(:final value) => (await value.sign.psbt(
            built.encoded,
            network: network,
            scriptType: signer.scriptType,
          )).mapErr((_) => const SpendSigningRefusedFailure()),
        };
    }
  }

  @override
  Future<Result<SignedBitcoinSpend, SpendFailure>> signBitcoin({
    required PreparedBitcoinSpend prepared,
  }) async {
    final built = prepared._native;
    if (built == null) return const Err(SpendInvalidRequestFailure());
    return switch (await _signBitcoin(built)) {
      Err(:final failure) => Err(failure),
      Ok(:final value) => _verifyBitcoin(
        built,
        signedTransaction: value,
        isPsbt: true,
      ),
    };
  }

  Future<Result<SignedLiquidSpend, SpendFailure>> _signLiquid(
    UnsignedSpend built,
  ) async {
    final network = built.key.network;
    if (network is! LiquidNetwork) {
      return const Err(SpendNetworkMismatchFailure());
    }
    switch (await _signer(built)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final signer):
        return switch (await _secrets.fetch(signer.fingerprint)) {
          Err() => const Err(SpendSigningRefusedFailure()),
          Ok(:final value) =>
            (await value.sign.pset(built.encoded, network: network))
                .map(
                  (pset) =>
                      SignedLiquidSpend._(built.signed(SignedPset(pset)), pset),
                )
                .mapErr((_) => const SpendSigningRefusedFailure()),
        };
    }
  }

  @override
  Future<Result<SignedLiquidSpend, SpendFailure>> signLiquid({
    required PreparedLiquidSpend prepared,
  }) async => switch (prepared._native) {
    final built? => _signLiquid(built),
    null => const Err(SpendInvalidRequestFailure()),
  };

  @override
  Future<Result<SignedBitcoinSpend, SpendFailure>> verifySignedBitcoin({
    required PreparedBitcoinSpend prepared,
    required String signedTransaction,
    required bool isPsbt,
  }) async => switch (prepared._native) {
    final built? => _verifyBitcoin(
      built,
      signedTransaction: signedTransaction,
      isPsbt: isPsbt,
    ),
    null => const Err(SpendInvalidRequestFailure()),
  };

  @override
  Result<void, SpendFailure> verifyExternalBitcoin({
    required String unsignedPsbt,
    required String signedTransaction,
    required bool isPsbt,
  }) => _bitcoinEvidence(
    unsignedPsbt,
    signedTransaction,
    isPsbt,
    requireFinalized: false,
  ).map((_) {});

  Result<SignedBitcoinSpend, SpendFailure> _verifyBitcoin(
    UnsignedSpend built, {
    required String signedTransaction,
    required bool isPsbt,
  }) => _bitcoinEvidence(built.encoded, signedTransaction, isPsbt).map(
    (decoded) => SignedBitcoinSpend._(
      built.signed(SignedBitcoinTransaction(decoded.bytes)),
      signedTransaction,
      decoded.vsize,
    ),
  );

  Future<Result<SpendBroadcastReceipt, SpendFailure>> _broadcast(
    SignedSpend? signed,
  ) async {
    if (signed == null) return const Err(SpendInvalidRequestFailure());
    try {
      return (await _sync.broadcastSigned(signed))
          .map(
            (value) => (
              txid: value.txid,
              guarded: value.guarded,
              durable: value.durable,
            ),
          )
          .mapErr(_syncFailure);
    } on Exception {
      return const Err(SpendBroadcastOutcomeUnknownFailure());
    }
  }

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastBitcoin(
    SignedBitcoinSpend signed,
  ) => _broadcast(signed._native);

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> broadcastLiquid(
    SignedLiquidSpend signed,
  ) => _broadcast(signed._native);

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> resumeLiquidPayin({
    required String signedPset,
    required String walletId,
    required LiquidNetwork network,
    required String address,
    required Sats amount,
  }) async {
    if (amount == Sats.zero) return const Err(SpendInvalidRequestFailure());
    final wallet = await _wallet(walletId);
    switch (wallet) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.key.network != network) {
          return const Err(SpendNetworkMismatchFailure());
        }
        switch (await liquidAddressNetwork(address)) {
          case Ok(value: final addressNetwork) when addressNetwork == network:
            break;
          case _:
            return const Err(SpendNetworkMismatchFailure());
        }
        switch (await value.tx.liquidAmountToAddress(signedPset, address)) {
          case Err(:final failure):
            return Err(_syncFailure(failure));
          case Ok(value: final sent) when sent != amount.value:
            return const Err(SpendSignedTransactionMismatchFailure());
          case Ok():
            break;
        }
        switch (await value.tx.liquidEffect(signedPset)) {
          case Err(:final failure):
            return Err(_syncFailure(failure));
          case Ok(value: final effect)
              when BigInt.from(-effect.policyBalanceSat - effect.feeSat) !=
                  amount.value:
            return const Err(SpendSignedTransactionMismatchFailure());
          case Ok():
            return _broadcast(value.tx.signed(SignedPset(signedPset)));
        }
    }
  }

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> resumeBitcoinPayin({
    required String signedPsbt,
    required String walletId,
    required BitcoinNetwork network,
    required String address,
    required Sats amount,
    bool isPsbt = true,
  }) async {
    if (amount == Sats.zero || amount.value > Sats.maxBitcoinSupply) {
      return const Err(SpendInvalidRequestFailure());
    }
    final DecodedBitcoinTransaction tx;
    if (isPsbt) {
      switch (_bitcoinEvidence(signedPsbt, signedPsbt, true)) {
        case Err(:final failure):
          return Err(failure);
        case Ok(:final value):
          tx = value;
      }
    } else {
      try {
        tx = decodeBitcoinTransaction(_hex(signedPsbt));
      } on FormatException {
        return const Err(SpendInvalidTransactionFailure());
      }
    }
    final wallet = await _wallet(walletId);
    switch (wallet) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.key.network != network) {
          return const Err(SpendNetworkMismatchFailure());
        }
        switch (bitcoinAddressScript(address, network)) {
          case Err(:final failure):
            return Err(_syncFailure(failure));
          case Ok(value: final script):
            final paid = tx.outputs
                .where((output) => _sameBytes(output.scriptPubkey, script))
                .fold(
                  BigInt.zero,
                  (sum, output) => sum + BigInt.from(output.valueSat),
                );
            if (paid != amount.value) {
              return const Err(SpendSignedTransactionMismatchFailure());
            }
            switch (await value.ownership()) {
              case Err(:final failure):
                return Err(_syncFailure(failure));
              case Ok(value: final owned):
                if (tx.outputs.any(
                  (output) =>
                      !_sameBytes(output.scriptPubkey, script) &&
                      !owned.ownsScript(output.scriptPubkey),
                )) {
                  return const Err(SpendSignedTransactionMismatchFailure());
                }
            }
            return _broadcast(
              value.tx.signed(SignedBitcoinTransaction(tx.bytes)),
            );
        }
    }
  }

  @override
  Future<Result<String, SpendFailure>> broadcastImportedBitcoin({
    required String transaction,
    required BitcoinNetwork network,
    required bool isPsbt,
  }) async {
    final List<int> bytes;
    try {
      if (isPsbt) {
        switch (finalizeBitcoinPsbts(
          unsignedBase64: transaction,
          signedBase64: transaction,
        )) {
          case Err(:final failure):
            return Err(_syncFailure(failure));
          case Ok(:final value):
            bytes = value.bytes;
        }
      } else {
        bytes = _hex(transaction);
      }
    } on FormatException {
      return const Err(SpendInvalidTransactionFailure());
    }
    try {
      return (await _sync.broadcastImportedBitcoin(
        bytes,
        network: network,
      )).mapErr(_syncFailure);
    } on Exception {
      return const Err(SpendBroadcastOutcomeUnknownFailure());
    }
  }

  @override
  Future<Result<PayjoinSpendHandoff, SpendFailure>> handOffToPayjoin(
    PreparedBitcoinSpend prepared, {
    required WalletKey wallet,
    required String sessionId,
    required String signedPsbt,
    required Future<void> Function() persist,
  }) async {
    final built = prepared._native;
    if (built == null ||
        built.key != wallet ||
        built.owner != null ||
        built.replacing != null ||
        sessionId.isEmpty ||
        built.key.network is! BitcoinNetwork) {
      return const Err(SpendInvalidRequestFailure());
    }
    final inputs = built.inputs.toSet();
    switch (_bitcoinEvidence(built.encoded, signedPsbt, true)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(:final value):
        if (value.inputs.length != inputs.length ||
            !inputs.containsAll(value.inputs)) {
          return const Err(SpendSignedTransactionMismatchFailure());
        }
    }
    return (await _sync.reservePayjoinInputs(
          built.key,
          inputs: inputs,
          sessionId: sessionId,
          expectedGeneration: built.revision.generation,
          persist: persist,
        ))
        .map<PayjoinSpendHandoff>(
          (_) => _PayjoinSpendHandoff(built.encoded, built.key, inputs),
        )
        .mapErr(_syncFailure);
  }

  @override
  Future<Result<void, SpendFailure>> verifyOriginalBitcoin({
    required String walletId,
    required String originalTxid,
    required BitcoinNetwork network,
  }) async {
    switch (await _wallet(walletId)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final wallet):
        if (wallet.key.network != network) {
          return const Err(SpendNetworkMismatchFailure());
        }
        return switch (await wallet.tx.originalSignatures(originalTxid)) {
          Err(:final failure) => Err(_syncFailure(failure)),
          Ok(value: SignatureCheck.valid) => const Ok(null),
          Ok(value: final check) => Err(
            SpendOriginalSignaturesFailure(
              unverifiable: check == SignatureCheck.unverifiable,
            ),
          ),
        };
    }
  }

  @override
  Future<Result<SpendBroadcastReceipt, SpendFailure>> replaceBitcoin({
    required String walletId,
    required String originalTxid,
    required BitcoinNetwork network,
    required RelativeFee newFeeRate,
  }) async {
    final BumpFeeRequest request;
    try {
      request = BumpFeeRequest(
        txid: originalTxid,
        fee: SpendFeeRate(newFeeRate.satPerKwu),
      );
    } on ArgumentError {
      return const Err(SpendInvalidRequestFailure());
    }
    switch (await _wallet(walletId)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final wallet):
        if (wallet.key.network != network) {
          return const Err(SpendNetworkMismatchFailure());
        }
        switch (await wallet.tx.bump(request)) {
          case Err(:final failure):
            return Err(_syncFailure(failure));
          case Ok(value: final built):
            return switch (await _signBitcoin(built)) {
              Err(:final failure) => Err(failure),
              Ok(:final value) => switch (_verifyBitcoin(
                built,
                signedTransaction: value,
                isPsbt: true,
              )) {
                Err(:final failure) => Err(failure),
                Ok(value: final signed) => broadcastBitcoin(signed),
              },
            };
        }
    }
  }

  @override
  Future<Result<int, SpendFailure>> countLiquidCoins(String walletId) async =>
      switch (await _wallet(walletId)) {
        Err(:final failure) => Err(failure),
        Ok(value: final wallet) when wallet.key.network is LiquidNetwork =>
          (await wallet.unspent())
              .map((coins) => coins.length)
              .mapErr(_syncFailure),
        Ok() => const Err(SpendNetworkMismatchFailure()),
      };

  @override
  Future<Result<bool, SpendFailure>> needsLiquidConsolidation(
    String walletId, {
    required int highUtxoThreshold,
  }) async {
    if (highUtxoThreshold < 0) return const Err(SpendInvalidRequestFailure());
    switch (await _wallet(walletId)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final wallet):
        if (wallet.key.network is! LiquidNetwork) {
          return const Err(SpendNetworkMismatchFailure());
        }
        return (await wallet.unspent())
            .map(
              (coins) =>
                  coins
                      .where(
                        (coin) =>
                            coin is LiquidCoin &&
                            !coin.frozen &&
                            (coin.blockHeight ?? 0) > 0,
                      )
                      .length >
                  highUtxoThreshold,
            )
            .mapErr(_syncFailure);
    }
  }

  @override
  Future<Result<PreparedLiquidConsolidation, SpendFailure>>
  prepareLiquidConsolidation(
    String walletId, {
    required RelativeFee feeRate,
    required int highUtxoThreshold,
    required int maximumInputs,
  }) async {
    final ConsolidationRequest request;
    try {
      request = ConsolidationRequest(
        fee: SpendFeeRate(feeRate.satPerKwu),
        highUtxoThreshold: highUtxoThreshold,
        maximumInputs: maximumInputs,
      );
    } on ArgumentError {
      return const Err(SpendInvalidRequestFailure());
    }
    switch (await _wallet(walletId)) {
      case Err(:final failure):
        return Err(failure);
      case Ok(value: final wallet):
        if (wallet.key.network is! LiquidNetwork) {
          return const Err(SpendNetworkMismatchFailure());
        }
        switch (await wallet.tx.consolidate(request)) {
          case Err(:final failure):
            return Err(_syncFailure(failure));
          case Ok(value: final batches):
            var total = BigInt.zero;
            for (final batch in batches) {
              switch (await liquidPsetFees(batch.encoded)) {
                case Err(:final failure):
                  return Err(_syncFailure(failure));
                case Ok(:final value) when value.feeSat >= 0:
                  total += BigInt.from(value.feeSat);
                case Ok():
                  return const Err(SpendInvalidTransactionFailure());
              }
            }
            return Ok(
              PreparedLiquidConsolidation._(
                List.unmodifiable(batches),
                batches.length,
                Sats(total),
              ),
            );
        }
    }
  }

  @override
  Future<Result<List<String>, SpendFailure>> submitLiquidConsolidation(
    PreparedLiquidConsolidation prepared,
  ) async {
    final batches = prepared._batches;
    if (batches == null || _submittedConsolidations[prepared] == true) {
      return const Err(SpendInvalidRequestFailure());
    }
    _submittedConsolidations[prepared] = true;
    final accepted = <String>[];
    for (final batch in batches) {
      final result = switch (await _signLiquid(batch)) {
        Err(:final failure) => Err<SpendBroadcastReceipt, SpendFailure>(
          failure,
        ),
        Ok(:final value) => await broadcastLiquid(value),
      };
      switch (result) {
        case Err(:final failure):
          return Err(SpendConsolidationInterruptedFailure(accepted, failure));
        case Ok(:final value):
          accepted.add(value.txid);
      }
    }
    return Ok(List.unmodifiable(accepted));
  }
}

final class _PayjoinSpendHandoff implements PayjoinSpendHandoff {
  @override
  final String unsignedPsbt;
  @override
  final WalletKey wallet;
  @override
  final Set<Outpoint> inputs;

  _PayjoinSpendHandoff(this.unsignedPsbt, this.wallet, Set<Outpoint> inputs)
    : inputs = Set.unmodifiable(inputs);
}

Result<DecodedBitcoinTransaction, SpendFailure> _bitcoinEvidence(
  String unsignedPsbt,
  String signedTransaction,
  bool isPsbt, {
  bool requireFinalized = true,
}) {
  try {
    final unsignedResult = bitcoinPsbtSkeleton(unsignedPsbt);
    if (unsignedResult case Err(:final failure)) {
      return Err(_syncFailure(failure));
    }
    final unsigned =
        (unsignedResult as Ok<DecodedBitcoinTransaction, SyncFailure>).value;
    final signedResult = isPsbt
        ? bitcoinPsbtSkeleton(signedTransaction)
        : Ok<DecodedBitcoinTransaction, SyncFailure>(
            decodeBitcoinTransaction(_hex(signedTransaction)),
          );
    if (signedResult case Err(:final failure)) {
      return Err(_syncFailure(failure));
    }
    final signed =
        (signedResult as Ok<DecodedBitcoinTransaction, SyncFailure>).value;
    if (unsigned.version != signed.version ||
        unsigned.locktime != signed.locktime ||
        unsigned.inputDetails.length != signed.inputDetails.length ||
        unsigned.outputs.length != signed.outputs.length) {
      return const Err(SpendSignedTransactionMismatchFailure());
    }
    for (final (index, input) in unsigned.inputDetails.indexed) {
      final candidate = signed.inputDetails[index];
      if (input.outpoint != candidate.outpoint ||
          input.sequence != candidate.sequence) {
        return const Err(SpendSignedTransactionMismatchFailure());
      }
    }
    for (final (index, output) in unsigned.outputs.indexed) {
      final candidate = signed.outputs[index];
      if (output.valueSat != candidate.valueSat ||
          output.scriptPubkey.length != candidate.scriptPubkey.length ||
          output.scriptPubkey.indexed.any(
            (item) => item.$2 != candidate.scriptPubkey[item.$1],
          )) {
        return const Err(SpendSignedTransactionMismatchFailure());
      }
    }
    if (!isPsbt || !requireFinalized) return Ok(signed);
    return finalizeBitcoinPsbts(
      unsignedBase64: unsignedPsbt,
      signedBase64: signedTransaction,
    ).mapErr(_syncFailure);
  } on FormatException {
    return const Err(SpendInvalidTransactionFailure());
  }
}

Uint8List _hex(String value) {
  if (value.length > maxBitcoinTransactionBytes * 2 ||
      value.length.isOdd ||
      !RegExp(r'^[0-9a-fA-F]+$').hasMatch(value)) {
    throw const FormatException('Invalid transaction hex');
  }
  return Uint8List.fromList([
    for (var index = 0; index < value.length; index += 2)
      int.parse(value.substring(index, index + 2), radix: 16),
  ]);
}

bool _sameBytes(List<int> left, List<int> right) =>
    left.length == right.length &&
    Iterable<int>.generate(left.length)
        .every((index) => left[index] == right[index]);

SpendFailure _syncFailure(SyncFailure failure) => switch (failure) {
  SyncInsufficientFundsFailure() => const SpendInsufficientFundsFailure(),
  SyncFeeRateTooLowFailure() => const SpendFeeRateTooLowFailure(),
  SyncNoSpendableInputsFailure() => const SpendNoSpendableInputsFailure(),
  SyncProtectedInputsFailure() => const SpendSelectedInputsUnavailableFailure(),
  SyncUnauthorizedNetworkFailure() =>
    const SpendDeveloperAuthorizationFailure(),
  SyncUnsupportedNetworkFailure() ||
  SyncInvalidAddressFailure() => const SpendNetworkMismatchFailure(),
  SyncConsolidationRequiredFailure() =>
    const SpendConsolidationRequiredFailure(),
  SyncSpendRefusedFailure() => const SpendBuildRefusedFailure(),
  SyncOriginalSignaturesFailure(:final check) => SpendOriginalSignaturesFailure(
    unverifiable: check == SignatureCheck.unverifiable,
  ),
  SyncBroadcastRejectedFailure() => const SpendBroadcastRejectedFailure(
    SpendBroadcastRejection.nodeRejected,
  ),
  SyncAlreadyInChainFailure() => const SpendAlreadyInChainFailure(),
  SyncConnectionFailure() => const SpendBroadcastConnectionFailure(),
  SyncOutcomeUnknownFailure() ||
  SyncUnrecognizedReplyFailure() => const SpendBroadcastOutcomeUnknownFailure(),
  SyncInvalidTransactionFailure() ||
  SyncNotFinalizableFailure() => const SpendInvalidTransactionFailure(),
  SyncBusyFailure() => const SpendUnavailableFailure(busy: true),
  SyncSpendBlockedFailure(:final status) => SpendUnavailableFailure(
    busy: status == BitcoinSpendStatus.busy,
    replacementPending: status == BitcoinSpendStatus.replacementPending,
  ),
  SyncNotFoundFailure() ||
  SyncStorageFailure() ||
  SyncClosedFailure() ||
  SyncNeedsRepairFailure() ||
  SyncRestartRequiredFailure() ||
  SyncInitialScanRequiredFailure() ||
  SyncInvalidCatalogFailure() => const SpendUnavailableFailure(),
};

abstract class _SpendPreviews implements Spend {
  @override
  Future<Result<BitcoinSpendPreview?, SpendFailure>> previewBitcoinFee({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required NetworkFee networkFee,
    required bool replaceByFee,
    required Set<Outpoint> selectedInputs,
    bool selectedOnly = false,
  }) async => switch (await prepareBitcoin(
    walletId: walletId,
    recipients: recipients,
    networkFee: networkFee,
    replaceByFee: replaceByFee,
    selectedInputs: selectedInputs,
    selectedOnly: selectedOnly,
  )) {
    Ok(value: final prepared) => Ok((prepared: prepared, fee: prepared.fee)),
    Err(
      failure: SpendInsufficientFundsFailure() ||
          SpendInsufficientFundsForFeesFailure() ||
          SpendBuildRefusedFailure(),
    ) =>
      const Ok(null),
    Err(:final failure) => Err(failure),
  };

  @override
  Future<Result<Map<FeeSelection, BitcoinSpendPreview?>, SpendFailure>>
  previewBitcoinFeePresets({
    required String walletId,
    required List<BitcoinTransactionRecipient> recipients,
    required FeeOptions presets,
    required bool replaceByFee,
    required Set<Outpoint> selectedInputs,
    bool selectedOnly = false,
  }) async {
    final byRate = <NetworkFee, BitcoinSpendPreview?>{};
    final bySlot = <FeeSelection, BitcoinSpendPreview?>{};
    final targets = List.of(recipients);
    final selected = Set.of(selectedInputs);
    // Builds reveal change; do not run competing writes on one wallet.
    for (final (slot, rate) in [
      (FeeSelection.fastest, presets.fastest),
      (FeeSelection.economic, presets.economic),
      (FeeSelection.slow, presets.slow),
    ]) {
      if (!byRate.containsKey(rate)) {
        switch (await previewBitcoinFee(
          walletId: walletId,
          recipients: targets,
          networkFee: rate,
          replaceByFee: replaceByFee,
          selectedInputs: selected,
          selectedOnly: selectedOnly,
        )) {
          case Err(:final failure):
            return Err(failure);
          case Ok(:final value):
            byRate[rate] = value;
        }
      }
      bySlot[slot] = byRate[rate];
    }
    return Ok(Map.unmodifiable(bySlot));
  }
}
