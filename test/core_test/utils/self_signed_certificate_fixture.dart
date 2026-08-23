import 'dart:io';

/// Generates a short-lived self-signed certificate for TLS behavior tests.
final class SelfSignedCertificateFixture {
  final Directory _directory;
  final SecurityContext securityContext;

  SelfSignedCertificateFixture._(this._directory, this.securityContext);

  static Future<SelfSignedCertificateFixture> create() async {
    final directory = Directory.systemTemp.createTempSync('bb_self_signed');
    final result = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-keyout',
      '${directory.path}/key.pem',
      '-out',
      '${directory.path}/cert.pem',
      '-days',
      '1',
      '-nodes',
      '-subj',
      '/CN=localhost',
      '-addext',
      'subjectAltName=DNS:localhost,IP:127.0.0.1',
      '-addext',
      'basicConstraints=critical,CA:FALSE',
    ]);
    if (result.exitCode != 0) {
      throw StateError('openssl failed to build a test cert: ${result.stderr}');
    }
    return SelfSignedCertificateFixture._(
      directory,
      SecurityContext()
        ..useCertificateChain('${directory.path}/cert.pem')
        ..usePrivateKey('${directory.path}/key.pem'),
    );
  }

  void dispose() => _directory.deleteSync(recursive: true);
}
