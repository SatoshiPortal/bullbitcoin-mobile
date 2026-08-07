import 'dart:io';

/// Test fixture for the certificate-validation branches of the electrum code.
///
/// The certificate is generated with `openssl` at run time rather than
/// committed, so no private key — even a throwaway one — lives in the repo.
class SelfSignedElectrumServer {
  final Directory _dir;
  final SecurityContext securityContext;

  SelfSignedElectrumServer._(this._dir, this.securityContext);

  static Future<SelfSignedElectrumServer> create() async {
    final dir = Directory.systemTemp.createTempSync('bb_self_signed');
    final result = await Process.run('openssl', [
      'req',
      '-x509',
      '-newkey',
      'rsa:2048',
      '-keyout',
      '${dir.path}/key.pem',
      '-out',
      '${dir.path}/cert.pem',
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
    return SelfSignedElectrumServer._(
      dir,
      SecurityContext()
        ..useCertificateChain('${dir.path}/cert.pem')
        ..usePrivateKey('${dir.path}/key.pem'),
    );
  }

  void dispose() => _dir.deleteSync(recursive: true);
}

/// Answers every request with a well-formed JSON-RPC reply whose `result` is a
/// non-empty hex string — enough for the probe to call the server alive, not
/// enough to be a real transaction.
void serveElectrumStub(Stream<Socket> server) {
  server.listen(
    (socket) => socket.listen(
      (_) => socket.write('{"id":1,"result":"00"}\n'),
      onError: (_) {},
      onDone: socket.destroy,
    ),
    onError: (_) {},
  );
}
