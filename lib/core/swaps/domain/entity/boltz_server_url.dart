final class BoltzServerUrl {
  final Uri uri;

  const BoltzServerUrl._(this.uri);

  factory BoltzServerUrl.parse(String value) {
    final parsed = Uri.tryParse(value.trim());
    if (parsed == null ||
        parsed.scheme != 'https' ||
        !parsed.hasAuthority ||
        parsed.host.isEmpty ||
        parsed.userInfo.isNotEmpty ||
        parsed.hasQuery ||
        parsed.hasFragment) {
      throw const FormatException('Invalid Boltz server URL');
    }

    final path = switch (parsed.path) {
      '' || '/' => '/v2',
      final path => path.replaceFirst(RegExp(r'/+$'), ''),
    };
    if (path.split('/').contains('..')) {
      throw const FormatException('Invalid Boltz server URL');
    }

    return BoltzServerUrl._(parsed.replace(path: path));
  }

  static BoltzServerUrl? tryParse(String value) {
    try {
      return BoltzServerUrl.parse(value);
    } on FormatException {
      return null;
    }
  }

  @override
  String toString() => uri.toString();

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is BoltzServerUrl && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;
}

BoltzServerUrl? boltzServerUrlFromJson(String? value) =>
    value == null ? null : BoltzServerUrl.parse(value);

String? boltzServerUrlToJson(BoltzServerUrl? value) => value?.toString();
