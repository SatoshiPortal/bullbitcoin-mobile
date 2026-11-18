import 'dart:typed_data';

import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/bull_sdk.dart' as bull_sdk;
import 'package:bull_sdk/lwk.dart' as lwk;
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart';

import '../../../domain/public_wallet_descriptor.dart';
import '../../../domain/spend.dart';
import '../../../domain/sync_failure.dart';
import '../../codec/liquid_codec.dart';
import '../../codec/liquid_codec.dart' as codec show liquidAddressNetwork;
import '../../codec/native_bitcoin_transaction.dart';
import '../../native_store_paths.dart';
import '../datasources/bdk_wallet_store_datasource.dart';
import '../datasources/native_store_errors.dart';
import '../native_write_session.dart';

/// A built transaction and the effective inputs it spends.
final class BuiltTransaction {
  final String encoded;
  final List<Outpoint> inputs;

  BuiltTransaction(this.encoded, List<Outpoint> inputs)
    : inputs = List.unmodifiable(inputs);
}

/// Funding must retain its unsigned txid through external signing. Refuse
/// scriptSig-bearing inputs, missing witness prevouts and any signed/finalised
/// PSBT input. This is checked on actual native output, not caller metadata.
bool isUnfinalisedNativeSegwitFunding(BuiltTransaction built) {
  bdk.Psbt? psbt;
  try {
    psbt = bdk.Psbt(psbtBase64: built.encoded);
    final decoded = decodeNativePsbt(psbt);
    final inputs = psbt.input();
    try {
      if (inputs.isEmpty ||
          inputs.length != built.inputs.length ||
          decoded.inputs.length != built.inputs.length) {
        return false;
      }
      for (var index = 0; index < inputs.length; index++) {
        final input = inputs[index];
        final script = input.witnessUtxo?.scriptPubkey.toBytes();
        if (script == null ||
            script.length != 22 ||
            script[0] != 0 ||
            script[1] != 20 ||
            input.redeemScript != null ||
            input.finalScriptSig != null ||
            input.finalScriptWitness != null ||
            input.partialSigs.isNotEmpty ||
            input.tapKeySig != null ||
            input.tapScriptSigs.isNotEmpty ||
            decoded.inputs[index] != built.inputs[index] ||
            decoded.inputDetails[index].scriptSig.isNotEmpty) {
          return false;
        }
      }
      return true;
    } finally {
      for (final input in inputs) {
        input.nonWitnessUtxo?.dispose();
        input.witnessUtxo?.scriptPubkey.dispose();
        input.witnessUtxo?.value.dispose();
        input.redeemScript?.dispose();
        input.witnessScript?.dispose();
        input.finalScriptSig?.dispose();
      }
    }
  } on Exception {
    return false;
  } finally {
    psbt?.dispose();
  }
}

/// Thrown by a native spend to end the command with [failure].
final class SpendRefusal implements Exception {
  final SyncFailure failure;
  const SpendRefusal(this.failure);
}

/// Opens one native wallet for one spend command, from its durable store.
/// Never cached: each command opens, builds once, persists and closes.
abstract interface class NativeSpendSessions {
  Future<NativeBitcoinSpend> bitcoin(BitcoinWalletDescriptor descriptor);
  Future<NativeLiquidSpend> liquid(LiquidWalletDescriptor descriptor);

  /// The inputs [pset] spends, decoded without a wallet. Throws
  /// [SpendRefusal] when it does not decode.
  List<Outpoint> psetInputs(String pset);

  /// The Liquid network [address] belongs to.
  Future<Result<LiquidNetwork, SyncFailure>> liquidAddressNetwork(
    String address,
  );
}

abstract interface class NativeBitcoinSpend {
  /// The unspent outpoints the wallet holds.
  Set<Outpoint> unspent();

  /// The inputs of this wallet's transaction [txid], or null when unknown.
  List<Outpoint>? transactionInputs(String txid);

  /// One build. Throws [SpendRefusal] for a request the builder refuses.
  BuiltTransaction build(BitcoinSpendRequest request, Set<Outpoint> excluded);

