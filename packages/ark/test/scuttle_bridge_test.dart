import 'dart:io';

import 'package:ark/src/rust/api/wallet.dart';
import 'package:ark/src/rust/frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart'
    show ExternalLibrary;
import 'package:test/test.dart';

class _InspectingHandler extends BaseHandler {
  bool sawOpen = false;

  @override
  Future<S> executeNormal<S, E extends Object>(NormalTask<S, E> task) {
    if (task.constMeta.debugName == 'ScuttleWallet_open') {
      sawOpen = true;
      expect(task.argMap['childMnemonic'], isNull);
    }
    return super.executeNormal(task);
  }
}

void main() {
  test('opens, closes and reopens an existing native wallet', () async {
    final library = Platform.environment['SCUTTLE_TEST_LIBRARY'];
    final dir = await Directory.systemTemp.createTemp('scuttle-bridge-test-');
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final handler = _InspectingHandler();
    final subscription = server.listen((request) async {
      if (request.uri.path != '/block-height/0') {
        request.response.statusCode = HttpStatus.notFound;
      } else {
        request.response.write(
          '0f9188f13cb7b2c71f2a335e3a4fc328bf5beb436012afca590b1a11466e2206',
        );
      }
      await request.response.close();
    });
    try {
      await ScuttleCore.init(
        externalLibrary: library == null ? null : ExternalLibrary.open(library),
        handler: handler,
      );
      Future<ScuttleWallet> open(OpenMode mode) => ScuttleWallet.open(
        network: ScuttleNetwork.regtest,
        mode: mode,
        datadir: dir.path,
        serverAddress: 'http://127.0.0.1:1',
        esploraAddress: 'http://127.0.0.1:${server.port}',
        childMnemonic: '${'abandon ' * 11}about',
        allowUnreachableServer: true,
      );
      final wallet = await open(OpenMode.new_);
      final fingerprint = await wallet.fingerprint();
      expect(await wallet.exitInventory(), isEmpty);
      expect(await wallet.confirmedReserve(), isEmpty);
      await expectLater(wallet.startExit(vtxoIds: []), throwsA(anything));
      expect(await wallet.exitInventory(), isEmpty);
      expect(handler.sawOpen, isTrue);
      await wallet.close();
      await expectLater(wallet.fingerprint(), throwsA(anything));
      final reopened = await open(OpenMode.existing);
      expect(await reopened.fingerprint(), fingerprint);
      expect(await reopened.exitInventory(), isEmpty);
      await reopened.close();
    } finally {
      ScuttleCore.dispose();
      await subscription.cancel();
      await server.close(force: true);
      await dir.delete(recursive: true);
    }
  }, timeout: const Timeout(Duration(seconds: 30)));
}
