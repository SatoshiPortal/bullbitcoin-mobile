import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/consts/configs.dart';
import 'package:bb_mobile/_pkg/error.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/storage/storage.dart';
import 'package:boltz_dart/boltz_dart.dart';

class SwapBoltz {
  SwapBoltz({
    required SecureStorage secureStorage,
  }) : _secureStorage = secureStorage;

  final SecureStorage _secureStorage;

  Future<(Invoice?, Err?)> decodeInvoice({required String invoice}) async {
    try {
      final res = await Bolt11Invoice.decode(invoice: invoice);
      final inv = Invoice.fromDecodedInvoice(res, invoice);
      return (inv, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(AllFees?, Err?)> getFeesAndLimits({
    required String boltzUrl,
    required int outAmount,
  }) async {
    try {
      final res = await AllSwapFees.estimateFee(
        boltzUrl: boltzUrl,
        outputAmount: outAmount,
      );
      return (res, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(SwapTx?, Err?)> send({
    required String mnemonic,
    required int index,
    required String invoice,
    required Chain network,
    required String electrumUrl,
    required String boltzUrl,
    required String pairHash,
  }) async {
    try {
      final res = await BtcLnBoltzSwap.newSubmarine(
        mnemonic: mnemonic,
        index: index,
        invoice: invoice,
        network: network,
        electrumUrl: electrumUrl,
        boltzUrl: boltzUrl,
        pairHash: pairHash,
      );
      final obj = res.btcLnSwap;

      final swapSensitive = res.createSwapSensitiveFromBtcLnSwap();

      //SwapTxSensitive.fromBtcLnSwap(res);
      final err = await _secureStorage.saveValue(
        key: StorageKeys.swapTxSensitive + '_' + obj.id,
        value: jsonEncode(swapSensitive.toJson()),
      );
      if (err != null) throw err;
      final swap = res.createSwapFromBtcLnSwap();
      // SwapTx.fromBtcLnSwap(res);

      return (swap, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(SwapTx?, Err?)> receive({
    required String mnemonic,
    required int index,
    required int outAmount,
    required Chain network,
    required String electrumUrl,
    required String boltzUrl,
    required String pairHash,
    required bool isLiquid,
  }) async {
    try {
      late SwapTx swapTx;
      if (!isLiquid) {
        final res = await BtcLnBoltzSwap.newReverse(
          mnemonic: mnemonic,
          index: index,
          outAmount: outAmount,
          network: network,
          electrumUrl: electrumUrl,
          boltzUrl: boltzUrl,
          pairHash: pairHash,
        );
        final obj = res.btcLnSwap;

        final swapSensitive = res.createSwapSensitiveFromBtcLnSwap();
        // SwapTxSensitive.fromBtcLnSwap(res);
        final err = await _secureStorage.saveValue(
          key: StorageKeys.swapTxSensitive + '_' + obj.id,
          value: jsonEncode(swapSensitive.toJson()),
        );
        if (err != null) throw err;
        swapTx = res.createSwapFromBtcLnSwap();
        // SwapTx.fromBtcLnSwap(res);
      } else {
        final res = await LbtcLnBoltzSwap.newReverse(
          mnemonic: mnemonic,
          index: index,
          outAmount: outAmount,
          network: network,
          electrumUrl: electrumUrl,
          boltzUrl: boltzUrl,
          pairHash: pairHash,
        );
        final obj = res.lbtcLnSwap;

        final swapSensitive = res.createSwapSensitiveFromLbtcLnSwap();
        // SwapTxSensitive.fromLbtcLnSwap(res);
        final err = await _secureStorage.saveValue(
          key: StorageKeys.swapTxSensitive + '_' + obj.id,
          value: jsonEncode(swapSensitive.toJson()),
        );
        if (err != null) throw err;
        swapTx = res.createSwapFromLbtcLnSwap();
        // SwapTx.fromLbtcLnSwap(res);
      }

      return (swapTx, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(BoltzApi?, Err?)> initializeBoltzApi() async {
    try {
      final api = await BoltzApi.newBoltzApi();

      api.initialize();

      return (api, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(BoltzApi?, Err?)> addSwapSubs({
    required BoltzApi api,
    required List<String> swapIds,
    required void Function(
      String id,
      SwapStatusResponse status,
    ) onUpdate,
  }) async {
    try {
      api.subscribeSwapStatus(swapIds).listen((event) {
        onUpdate(event.id, event);
      });
      return (api, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<(String?, Err?)> claimOrRefundSwap({
    required SwapTx swapTx,
    required Wallet wallet,
    required bool shouldRefund,
  }) async {
    try {
      final address = wallet.lastGeneratedAddress?.address;
      if (address == null || address.isEmpty) throw 'Address not found';

      final (fees, errFees) = await getFeesAndLimits(
        boltzUrl: boltzTestnet,
        outAmount: swapTx.outAmount,
      );
      if (errFees != null) throw errFees;

      final isLiquid = wallet.baseWalletType == BaseWalletType.Liquid;

      final (swapSentive, err) = await _secureStorage.getValue(
        StorageKeys.swapTxSensitive + '_' + swapTx.id,
      );
      if (err != null) throw err;

      final swapSensitive =
          SwapTxSensitive.fromJson(jsonDecode(swapSentive!) as Map<String, dynamic>);

      if (!shouldRefund) {
        final DateTime now = DateTime.now();
        final String formattedDate =
            '${now.year}-${now.month}-${now.day} ${now.hour}:${now.minute}:${now.second}:${now.millisecond}';
        final Random random = Random();
        final int randomNumber =
            random.nextInt(10000); // This will generate a random number between 0 and 9999

        print('ATTEMPT CLAIMING: $randomNumber AT: $formattedDate');
        if (isLiquid) {
          final claimFeesEstimate = fees?.lbtcReverse.claimFeesEstimate;
          if (claimFeesEstimate == null) throw 'Fees estimate not found';

          final swap = swapTx.toLbtcLnSwap(swapSensitive);

          final resp = await swap.claim(
            outAddress: address,
            absFee: claimFeesEstimate,
          );
          return (resp, null);
        }

        final claimFeesEstimate = fees?.btcSubmarine.claimFees;
        if (claimFeesEstimate == null) throw 'Fees estimate not found';

        final swap = swapTx.toBtcLnSwap(swapSensitive);

        final resp = await swap.claim(
          outAddress: address,
          absFee: claimFeesEstimate,
        );

        return (resp, null);
      }

      if (isLiquid) {
        final refundFeesEstimate = fees?.lbtcSubmarine.claimFees;
        if (refundFeesEstimate == null) throw 'Fees estimate not found';

        final swap = swapTx.toLbtcLnSwap(swapSensitive);

        final resp = await swap.refund(
          outAddress: address,
          absFee: refundFeesEstimate,
        );

        return (resp, null);
      }

      final refundFeesEstimate = fees?.lbtcReverse.claimFeesEstimate;
      if (refundFeesEstimate == null) throw 'Fees estimate not found';

      final swap = swapTx.toBtcLnSwap(swapSensitive);

      final resp = await swap.refund(
        outAddress: address,
        absFee: refundFeesEstimate,
      );

      return (resp, null);
    } catch (e) {
      return (null, Err(e.toString()));
    }
  }

  Future<Err?> deleteSwapSensitive({required String id}) async {
    try {
      final err = await _secureStorage.deleteValue(StorageKeys.swapTxSensitive + '_' + id);
      if (err != null) throw err;
      return null;
    } catch (e) {
      return Err(e.toString());
    }
  }
}

extension Btcln on BtcLnBoltzSwap {
  SwapTx createSwapFromBtcLnSwap() {
    final swap = btcLnSwap;
    return SwapTx(
      id: swap.id,
      isSubmarine: swap.kind == SwapType.Submarine,
      // network: swap.network == Chain.Testnet ? BBNetwork.Testnet : BBNetwork.LTestnet,
      network: BBNetwork.Testnet,
      walletType: (swap.network == Chain.Bitcoin || swap.network == Chain.BitcoinTestnet)
          ? BaseWalletType.Bitcoin
          : BaseWalletType.Liquid,
      redeemScript: swap.redeemScript,
      invoice: swap.invoice,
      outAmount: swap.outAmount,
      scriptAddress: swap.scriptAddress,
      electrumUrl: swap.electrumUrl,
      boltzUrl: swap.boltzUrl,
    );
  }

  SwapTxSensitive createSwapSensitiveFromBtcLnSwap() {
    final swap = btcLnSwap;
    return SwapTxSensitive(
      id: swap.id,
      value: swap.preimage.value,
      sha256: swap.preimage.sha256,
      hash160: swap.preimage.hash160,
      publicKey: swap.keys.publicKey,
      secretKey: swap.keys.secretKey,
    );
  }
}

extension Lbtcln on LbtcLnBoltzSwap {
  SwapTx createSwapFromLbtcLnSwap() {
    final swap = lbtcLnSwap;
    return SwapTx(
      id: swap.id,
      isSubmarine: swap.kind == SwapType.Submarine,
      // network: swap.network == Chain.Testnet ? BBNetwork.Testnet : BBNetwork.LTestnet,
      network: BBNetwork.Testnet,
      walletType: (swap.network == Chain.Bitcoin || swap.network == Chain.BitcoinTestnet)
          ? BaseWalletType.Bitcoin
          : BaseWalletType.Liquid,
      redeemScript: swap.redeemScript,
      invoice: swap.invoice,
      outAmount: swap.outAmount,
      scriptAddress: swap.scriptAddress,
      electrumUrl: swap.electrumUrl,
      boltzUrl: swap.boltzUrl,
      blindingKey: swap.blindingKey,
    );
  }

  SwapTxSensitive createSwapSensitiveFromLbtcLnSwap() {
    final swap = lbtcLnSwap;
    return SwapTxSensitive(
      id: swap.id,
      value: swap.preimage.value,
      sha256: swap.preimage.sha256,
      hash160: swap.preimage.hash160,
      publicKey: swap.keys.publicKey,
      secretKey: swap.keys.secretKey,
    );
  }
}

extension SwapExt on SwapTx {
  BtcLnBoltzSwap toBtcLnSwap(SwapTxSensitive sensitive) {
    final tx = this;
    return BtcLnBoltzSwap(
      BtcLnSwap(
        id: tx.id,
        redeemScript: tx.redeemScript,
        invoice: tx.invoice,
        outAmount: tx.outAmount,
        scriptAddress: tx.scriptAddress,
        electrumUrl: tx.electrumUrl.replaceAll('ssl://', ''),
        boltzUrl: tx.boltzUrl,
        kind: SwapType.Reverse,
        network: network == BBNetwork.Testnet ? Chain.BitcoinTestnet : Chain.Bitcoin,
        keys: KeyPair(
          secretKey: sensitive.secretKey,
          publicKey: sensitive.publicKey,
        ),
        preimage: PreImage(
          value: sensitive.value,
          sha256: sensitive.sha256,
          hash160: sensitive.hash160,
        ),
      ),
    );
  }

  LbtcLnBoltzSwap toLbtcLnSwap(SwapTxSensitive sensitive) {
    final tx = this;
    return LbtcLnBoltzSwap(
      LbtcLnSwap(
        id: tx.id,
        redeemScript: tx.redeemScript,
        invoice: tx.invoice,
        outAmount: tx.outAmount,
        scriptAddress: tx.scriptAddress,
        electrumUrl: tx.electrumUrl.replaceAll('ssl://', ''),
        boltzUrl: tx.boltzUrl,
        kind: SwapType.Reverse,
        network: network == BBNetwork.Testnet ? Chain.LiquidTestnet : Chain.Liquid,
        keys: KeyPair(
          secretKey: sensitive.secretKey,
          publicKey: sensitive.publicKey,
        ),
        preimage: PreImage(
          value: sensitive.value,
          sha256: sensitive.sha256,
          hash160: sensitive.hash160,
        ),
        blindingKey: tx.blindingKey ?? '',
      ),
    );
  }
}

// extension SwapTxExt on SwapStatus {
//   bool get showPending => this == SwapStatus.invoicePaid;
//   bool get showQR => this != SwapStatus.invoiceSettled || hasExpired;
//   bool get hasExpired => this == SwapStatus.swapExpired || this == SwapStatus.invoiceExpired;
//   bool get reverseSettled => this == SwapStatus.invoiceSettled;
// }
