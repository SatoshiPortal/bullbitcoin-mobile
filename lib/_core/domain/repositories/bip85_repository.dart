abstract class Bip85Repository {
  List<int> derive(String xprv, String path);
  String generateBackupKeyPath();
}
