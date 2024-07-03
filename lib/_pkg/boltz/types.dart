import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:boltz_dart/boltz_dart.dart';

extension SwapExt on SwapTx {
  BtcLnSwap toBtcLnSwap(SwapTxSensitive sensitive) {
    final tx = this;
    return BtcLnSwap(
      id: tx.id,
      invoice: tx.invoice,
      outAmount: tx.outAmount,
      scriptAddress: tx.scriptAddress,
      electrumUrl: tx.electrumUrl.replaceAll('ssl://', ''),
      boltzUrl: tx.boltzUrl,
      kind: tx.isSubmarine ? SwapType.submarine : SwapType.reverse,
      network:
          network == BBNetwork.Testnet ? Chain.bitcoinTestnet : Chain.bitcoin,
      keys: KeyPair(
        secretKey: sensitive.secretKey,
        publicKey: sensitive.publicKey,
      ),
      preimage: PreImage(
        value: sensitive.preimage,
        sha256: sensitive.sha256,
        hash160: sensitive.hash160,
      ),
      swapScript: BtcSwapScriptStr(
        swapType: tx.isSubmarine ? SwapType.submarine : SwapType.reverse,
        hashlock: sensitive.hash160,
        receiverPubkey: tx.isSubmarine ? tx.boltzPubkey! : tx.publicKey!,
        locktime: tx.locktime!,
        senderPubkey: tx.isSubmarine ? tx.publicKey! : tx.boltzPubkey!,
        fundingAddrs: tx.scriptAddress,
      ),
    );
  }

  LbtcLnSwap toLbtcLnSwap(SwapTxSensitive sensitive) {
    final tx = this;
    return LbtcLnSwap(
      id: tx.id,
      invoice: tx.invoice,
      outAmount: tx.outAmount,
      scriptAddress: tx.scriptAddress,
      electrumUrl: tx.electrumUrl.replaceAll('ssl://', ''),
      boltzUrl: tx.boltzUrl,
      kind: tx.isSubmarine ? SwapType.submarine : SwapType.reverse,
      network:
          network == BBNetwork.Testnet ? Chain.liquidTestnet : Chain.liquid,
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
      swapScript: LBtcSwapScriptStr(
        swapType: tx.isSubmarine ? SwapType.submarine : SwapType.reverse,
        hashlock: sensitive.hash160,
        receiverPubkey:
            tx.isSubmarine ? tx.boltzPubkey ?? '' : sensitive.publicKey,
        locktime: tx.locktime ?? 0,
        senderPubkey:
            tx.isSubmarine ? sensitive.publicKey : tx.boltzPubkey ?? '',
        blindingKey: sensitive.blindingKey ?? '',
        fundingAddrs: tx.scriptAddress,
      ),
    );
  }
}

extension BtcLn on BtcLnSwap {
  SwapTx createSwapFromBtcLnSwap() {
    return SwapTx(
      id: id,
      isSubmarine: kind == SwapType.submarine,
      // network: network == Chain.Testnet ? BBNetwork.Testnet : BBNetwork.LTestnet,
      network: network == Chain.liquidTestnet
          ? BBNetwork.Testnet
          : BBNetwork.Mainnet,
      walletType: (network == Chain.bitcoin || network == Chain.bitcoinTestnet)
          ? BaseWalletType.Bitcoin
          : BaseWalletType.Liquid,
      redeemScript: 'redeemScript',
      invoice: invoice,
      outAmount: outAmount,
      scriptAddress: scriptAddress,
      electrumUrl: electrumUrl,
      boltzUrl: boltzUrl,
      boltzPubkey: kind == SwapType.submarine
          ? swapScript.receiverPubkey
          : swapScript.senderPubkey,
      publicKey: kind == SwapType.submarine
          ? swapScript.senderPubkey
          : swapScript.receiverPubkey,
      locktime: swapScript.locktime,
      creationTime: DateTime.now(),
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
      redeemScript: 'redeemScript',
      boltzPubkey: kind == SwapType.submarine
          ? swapScript.receiverPubkey
          : swapScript.senderPubkey,
      locktime: swapScript.locktime,
      isSubmarine: kind == SwapType.submarine,
    );
  }
}

extension LbtcLn on LbtcLnSwap {
  SwapTx createSwapFromLbtcLnSwap() {
    return SwapTx(
      id: id,
      isSubmarine: kind == SwapType.submarine,
      // network: network == Chain.Testnet ? BBNetwork.Testnet : BBNetwork.LTestnet,
      network: network == Chain.liquidTestnet
          ? BBNetwork.Testnet
          : BBNetwork.Mainnet,
      walletType: (network == Chain.bitcoin || network == Chain.bitcoinTestnet)
          ? BaseWalletType.Bitcoin
          : BaseWalletType.Liquid,
      redeemScript: 'redeemScript',
      invoice: invoice,
      outAmount: outAmount,
      scriptAddress: scriptAddress,
      electrumUrl: electrumUrl,
      boltzUrl: boltzUrl,
      blindingKey: blindingKey,
      boltzPubkey: kind == SwapType.submarine
          ? swapScript.receiverPubkey
          : swapScript.senderPubkey,
      publicKey: kind == SwapType.submarine
          ? swapScript.senderPubkey
          : swapScript.receiverPubkey,
      locktime: swapScript.locktime,
      creationTime: DateTime.now(),
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
      redeemScript: 'redeemScript',
      blindingKey: blindingKey,
      boltzPubkey: kind == SwapType.submarine
          ? swapScript.receiverPubkey
          : swapScript.senderPubkey,
      locktime: swapScript.locktime,
      isSubmarine: kind == SwapType.submarine,
    );
  }
}
