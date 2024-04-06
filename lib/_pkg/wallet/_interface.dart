import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';

abstract class IWalletTransactions {
  Future<(Wallet?, Err?)> getTransactions(Wallet wallet);

  Future<Err?> broadcastTx(Transaction tx);

  Future<((Wallet, String)?, Err?)> broadcastTxWithWallet({
    required String tx,
    required Wallet wallet,
    required String address,
    required Transaction transaction,
    String? note,
  });

  Future<(Transaction?, Err?)> finalizeTx({
    required String psbt,
    required Wallet wallet,
  });

  Future<((Transaction?, int?, String)?, Err?)> buildTx({
    required Wallet wallet,
    required String address,
    required int? amount,
    required bool sendAllCoin,
    required double feeRate,
    String? note,
    required bool isManualSend,
    required bool enableRbf,
    List<UTXO>? selectedUtxos,
  });

  Future<(Wallet?, Err?)> loadUtxos(Wallet wallet);
}

abstract class IWalletSync {
  Future<Err?> syncWallet(Wallet wallet);
  void cancelSync();
}

abstract class IWalletNetwork {
  Future<Err?> createBlockChain({
    required int stopGap,
    required int timeout,
    required int retry,
    required String url,
    required bool validateDomain,
  });
}

abstract class IWalletAddress {
  Future<(Wallet?, Err?)> loadAddresses(Wallet wallet);

  Future<(Wallet?, Err?)> loadChangeAddresses(Wallet wallet);

  Future<(Wallet?, Err?)> newAddress(Wallet wallet);

  Future<(String?, Err?)> peekIndex({
    required Wallet wallet,
    required int idx,
  });

  Future<(Wallet?, Err?)> updateUtxoAddresses(Wallet wallet);

  Future<(Address, Wallet)> addAddressToWallet({
    required (int?, String) address,
    required Wallet wallet,
    String? label,
    String? spentTxId,
    required AddressKind kind,
    AddressStatus state = AddressStatus.unused,
    bool spendable = true,
  });
}

abstract class IWalletBalance {
  Future<((Wallet, Balance)?, Err?)> getBalance(Wallet wallet);
}

abstract class IWalletCreate {
  Future<(Wallet?, Err?)> loadPublicWallet({
    required String saveDir,
    Wallet? wallet,
  });
}

abstract class IWalletSensitiveTx {
  Future<(String?, Err?)> signTx({
    required String unsignedTx,
    required Wallet wallet,
  });

  Future<(Transaction?, Err?)> buildBumpFeeTx({
    required Transaction tx,
    required double feeRate,
    required Wallet wallet,
  });
}

abstract class IWalletSensitiveCreate {
  Future<(List<String>?, Err?)> createMnemonic();

  Future<(String?, Err?)> getFingerprint({
    required String mnemonic,
    String? passphrase,
  });
}