  /// One replacement of [txid]. The pinned builder cannot exclude inputs: the
  /// caller checks the ones it picked.
  BuiltTransaction bumpFee(String txid, SpendFeeRate fee);

  /// Whether every output of [psbt] pays a recipient of [request] or this
  /// wallet, and each fixed amount is paid in full.
  bool paysAsRequested(String psbt, BitcoinSpendRequest request);

  /// Whether the outputs of the replacement [psbt] keep every external
  /// payee of [txid].
  bool keepsPayees(String psbt, String txid);

  Future<SignatureCheck> originalSignatures(String txid);

  /// [psbt] with this wallet's derivations on the inputs and outputs it
  /// owns. Signs nothing: the wallet holds no key.
  String annotate(String psbt);

  /// Persists staged native changes. True when something was written.
  bool persist();

  void close();
}

abstract interface class NativeLiquidSpend {
  /// Policy-asset coins, with whether they are confirmed.
  Future<List<({Outpoint outpoint, bool confirmed})>> coins();

  Future<String> build(LiquidSpendRequest request, Set<Outpoint>? inputs);

  /// Consolidation batches of [coins], each paid to the next unused address.
  Future<List<String>> consolidate(
    ConsolidationRequest request,
    List<Outpoint> coins,
  );

  /// LWK's own batches, when nothing is excluded.
  Future<List<String>> consolidateAll(ConsolidationRequest request);

  Future<LiquidPsetEffect> effect(String pset);

  Future<BigInt> amountToAddress(String pset, String address);

  void close();
}

/// Number of confidential-transaction inputs above which LWK cannot build.
const maxLiquidTransactionInputs = 256;

/// The SDK sessions, at the published store paths.
final class SdkSpendSessions implements NativeSpendSessions {
  final String documentsDirectory;

  const SdkSpendSessions(this.documentsDirectory);

  @override
  Future<NativeBitcoinSpend> bitcoin(
    BitcoinWalletDescriptor descriptor,
  ) async => _BitcoinSpend(
    BdkWalletStoreDatasource.load(
      nativeWalletStoragePath(documentsDirectory, descriptor.key),
      descriptor,
    ),
    descriptor,
  );

  @override
  Future<NativeLiquidSpend> liquid(LiquidWalletDescriptor descriptor) async {
    final store = await openLiquidStore(documentsDirectory, descriptor);
    return _LiquidSpend(
      store.store.wallet,
      store.store.close,
      descriptor.key.network,
    );
  }

  @override
  List<Outpoint> psetInputs(String pset) => switch (decodeLiquidPset(pset)) {
    Ok(:final value) => [
      for (final input in value.inputs) (txId: input.txid, vout: input.vout),
    ],
    Err() => throw const SpendRefusal(SyncInvalidTransactionFailure()),
  };

  @override
  Future<Result<LiquidNetwork, SyncFailure>> liquidAddressNetwork(
    String address,
  ) => codec.liquidAddressNetwork(address);
}

Outpoint _outpoint(bdk.OutPoint outpoint) =>
    (txId: outpoint.txid.toString(), vout: outpoint.vout);

final class _BitcoinSpend implements NativeBitcoinSpend {
  final BdkWalletStoreDatasource _store;
  final BitcoinWalletDescriptor _descriptor;

  _BitcoinSpend(this._store, this._descriptor);

  bdk.Wallet get _wallet => _store.wallet;

  bdk.Network get _network =>
      BdkWalletStoreDatasource.network(_descriptor.key.network) ??
      (throw const NativeNetworkUnsupported());

  @override
  Set<Outpoint> unspent() => {
    for (final output in _wallet.listUnspent()) _outpoint(output.outpoint),
  };

  @override
  List<Outpoint>? transactionInputs(String txid) {
    final native = bdk.Txid.fromString(hex: txid);
    try {
      final canonical = _wallet.getTx(txid: native);
      if (canonical == null) return null;
      return [
        for (final input in canonical.transaction.input())
          _outpoint(input.previousOutput),
      ];
    } finally {
      native.dispose();
    }
  }

