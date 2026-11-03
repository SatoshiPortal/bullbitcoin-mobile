import 'dart:io';

import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:bull_ark/bull_ark.dart';
import 'package:bull_ark/src/data/bark_wallet_datasource.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

/// A dead server, so nothing here touches the network.
final _offline = ArkServerConfig(
  network: BitcoinNetwork.signet,
  serverUrl: Uri.parse('http://127.0.0.1:1'),
  esploraUrl: Uri.parse('http://127.0.0.1:1'),
);

class _FakeDatasource extends BarkWalletDatasource {
  final bark.Balance stubbedBalance;

  _FakeDatasource(this.stubbedBalance);

  @override
  Future<bark.Balance> balance() async => stubbedBalance;
}

void main() {
  group('against the native library', () {
    late Directory datadir;
    late BarkWalletRepository repository;

    setUp(() {
      datadir = Directory.systemTemp.createTempSync('bull-ark-');
      repository = BarkWalletRepository();
    });

    tearDown(() async {
      await repository.close();
      datadir.deleteSync(recursive: true);
    });

    test('calls before open fail as not open', () async {
      expect(await repository.balance(), isA<Err<ArkBalance, ArkFailure>>());
      final result = await repository.newReceiveAddress();
      expect(
        (result as Err<String, ArkFailure>).failure,
        isA<ArkWalletNotOpenFailure>(),
      );
    });

    test(
      'an unreachable server comes back as a failure, not a throw',
      () async {
        final result = await repository.open(
          mnemonic: bark.generateMnemonic(),
          config: _offline,
          datadir: datadir.path,
        );
        expect(
          (result as Err<void, ArkFailure>).failure,
          isA<ArkOperationFailure>(),
        );
      },
    );
  });

  test('pending sends are summed into one figure', () async {
    final repository = BarkWalletRepository(
      datasource: _FakeDatasource(
        bark.Balance(
          spendableSats: 1000,
          needsRefreshSats: 100,
          pendingInRoundSats: 10,
          pendingExitSats: 20,
          pendingLightningSendSats: 1,
          claimableLightningReceiveSats: 30,
          pendingBoardSats: 40,
          pendingArkoorSendSats: 2,
          pendingOffboardSats: 4,
        ),
      ),
    );

    final result = await repository.balance();

    expect(
      (result as Ok<ArkBalance, ArkFailure>).value,
      const ArkBalance(
        spendableSats: 1000,
        needsRefreshSats: 100,
        pendingBoardSats: 40,
        pendingInRoundSats: 10,
        pendingExitSats: 20,
        pendingSendSats: 7,
        claimableLightningReceiveSats: 30,
      ),
    );
  });
}
