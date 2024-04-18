import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:boltz_dart/boltz_dart.dart';

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
      preimage: swap.preimage.value,
      sha256: swap.preimage.sha256,
      hash160: swap.preimage.hash160,
      publicKey: swap.keys.publicKey,
      secretKey: swap.keys.secretKey,
      redeemScript: swap.redeemScript,
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
      preimage: swap.preimage.value,
      sha256: swap.preimage.sha256,
      hash160: swap.preimage.hash160,
      publicKey: swap.keys.publicKey,
      secretKey: swap.keys.secretKey,
      redeemScript: swap.redeemScript,
      blindingKey: swap.blindingKey,
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
          value: sensitive.preimage,
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
          value: sensitive.preimage,
          sha256: sensitive.sha256,
          hash160: sensitive.hash160,
        ),
        blindingKey: sensitive.blindingKey ?? '',
      ),
    );
  }
}