  bdk.Script _script(String address) {
    // Base58 is ambiguous between testnet and regtest: new regtest spends
    // require bech32 bcrt1.
    if (_descriptor.key.network == BitcoinNetwork.regtest &&
        !address.toLowerCase().startsWith('bcrt1')) {
      throw const SpendRefusal(SyncInvalidAddressFailure());
    }
    final bdk.Address parsed;
    try {
      parsed = bdk.Address(address: address, network: _network);
    } on Exception {
      throw const SpendRefusal(SyncInvalidAddressFailure());
    }
    try {
      return parsed.scriptPubkey();
    } finally {
      parsed.dispose();
    }
  }

  static bdk.OutPoint _native(Outpoint outpoint) => bdk.OutPoint(
    txid: bdk.Txid.fromString(hex: outpoint.txId),
    vout: outpoint.vout,
  );

  @override
  BuiltTransaction build(BitcoinSpendRequest request, Set<Outpoint> excluded) {
    final scripts = [
      for (final recipient in request.recipients) _script(recipient.address),
    ];
    var builder = bdk.TxBuilder();
    for (var index = 0; index < request.recipients.length; index++) {
      final amount = request.recipients[index].amountSat;
      builder = amount == null
          ? builder.drainWallet().drainTo(script: scripts[index])
          : builder.addRecipient(
              script: scripts[index],
              amount: bdk.Amount.fromSat(satoshi: amount),
            );
    }
    final selected = request.selected;
    if (request.selectedOnly && (selected == null || selected.isEmpty)) {
      throw const SpendRefusal(SyncNoSpendableInputsFailure());
    }
    if (selected != null && selected.isNotEmpty) {
      // The builder is immutable: keep the builder each call returns.
      builder = builder
          .addUtxos(outpoints: [for (final input in selected) _native(input)])
          .manuallySelectedOnly();
    }
    // BDK signals replaceability by default (nSequence 0xFFFFFFFD).
    if (!request.replaceable) {
      builder = builder.setExactSequence(nsequence: 0xFFFFFFFE);
    }
    builder = switch (request.fee) {
      SpendAbsoluteFee(:final sats) => builder.feeAbsolute(
        feeAmount: bdk.Amount.fromSat(satoshi: sats),
      ),
      // sat/kwu is BDK's own unit: no rounding of fractional sat/vB rates.
      SpendFeeRate(:final satPerKwu) => builder.feeRate(
        feeRate: bdk.FeeRate.fromSatPerKwu(satKwu: satPerKwu),
      ),
    };
    if (excluded.isNotEmpty) {
      if (unspent().difference(excluded).isEmpty) {
        throw const SpendRefusal(SyncNoSpendableInputsFailure());
      }
      builder = builder.unspendable(
        unspendable: [for (final input in excluded) _native(input)],
      );
    }
    final bdk.Psbt psbt;
    try {
      psbt = builder.finish(wallet: _wallet);
    } on bdk.InsufficientFundsCreateTxException {
      throw const SpendRefusal(SyncInsufficientFundsFailure());
    } on bdk.CoinSelectionCreateTxException {
      // Hand-picked coins that cannot cover the outputs and the fee.
      throw const SpendRefusal(SyncInsufficientFundsFailure());
    } on bdk.OutputBelowDustLimitCreateTxException {
      throw const SpendRefusal(SyncInsufficientFundsFailure());
    } on bdk.CreateTxException {
      throw const SpendRefusal(SyncSpendRefusedFailure());
    }
    try {
      final decoded = decodeNativePsbt(psbt);
      // A remainder the fee consumed, or below the destination's dust limit
      // once the fixed payees are paid, is a shortfall.
      final remainder = request.recipients.indexWhere(
        (recipient) => recipient.amountSat == null,
      );
      if (remainder >= 0) {
        final target = _hex(scripts[remainder].toBytes());
        var paid = 0;
        for (final output in decoded.outputs) {
          if (_hex(output.scriptPubkey) == target) paid += output.valueSat;
        }
        for (var index = 0; index < request.recipients.length; index++) {
          if (_hex(scripts[index].toBytes()) == target) {
            paid -= request.recipients[index].amountSat ?? 0;
          }
        }
        if (paid <= 0) {
          throw const SpendRefusal(SyncInsufficientFundsFailure());
        }
      }
      return BuiltTransaction(psbt.serialize(), decoded.inputs);
    } finally {
      psbt.dispose();
    }
  }

