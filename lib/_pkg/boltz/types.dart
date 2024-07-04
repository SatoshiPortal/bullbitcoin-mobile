import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:boltz_dart/boltz_dart.dart';

extension LnSwapExt on SwapTx {
  BtcLnSwap toBtcLnSwap(LnSwapTxSensitive sensitive) {
    final tx = this;
    return BtcLnSwap(
      id: tx.id,
      invoice: tx.lnSwapDetails!.invoice,
      outAmount: tx.outAmount,
      scriptAddress: tx.scriptAddress,
      electrumUrl: tx.lnSwapDetails!.electrumUrl.replaceAll('ssl://', ''),
      boltzUrl: tx.boltzUrl,
      kind: tx.lnSwapDetails!.swapType,
      keyIndex: tx.lnSwapDetails!.keyIndex,
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
        swapType: tx.lnSwapDetails!.swapType,
        hashlock: sensitive.hash160,
        receiverPubkey: tx.isSubmarine()
            ? tx.lnSwapDetails!.boltzPubKey
            : tx.lnSwapDetails!.myPublicKey,
        locktime: tx.lnSwapDetails!.locktime,
        senderPubkey: tx.isSubmarine()
            ? tx.lnSwapDetails!.myPublicKey
            : tx.lnSwapDetails!.boltzPubKey,
        fundingAddrs: tx.scriptAddress,
      ),
    );
  }

  LbtcLnSwap toLbtcLnSwap(LnSwapTxSensitive sensitive) {
    final tx = this;
    return LbtcLnSwap(
      id: tx.id,
      invoice: tx.lnSwapDetails!.invoice,
      outAmount: tx.outAmount,
      scriptAddress: tx.scriptAddress,
      electrumUrl: tx.lnSwapDetails!.electrumUrl.replaceAll('ssl://', ''),
      boltzUrl: tx.boltzUrl,
      kind: tx.lnSwapDetails!.swapType,
      keyIndex: tx.lnSwapDetails!.keyIndex,
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
        swapType: tx.lnSwapDetails!.swapType,
        hashlock: sensitive.hash160,
        receiverPubkey: tx.isSubmarine()
            ? tx.lnSwapDetails!.boltzPubKey
            : tx.lnSwapDetails!.myPublicKey,
        locktime: tx.lnSwapDetails!.locktime,
        senderPubkey: tx.isSubmarine()
            ? tx.lnSwapDetails!.myPublicKey
            : tx.lnSwapDetails!.boltzPubKey,
        fundingAddrs: tx.scriptAddress,
        blindingKey: sensitive.blindingKey ?? '',
      ),
    );
  }
}

extension BtcLnSwapExt on BtcLnSwap {
  SwapTx createSwapFromBtcLnSwap() {
    return SwapTx(
      id: id,
      lnSwapDetails: LnSwapDetails(
        swapType: kind,
        invoice: invoice,
        boltzPubKey: kind == SwapType.submarine
            ? swapScript.receiverPubkey
            : swapScript.senderPubkey,
        keyIndex:
            0, // this is an issue, we should probably also save the keyIndex in BtcLnSwap
        myPublicKey: kind == SwapType.submarine
            ? swapScript.senderPubkey
            : swapScript.receiverPubkey,
        sha256: '',
        electrumUrl: electrumUrl,
        locktime: swapScript.locktime,
      ),
      // network: network == Chain.Testnet ? BBNetwork.Testnet : BBNetwork.LTestnet,
      network: network == Chain.liquidTestnet
          ? BBNetwork.Testnet
          : BBNetwork.Mainnet,
      baseWalletType:
          (network == Chain.bitcoin || network == Chain.bitcoinTestnet)
              ? BaseWalletType.Bitcoin
              : BaseWalletType.Liquid,
      outAmount: outAmount,
      scriptAddress: scriptAddress,
      boltzUrl: boltzUrl,
      creationTime: DateTime.now(),
    );
  }

  LnSwapTxSensitive createSwapSensitiveFromBtcLnSwap() {
    return LnSwapTxSensitive(
      id: id,
      preimage: preimage.value,
      sha256: preimage.sha256,
      hash160: preimage.hash160,
      publicKey: keys.publicKey,
      secretKey: keys.secretKey,
      boltzPubkey: kind == SwapType.submarine
          ? swapScript.receiverPubkey
          : swapScript.senderPubkey,
      locktime: swapScript.locktime,
      isSubmarine: kind == SwapType.submarine,
    );
  }
}

extension LbtcLnSwapExt on LbtcLnSwap {
  SwapTx createSwapFromLbtcLnSwap() {
    return SwapTx(
      id: id,
      lnSwapDetails: LnSwapDetails(
        swapType: kind,
        invoice: invoice,
        boltzPubKey: kind == SwapType.submarine
            ? swapScript.receiverPubkey
            : swapScript.senderPubkey,
        keyIndex:
            0, // this is an issue, we should probably also save the keyIndex in BtcLnSwap
        myPublicKey: kind == SwapType.submarine
            ? swapScript.senderPubkey
            : swapScript.receiverPubkey,
        sha256: '',
        electrumUrl: electrumUrl,
        locktime: swapScript.locktime,
        blindingKey: swapScript.blindingKey,
      ),
      // network: network == Chain.Testnet ? BBNetwork.Testnet : BBNetwork.LTestnet,
      network: network == Chain.liquidTestnet
          ? BBNetwork.Testnet
          : BBNetwork.Mainnet,
      baseWalletType:
          (network == Chain.bitcoin || network == Chain.bitcoinTestnet)
              ? BaseWalletType.Bitcoin
              : BaseWalletType.Liquid,
      outAmount: outAmount,
      scriptAddress: scriptAddress,
      boltzUrl: boltzUrl,
      creationTime: DateTime.now(),
    );
  }

  LnSwapTxSensitive createSwapSensitiveFromLbtcLnSwap() {
    return LnSwapTxSensitive(
      id: id,
      preimage: preimage.value,
      sha256: preimage.sha256,
      hash160: preimage.hash160,
      publicKey: keys.publicKey,
      secretKey: keys.secretKey,
      blindingKey: blindingKey,
      boltzPubkey: kind == SwapType.submarine
          ? swapScript.receiverPubkey
          : swapScript.senderPubkey,
      locktime: swapScript.locktime,
      isSubmarine: kind == SwapType.submarine,
    );
  }
}
