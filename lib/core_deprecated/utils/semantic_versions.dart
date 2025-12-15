class SemanticVersions {
  static bool isLowerThan(String version1, String version2) {
    final v1 = _parseVersion(version1);
    final v2 = _parseVersion(version2);

    if (v1[0] != v2[0]) {
      return v1[0] < v2[0];
    } else if (v1[1] != v2[1]) {
      return v1[1] < v2[1];
    } else {
      return v1[2] < v2[2];
    }
  }

  static List<int> _parseVersion(String version) {
    final parts = version.split('.');
    if (parts.length != 3) {
      throw ArgumentError('Invalid version format: $version');
    }
    return parts.map(int.parse).toList();
  }
}