  @override
  BuiltTransaction bumpFee(String txid, SpendFeeRate fee) {
    final native = bdk.Txid.fromString(hex: txid);
    final bdk.Psbt psbt;
    try {
      // Rate only, by BIP125 design; sat/kwu keeps sub-1 sat/vB bumps exact.
      psbt = bdk.BumpFeeTxBuilder(
        txid: native,
        feeRate: bdk.FeeRate.fromSatPerKwu(satKwu: fee.satPerKwu),
      ).finish(wallet: _wallet);
    } on bdk.FeeRateTooLowCreateTxException {
      throw const SpendRefusal(SyncFeeRateTooLowFailure());
    } on bdk.FeeTooLowCreateTxException {
      throw const SpendRefusal(SyncFeeRateTooLowFailure());
    } on bdk.InsufficientFundsCreateTxException {
      throw const SpendRefusal(SyncInsufficientFundsFailure());
    } on bdk.CoinSelectionCreateTxException {
      throw const SpendRefusal(SyncInsufficientFundsFailure());
    } on bdk.CreateTxException {
      throw const SpendRefusal(SyncSpendRefusedFailure());
    } finally {
      native.dispose();
    }
    try {
      return BuiltTransaction(psbt.serialize(), decodeNativePsbt(psbt).inputs);
    } finally {
      psbt.dispose();
    }
  }

  bool _isMine(Uint8List script) {
    final native = bdk.Script(rawOutputScript: script);
    try {
      return _wallet.isMine(script: native);
    } finally {
      native.dispose();
    }
  }

  static String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  @override
  bool paysAsRequested(String psbt, BitcoinSpendRequest request) {
    final outputs = _decodePsbt(psbt).outputs;
    final fixed = <String, int>{};
    final payees = <String>{};
    for (final recipient in request.recipients) {
      final script = _script(recipient.address);
      try {
        final key = _hex(script.toBytes());
        payees.add(key);
        fixed[key] = (fixed[key] ?? 0) + (recipient.amountSat ?? 0);
      } finally {
        script.dispose();
      }
    }
    final paid = <String, int>{};
    var remainder = 0;
    for (final output in outputs) {
      final key = _hex(output.scriptPubkey);
      if (payees.contains(key)) {
        paid[key] = (paid[key] ?? 0) + output.valueSat;
      } else if (!_isMine(output.scriptPubkey)) {
        return false;
      }
    }
    for (final MapEntry(:key, :value) in fixed.entries) {
      final total = paid[key] ?? 0;
      if (total < value) return false;
      remainder += total - value;
    }
    // A remainder recipient must receive something above its fixed share.
    final drains = request.recipients.any((r) => r.amountSat == null);
    return !drains || remainder > 0;
  }

  @override
  bool keepsPayees(String psbt, String txid) {
    final native = bdk.Txid.fromString(hex: txid);
    try {
      final original = _wallet.getTx(txid: native);
      if (original == null) return false;
      final replacement = {
        for (final output in _decodePsbt(psbt).outputs)
          _hex(output.scriptPubkey),
      };
      for (final output in original.transaction.output()) {
        final script = output.scriptPubkey.toBytes();
        if (!_isMine(script) && !replacement.contains(_hex(script))) {
          return false;
        }
      }
      return true;
    } finally {
      native.dispose();
    }
  }

  static ({List<({Uint8List scriptPubkey, int valueSat})> outputs}) _decodePsbt(
    String encoded,
  ) {
    final psbt = bdk.Psbt(psbtBase64: encoded);
    try {
      return (
        outputs: [
          for (final output in decodeNativePsbt(psbt).outputs)
            (
              scriptPubkey: Uint8List.fromList(output.scriptPubkey),
              valueSat: output.valueSat,
            ),
        ],
      );
    } finally {
      psbt.dispose();
    }
  }

