abstract class VersionRepository {
  Future<String?> getVersion();
  Future<void> saveVersion(String version);
}
