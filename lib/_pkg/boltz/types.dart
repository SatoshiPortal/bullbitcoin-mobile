import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:boltz_dart/boltz_dart.dart';

extension Btcln on BtcLnV1Swap {
  SwapTx createSwapFromBtcLnSwap() {
    return SwapTx(
      id: id,
      isSubmarine: kind == SwapType.submarine,
      // network: network == Chain.Testnet ? BBNetwork.Testnet : BBNetwork.LTestnet,
      network: BBNetwork.Testnet,
      walletType: (network == Chain.bitcoin || network == Chain.bitcoinTestnet)
          ? BaseWalletType.Bitcoin
          : BaseWalletType.Liquid,
      redeemScript: redeemScript,
      invoice: invoice,
      outAmount: outAmount,
      scriptAddress: scriptAddress,
      electrumUrl: electrumUrl,
      boltzUrl: boltzUrl,
    );
  }

  SwapTxSensitive createSwapSensitiveFromBtcLnSwap() {
    return SwapTxSensitive(
      id: id,
      preimage: preimage.value,
      sha256: preimage.sha256,
      hash160: preimage.hash160,
      publicKey: keys.publicKey,
      secretKey: keys.secretKey,
      redeemScript: redeemScript,
    );
  }
}

extension Lbtcln on LbtcLnV1Swap {
  SwapTx createSwapFromLbtcLnSwap() {
    return SwapTx(
      id: id,
      isSubmarine: kind == SwapType.submarine,
      // network: network == Chain.Testnet ? BBNetwork.Testnet : BBNetwork.LTestnet,
      network: BBNetwork.Testnet,
      walletType: (network == Chain.bitcoin || network == Chain.bitcoinTestnet)
          ? BaseWalletType.Bitcoin
          : BaseWalletType.Liquid,
      redeemScript: redeemScript,
      invoice: invoice,
      outAmount: outAmount,
      scriptAddress: scriptAddress,
      electrumUrl: electrumUrl,
      boltzUrl: boltzUrl,
      blindingKey: blindingKey,
    );
  }

  SwapTxSensitive createSwapSensitiveFromLbtcLnSwap() {
    return SwapTxSensitive(
      id: id,
      preimage: preimage.value,
      sha256: preimage.sha256,
      hash160: preimage.hash160,
      publicKey: keys.publicKey,
      secretKey: keys.secretKey,
      redeemScript: redeemScript,
      blindingKey: blindingKey,
    );
  }
}

extension SwapExt on SwapTx {
  BtcLnV1Swap toBtcLnSwap(SwapTxSensitive sensitive) {
    final tx = this;
    return BtcLnV1Swap(
      id: tx.id,
      redeemScript: tx.redeemScript,
      invoice: tx.invoice,
      outAmount: tx.outAmount,
      scriptAddress: tx.scriptAddress,
      electrumUrl: tx.electrumUrl.replaceAll('ssl://', ''),
      boltzUrl: tx.boltzUrl,
      kind: SwapType.reverse,
      network: network == BBNetwork.Testnet ? Chain.bitcoinTestnet : Chain.bitcoin,
      keys: KeyPair(
        secretKey: sensitive.secretKey,
        publicKey: sensitive.publicKey,
      ),
      preimage: PreImage(
        value: sensitive.preimage,
        sha256: sensitive.sha256,
        hash160: sensitive.hash160,
      ),
    );
  }

  LbtcLnV1Swap toLbtcLnSwap(SwapTxSensitive sensitive) {
    final tx = this;
    return LbtcLnV1Swap(
      id: tx.id,
      redeemScript: tx.redeemScript,
      invoice: tx.invoice,
      outAmount: tx.outAmount,
      scriptAddress: tx.scriptAddress,
      electrumUrl: tx.electrumUrl.replaceAll('ssl://', ''),
      boltzUrl: tx.boltzUrl,
      kind: SwapType.reverse,
      network: network == BBNetwork.Testnet ? Chain.liquidTestnet : Chain.liquid,
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
    );
  }
}