  /// GHSA-6jp4-8v48-cc5v: a malicious Electrum server can plant a mempool
  /// copy of a broadcast with redirected outputs. SIGHASH_ALL signatures
  /// commit to the outputs, so the wallet's own input signatures authenticate
  /// them. Inputs of unknown prevout are skipped; at least one owned input
  /// must verify. Sound for legacy and segwit v0 only: taproot commits to
  /// every prevout and needs this loop revisited.
  @override
  Future<SignatureCheck> originalSignatures(String txid) async {
    final native = bdk.Txid.fromString(hex: txid);
    final bdk.CanonicalTx? canonical;
    try {
      canonical = _wallet.getTx(txid: native);
    } finally {
      native.dispose();
    }
    if (canonical == null) return SignatureCheck.unverifiable;
    final tx = canonical.transaction;
    final inputs = tx.input();
    final toVerify = <bull_sdk.TxInputToVerify>[];
    for (var index = 0; index < inputs.length; index++) {
      final outpoint = inputs[index].previousOutput;
      final parent = _wallet.getTx(txid: outpoint.txid);
      if (parent == null) continue;
      final outputs = parent.transaction.output();
      if (outpoint.vout >= outputs.length) return SignatureCheck.unverifiable;
      final prevout = outputs[outpoint.vout];
      if (!_wallet.isMine(script: prevout.scriptPubkey)) continue;
      toVerify.add(
        bull_sdk.TxInputToVerify(
          inputIndex: index,
          prevoutScriptPubkey: prevout.scriptPubkey.toBytes(),
          prevoutValueSat: BigInt.from(prevout.value.toSat()),
        ),
      );
    }
    if (toVerify.isEmpty) return SignatureCheck.unverifiable;
    return switch (await bull_sdk.verifyTxInputSignatures(
      txBytes: tx.serialize(),
      inputs: toVerify,
    )) {
      bull_sdk.TxSignatureVerification_Valid() => SignatureCheck.valid,
      bull_sdk.TxSignatureVerification_InvalidSignatures() =>
        SignatureCheck.invalid,
      // Only caller-side errors, impossible on stored bytes.
      bull_sdk.TxSignatureVerification_Malformed() =>
        SignatureCheck.unverifiable,
    };
  }

  /// Trusts the witness UTXO a Payjoin input carries and finalizes nothing:
  /// the PSBT reaches the signer as it was, derivations aside.
  static final _annotateOptions = bdk.SignOptions(
    trustWitnessUtxo: true,
    assumeHeight: null,
    allowAllSighashes: false,
    tryFinalize: false,
    signWithTapInternalKey: false,
    allowGrinding: true,
  );

  @override
  String annotate(String psbt) {
    final parsed = bdk.Psbt(psbtBase64: psbt);
    try {
      // With no key, sign only fills in the derivations it knows.
      _wallet.sign(psbt: parsed, signOptions: _annotateOptions);
      return parsed.serialize();
    } finally {
      parsed.dispose();
    }
  }

  @override
  bool persist() => _store.persist();

  @override
  void close() => _store.close();
}

/// A Liquid spend over [wallet], for package tests: the LWK library is not
/// built for unit tests.
@visibleForTesting
NativeLiquidSpend liquidSpendOver(
  lwk.Wallet wallet, {
  LiquidNetwork network = LiquidNetwork.mainnet,
}) => _LiquidSpend(wallet, () {}, network);

/// LWK reports a shortfall only as text.
const _lwkInsufficientFunds = 'InsufficientFunds';

final class _LiquidSpend implements NativeLiquidSpend {
  final lwk.Wallet _wallet;
  final void Function() _close;

  final Network _network;

  _LiquidSpend(this._wallet, this._close, this._network);

  @override
  Future<List<({Outpoint outpoint, bool confirmed})>> coins() async {
    final asset = await _wallet.policyAsset();
    return [
      for (final coin in await _wallet.utxos())
        if (coin.unblinded.asset == asset)
          (
            outpoint: (txId: coin.outpoint.txid, vout: coin.outpoint.vout),
            confirmed: coin.height != null,
          ),
    ];
  }

