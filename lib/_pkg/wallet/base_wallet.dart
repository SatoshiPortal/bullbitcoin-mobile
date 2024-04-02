enum BaseWalletType { Bitcoin, Liquid, Lightning }

abstract class BaseWallet {
  String id = '';
  double balance = 0;
  bool backupTested = false;
  DateTime? lastBackupTested;

  static BaseWallet loadFromMnemonic(String mnemonic, String passphrase) {
    throw UnimplementedError();
  }

  BaseWalletType getWalletType();
  List<Map<String, dynamic>> getTransactions();
  void sync(String electrumUrl);

  dynamic toJson();
}
