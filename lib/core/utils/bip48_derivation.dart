abstract final class Bip48Derivation {
  static const maxAccount = 0x7fffffff;

  static final _accountPath = RegExp(
    r"^m/48(?:'|h)/([0-9]+)(?:'|h)/([0-9]+)(?:'|h)/2(?:'|h)$",
  );

  static String path({required int coinType, required int account}) {
    RangeError.checkValueInInterval(account, 0, maxAccount, 'account');
    return "m/48'/$coinType'/$account'/2'";
  }

  static int? account(String? path, {required int coinType}) {
    final match = path == null ? null : _accountPath.firstMatch(path);
    if (match == null || int.tryParse(match.group(1)!) != coinType) return null;
    final account = int.tryParse(match.group(2)!);
    return account != null && account <= maxAccount ? account : null;
  }

  static bool isAccountPath(String? path) =>
      path != null && _accountPath.hasMatch(path);

  static String accountKeyExpression({
    required String masterFingerprint,
    required String derivationPath,
    required String xpub,
  }) {
    final originPath = derivationPath.startsWith('m/')
        ? derivationPath.substring(2)
        : derivationPath;
    return '[${masterFingerprint.toLowerCase()}/$originPath]$xpub';
  }
}
