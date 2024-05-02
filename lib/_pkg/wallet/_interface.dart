import 'package:bb_mobile/_model/address.dart';
import 'package:bb_mobile/_model/seed.dart';
import 'package:bb_mobile/_model/transaction.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/error.dart';

abstract class IWalletTransactions {
  Future<(Wallet?, Err?)> getTransactions(Wallet wallet);

  // Future<Err?> broadcastTx(String tx);

  Future<((Wallet, String)?, Err?)> broadcastTxWithWallet({
    required Wallet wallet,
    required String address,
    required Transaction transaction,
    String? note,
  });

  // Future<(Transaction?, Err?)> finalizeTx({
  //   required String psbt,
  //   required Wallet wallet,
  // });

  Future<((Wallet?, Transaction?, int?)?, Err?)> buildTx({
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

  // Future<(Wallet?, Err?)> loadUtxos(Wallet wallet);
}

abstract class IWalletSync {
  Future<Err?> syncWallet(Wallet wallet);
  void cancelSync();
}

abstract class IWalletNetwork {
  Future<Err?> createBlockChain({
    required String url,
    required bool isTestnet,
    int? stopGap,
    int? timeout,
    int? retry,
    bool? validateDomain,
  });
}

abstract class IWalletAddress {
  Future<(Wallet?, Err?)> newAddress(Wallet wallet);

  Future<(String?, Err?)> peekIndex({
    required Wallet wallet,
    required int idx,
  });

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
    required BBNetwork network,
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

  Future<(Seed?, Err?)> mnemonicSeed(
    String mnemonic,
    BBNetwork network,
  );
}