  Never _refuse(lwk.LwkError error, int inputs) {
    if (error.msg.contains(_lwkInsufficientFunds)) {
      throw const SpendRefusal(SyncInsufficientFundsFailure());
    }
    if (inputs > maxLiquidTransactionInputs) {
      throw const SpendRefusal(SyncConsolidationRequiredFailure());
    }
    throw error;
  }

  @override
  Future<String> build(
    LiquidSpendRequest request,
    Set<Outpoint>? inputs,
  ) async {
    // LWK takes sat/kvB; 1 sat/kwu is exactly 4 sat/kvB.
    final rate = request.fee.satPerKwu * 4.0;
    final amount = request.amountSat;
    try {
      if (inputs == null) {
        return await _wallet.buildLbtcTx(
          sats: BigInt.from(amount ?? 0),
          outAddress: request.address,
          feeRate: rate,
          drain: amount == null,
        );
      }
      return await _wallet.buildCustomTx(
        utxos: [
          for (final input in inputs)
            lwk.OutPoint(txid: input.txId, vout: input.vout),
        ],
        outputs: [
          if (amount != null)
            lwk.TxOutputSpec(
              address: request.address,
              satoshi: BigInt.from(amount),
            ),
        ],
        drainTo: amount == null ? request.address : null,
        feeRate: rate,
      );
    } on lwk.LwkError catch (error) {
      _refuse(error, inputs?.length ?? (await coins()).length);
    }
  }

  @override
  Future<List<String>> consolidate(
    ConsolidationRequest request,
    List<Outpoint> coins,
  ) async {
    final limit = request.maximumInputs.clamp(1, 250);
    final batches = (coins.length / limit).ceil();
    final batchSize = (coins.length / batches).ceil();
    final start = (await _wallet.addressLastUnused()).index;
    if (start == null) throw const NativeStoreMissing();
    final psets = <String>[];
    for (var offset = 0; offset < coins.length; offset += batchSize) {
      final address = await _wallet.address(index: start + offset ~/ batchSize);
      try {
        psets.add(
          await _wallet.buildCustomTx(
            utxos: [
              for (final coin in coins.skip(offset).take(batchSize))
                lwk.OutPoint(txid: coin.txId, vout: coin.vout),
            ],
            outputs: [],
            drainTo: address.confidential,
            feeRate: request.fee.satPerKwu * 4.0,
          ),
        );
      } on lwk.LwkError catch (error) {
        // A batch whose coins cannot pay its fee is left out.
        if (!error.msg.contains(_lwkInsufficientFunds)) rethrow;
      }
    }
    if (psets.isEmpty) {
      throw const SpendRefusal(SyncNoSpendableInputsFailure());
    }
    return psets;
  }

  @override
  Future<List<String>> consolidateAll(ConsolidationRequest request) =>
      _wallet.consolidate(
        feeRate: request.fee.satPerKwu * 4.0,
        highUtxoThreshold: request.highUtxoThreshold,
        maximumInputs: request.maximumInputs,
      );

  @override
  Future<LiquidPsetEffect> effect(String pset) async {
    final decoded = await _wallet.decodeTx(pset: pset);
    final asset = await _wallet.policyAsset();
    final balance = decoded.balances
        .where((balance) => balance.assetId == asset)
        .firstOrNull;
    if (balance == null) throw const SpendRefusal(SyncSpendRefusedFailure());
    return LiquidPsetEffect(
      policyBalanceSat: balance.value,
      feeSat: decoded.absoluteFees.toInt(),
    );
  }

  @override
  Future<BigInt> amountToAddress(String pset, String address) async {
    final network = _network;
    if (network is! LiquidNetwork) {
      throw const SpendRefusal(SyncUnsupportedNetworkFailure());
    }
    return switch (await liquidPsetAmountToAddress(
      pset,
      address,
      network: network,
      policyAsset: await _wallet.policyAsset(),
    )) {
      Ok(:final value) => value,
      Err(:final failure) => throw SpendRefusal(failure),
    };
  }

  @override
  void close() => _close();
}
