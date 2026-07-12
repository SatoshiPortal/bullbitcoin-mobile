import 'package:bb_mobile/core/entities/signer_entity.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/joinstr/domain/joinstr.dart';
import 'package:flutter_test/flutter_test.dart';

Wallet _wallet({
  Network network = Network.bitcoinTestnet,
  ScriptType scriptType = ScriptType.bip84,
  SignerEntity signer = SignerEntity.local,
}) {
  return Wallet(
    origin: 'origin',
    network: network,
    xpubFingerprint: 'ffffffff',
    masterFingerprint: 'eeeeeeee',
    scriptType: scriptType,
    xpub: 'xpub',
    externalPublicDescriptor: 'wpkh([eeeeeeee/84h/1h/0h]xpub/0/*)',
    internalPublicDescriptor: 'wpkh([eeeeeeee/84h/1h/0h]xpub/1/*)',
    signer: signer,
    signerDevice: null,
    balanceSat: BigInt.zero,
  );
}

Matcher _throwsIssue(JoinstrIssue issue) =>
    throwsA(isA<JoinstrException>().having((e) => e.issue, 'issue', issue));

void main() {
  group('input eligibility window', () {
    const denomination = 100000;

    test('accepts the inclusive boundaries of denomination+500..+5000', () {
      expect(
        Joinstr.isEligibleCoin(valueSat: 100500, denominationSat: denomination),
        isTrue,
      );
      expect(
        Joinstr.isEligibleCoin(valueSat: 105000, denominationSat: denomination),
        isTrue,
      );
    });

    test('rejects a coin one satoshi outside either boundary', () {
      expect(
        Joinstr.isEligibleCoin(valueSat: 100499, denominationSat: denomination),
        isFalse,
      );
      expect(
        Joinstr.isEligibleCoin(valueSat: 105001, denominationSat: denomination),
        isFalse,
      );
    });

    test('rejects a coin equal to the denomination', () {
      expect(
        Joinstr.isEligibleCoin(
          valueSat: denomination,
          denominationSat: denomination,
        ),
        isFalse,
      );
    });

    test('rejects an oversized coin, which would otherwise burn the surplus '
        'to fees since a joinstr tx has no change output', () {
      expect(
        Joinstr.isEligibleCoin(
          valueSat: 100000000,
          denominationSat: denomination,
        ),
        isFalse,
      );
    });
  });

  group('coin selection', () {
    test('picks the cheapest eligible coin, not the first', () {
      final index = Joinstr.selectEligibleCoin(
        coinValuesSat: [104000, 100600, 103000],
        denominationSat: 100000,
      );
      expect(index, 1);
    });

    test('skips ineligible coins on either side of the window', () {
      final index = Joinstr.selectEligibleCoin(
        coinValuesSat: [100000, 500000, 102000, 100100],
        denominationSat: 100000,
      );
      expect(index, 2);
    });

    test('returns null when nothing falls inside the window', () {
      expect(
        Joinstr.selectEligibleCoin(
          coinValuesSat: [1000, 100000, 5000000],
          denominationSat: 100000,
        ),
        isNull,
      );
      expect(
        Joinstr.selectEligibleCoin(coinValuesSat: [], denominationSat: 100000),
        isNull,
      );
    });
  });

  group('electrum url parsing', () {
    test('preserves the ssl:// prefix so TLS is actually negotiated', () {
      final endpoint = Joinstr.parseElectrumUrl(
        'ssl://fulcrum.bullbitcoin.com:50002',
      );
      expect(endpoint.address, 'ssl://fulcrum.bullbitcoin.com');
      expect(endpoint.port, 50002);
    });

    test('strips a tcp:// prefix, which must stay plaintext', () {
      final endpoint = Joinstr.parseElectrumUrl('tcp://localhost:60001');
      expect(endpoint.address, 'localhost');
      expect(endpoint.port, 60001);
    });

    test('accepts a bare host:port', () {
      final endpoint = Joinstr.parseElectrumUrl('electrum.example.com:50001');
      expect(endpoint.address, 'electrum.example.com');
      expect(endpoint.port, 50001);
    });

    test('is case-insensitive on the scheme', () {
      expect(
        Joinstr.parseElectrumUrl('SSL://host:50002').address,
        'ssl://host',
      );
    });

    test(
      'rejects a url with no port, an unparseable port, or a port out of range',
      () {
        for (final url in [
          'ssl://host',
          'ssl://host:',
          'ssl://host:abc',
          'ssl://host:0',
          'ssl://host:65536',
          ':50002',
        ]) {
          expect(
            () => Joinstr.parseElectrumUrl(url),
            _throwsIssue(JoinstrIssue.invalidElectrumUrl),
            reason: url,
          );
        }
      },
    );
  });

  group('pool expiry', () {
    JoinstrPool poolExpiringAt(int unixSec) => JoinstrPool(
      id: 'p',
      rawJson: '{}',
      denominationSat: 100000,
      peers: 2,
      expiresAtUnixSec: unixSec,
      relay: 'wss://nos.lol',
      feeRateSatPerVb: 1,
      publicKey: 'pk',
    );

    test('reports the seconds remaining until an absolute expiry', () {
      final now = DateTime.utc(2026, 1, 1);
      final nowSec = now.millisecondsSinceEpoch ~/ 1000;
      expect(poolExpiringAt(nowSec + 300).secondsUntilExpiry(now), 300);
    });

    test('clamps a past expiry to zero rather than going negative', () {
      final now = DateTime.utc(2026, 1, 1);
      final nowSec = now.millisecondsSinceEpoch ~/ 1000;
      expect(poolExpiringAt(nowSec - 60).secondsUntilExpiry(now), 0);
    });
  });

  group('denomination conversion', () {
    test('converts satoshis to BTC for the pool config', () {
      expect(Joinstr.denominationBtc(100000), 0.001);
      expect(Joinstr.denominationBtc(100000000), 1.0);
    });
  });

  group('wallet support', () {
    test('accepts a locally-signed bip84 testnet bitcoin wallet', () {
      expect(() => Joinstr.assertWalletSupported(_wallet()), returnsNormally);
    });

    test('rejects a liquid wallet', () {
      expect(
        () => Joinstr.assertWalletSupported(
          _wallet(network: Network.liquidTestnet),
        ),
        _throwsIssue(JoinstrIssue.bitcoinOnly),
      );
    });

    test('rejects a watch-only wallet, which has no mnemonic to sign with', () {
      expect(
        () => Joinstr.assertWalletSupported(_wallet(signer: SignerEntity.none)),
        _throwsIssue(JoinstrIssue.watchOnlyWallet),
      );
      expect(
        () =>
            Joinstr.assertWalletSupported(_wallet(signer: SignerEntity.remote)),
        _throwsIssue(JoinstrIssue.watchOnlyWallet),
      );
    });

    test('rejects a non-bip84 wallet, since joinstr signs wpkh only', () {
      expect(
        () => Joinstr.assertWalletSupported(
          _wallet(scriptType: ScriptType.bip49),
        ),
        _throwsIssue(JoinstrIssue.unsupportedScriptType),
      );
    });

    test('rejects mainnet while the bindings cannot route over Tor', () {
      expect(
        () => Joinstr.assertWalletSupported(
          _wallet(network: Network.bitcoinMainnet),
        ),
        _throwsIssue(JoinstrIssue.mainnetNotSupported),
      );
    });
  });
}
