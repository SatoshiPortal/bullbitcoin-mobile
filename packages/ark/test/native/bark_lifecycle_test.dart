import 'dart:io';

import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_writer_lock.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

void main() {
  test(
    'real native offline fixture opens closes and reopens without daemon',
    () async {
      const genesis =
          '0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206';
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final temp = Directory.systemTemp.createTempSync('ark-native-smoke-');
      final admission = ArkWriterLock.acquire('${temp.path}/writer.sqlite');
      final lock = (admission as Ok<ArkWriterLock, ArkWalletFailure>).value;
      bark.OnchainWallet? onchain;
      bark.Wallet? wallet;
      server.listen((request) async {
        final body = switch (request.uri.path) {
          '/block-height/0' || '/blocks/tip/hash' => genesis,
          '/blocks/tip/height' => '0',
          '/fee-estimates' => '{"1":1,"2":1,"6":1,"144":1}',
          _ => null,
        };
        if (body == null) {
          request.response.statusCode = 404;
        } else {
          request.response.write(body);
        }
        await request.response.close();
      });
      try {
        // Public BIP39 zero-entropy fixture; never a funded account.
        final child = Mnemonic(
          List<int>.filled(16, 0),
          Language.english,
        ).sentence;
        expect(bark.validateMnemonic(mnemonic: child), isTrue);
        const expected = '53bdf6b1';
        final endpoint = 'http://127.0.0.1:${server.port}';
        final config = bark.Config(
          serverAddress: endpoint,
          esploraAddress: endpoint,
        );
        final path = '${temp.path}/native';
        onchain = await bark.OnchainWallet.default_(
          network: bark.Network.regtest,
          mnemonic: child,
          config: config,
          datadir: path,
        );
        wallet = await bark.Wallet.open(
          network: bark.Network.regtest,
          mnemonicOrSeed: child,
          config: config,
          args: bark.WalletOpenArgs(
            runDaemon: false,
            datadir: path,
            onchain: onchain,
            createIfNotExists: true,
            createWithoutServer: true,
          ),
        );
        expect(wallet.fingerprint() == expected, isTrue);
        expect(wallet.recoveryStatus() is bark.NotRunRecoveryStatus, isFalse);
        wallet.dispose();
        wallet = null;
        onchain.dispose();
        onchain = null;
        final metadata = bark.readDatadirInfo(datadir: path);
        expect(metadata?.network, bark.Network.regtest);
        expect(metadata?.fingerprint == expected, isTrue);
        onchain = await bark.OnchainWallet.default_(
          network: bark.Network.regtest,
          mnemonic: child,
          config: config,
          datadir: path,
        );
        wallet = await bark.Wallet.open(
          network: bark.Network.regtest,
          mnemonicOrSeed: child,
          config: config,
          args: bark.WalletOpenArgs(
            runDaemon: false,
            datadir: path,
            onchain: onchain,
            createIfNotExists: false,
          ),
        );
        expect(wallet.fingerprint() == expected, isTrue);
        expect(wallet.recoveryStatus(), isA<bark.NotRunRecoveryStatus>());
      } finally {
        try {
          wallet?.dispose();
        } finally {
          onchain?.dispose();
          lock.release();
          await server.close(force: true);
          temp.deleteSync(recursive: true);
        }
      }
    },
  );
}
