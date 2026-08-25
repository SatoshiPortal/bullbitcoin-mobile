abstract final class SigningKeyDerivation {
  static const maxAccount = 0x7fffffff;

  static String path({required bool isTestnet, required int account}) {
    RangeError.checkValueInInterval(account, 0, maxAccount, 'account');
    return "m/48'/${isTestnet ? 1 : 0}'/$account'/2'";
  }
}
