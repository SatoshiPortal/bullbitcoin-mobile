import 'dart:convert';
import 'dart:typed_data';

import 'package:rust_bindings/bdk.dart' as bdk;
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:sync/sync.dart';

// Synthetic one-input, one-output transaction paying 100000 sat to OP_TRUE.
const _transactionHex =
    '0100000001${'00000000000000000000000000000000'
        '00000000000000000000000000000000'}'
    'ffffffff020101ffffffff01a0860100000000000151'
    '00000000';

// Version 2, one input (txid 0x01..0x20 reversed, vout 0, sequence
// 0xfffffffd) carrying a 100200 sat witness UTXO, one 100000 sat P2WPKH
// output: a 200 sat fee.
const _psbt =
    'cHNidP8BAFICAAAAAQECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gAAAAAAD9////'
    'AaCGAQAAAAAAFgAUIiIiIiIiIiIiIiIiIiIiIiIiIiIAAAAAAAEBH2iHAQAAAAAAFgAUMzMz'
    'MzMzMzMzMzMzMzMzMzMzMzMAAA==';

List<int> _fromHex(String hex) => [
  for (var i = 0; i < hex.length; i += 2)
    int.parse(hex.substring(i, i + 2), radix: 16),
];

String _toHex(List<int> bytes) =>
    bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

final _p2wpkh = Uint8List.fromList([0, 20, ...List.filled(20, 0x22)]);

T _ok<T>(Result<T, SyncFailure> result) => switch (result) {
  Ok(:final value) => value,
  Err(:final failure) => throw TestFailure('Unexpected ${failure.logCode}'),
};

SyncFailure _err<T>(Result<T, SyncFailure> result) => switch (result) {
  Ok() => throw TestFailure('Unexpected success'),
  Err(:final failure) => failure,
};

/// [_psbt]'s unsigned transaction, with [lockTime] as little-endian hex.
String _unsignedHex({String lockTime = '00000000'}) =>
    '0200000001${_toHex(List.generate(32, (i) => i + 1))}00000000'
    '00fdffffff01a086010000000000160014${'22' * 20}$lockTime';

/// A PSBT of [_unsignedHex] whose input carries no amount.
String _psbtWithoutInputAmount({String lockTime = '00000000'}) {
  final transaction = bdk.Transaction(
    transactionBytes: Uint8List.fromList(
      _fromHex(_unsignedHex(lockTime: lockTime)),
    ),
  );
  final psbt = bdk.Psbt.fromUnsignedTx(tx: transaction);
  try {
    return psbt.serialize();
  } finally {
    psbt.dispose();
    transaction.dispose();
  }
}

void main() {
  group('decodeBitcoinTransaction', () {
    test('reads every field of a serialized transaction', () {
      final decoded = (decodeBitcoinTransaction(_fromHex(_transactionHex)));
      final native = bdk.Transaction(
        transactionBytes: Uint8List.fromList(_fromHex(_transactionHex)),
      );
      addTearDown(native.dispose);

      expect(decoded.txid, native.computeTxid().toString());
      expect(decoded.version, 1);
      expect(decoded.locktime, 0);
      expect(decoded.size, _transactionHex.length ~/ 2);
      expect(decoded.vsize, _transactionHex.length ~/ 2);
      expect(decoded.inputs, hasLength(1));
      expect(decoded.inputs.single, (txId: '0' * 64, vout: 0xffffffff));
      expect(decoded.inputDetails.single.outpoint, decoded.inputs.single);
      expect(decoded.inputDetails.single.sequence, 0xffffffff);
      expect(decoded.inputDetails.single.scriptSig, [0x01, 0x01]);
      expect(decoded.outputs.single.valueSat, 100000);
      expect(decoded.outputs.single.scriptPubkey, [0x51]);
      expect(_toHex(decoded.bytes), _transactionHex);
    });

    test('publishes immutable values', () {
      final decoded = (decodeBitcoinTransaction(_fromHex(_transactionHex)));
      expect(() => decoded.bytes[0] = 2, throwsUnsupportedError);
      expect(() => decoded.inputs.clear(), throwsUnsupportedError);
      expect(() => decoded.inputDetails.clear(), throwsUnsupportedError);
      expect(
        () => decoded.outputs.single.scriptPubkey[0] = 0,
        throwsUnsupportedError,
      );
    });

    for (final (name, bytes) in <(String, List<int>)>[
      ('no bytes', const []),
      ('a truncated transaction', _fromHex(_transactionHex.substring(0, 40))),
      ('trailing bytes', [..._fromHex(_transactionHex), 0]),
      ('random bytes', List.generate(64, (i) => i * 7 % 256)),
      ('a PSBT', base64.decode(_psbt)),
    ]) {
      test('refuses $name', () {
        expect(() => decodeBitcoinTransaction(bytes), throwsFormatException);
      });
    }

    test('refuses more bytes than any valid transaction holds', () {
      expect(
        () =>
            decodeBitcoinTransaction(Uint8List(maxBitcoinTransactionBytes + 1)),
        throwsFormatException,
      );
    });
  });

  group('decodeBitcoinPsbt', () {
    test('reads the transaction the PSBT describes', () {
      final decoded = (decodeBitcoinPsbt(_psbt));
      expect(decoded.version, 2);
      expect(decoded.locktime, 0);
      expect(decoded.inputs.single, (
        txId: _toHex(List.generate(32, (i) => 32 - i)),
        vout: 0,
      ));
      expect(decoded.inputDetails.single.sequence, 0xfffffffd);
      expect(decoded.inputDetails.single.scriptSig, isEmpty);
      expect(decoded.outputs.single.valueSat, 100000);
      expect(decoded.outputs.single.scriptPubkey, _p2wpkh);
    });

    test('refuses a PSBT without its input amounts', () {
      expect(
        () => decodeBitcoinPsbt(_psbtWithoutInputAmount()),
        throwsFormatException,
      );
    });

    for (final (name, input) in [
      ('an empty string', ''),
      ('text', 'not a psbt'),
      ('a hex transaction', _transactionHex),
      ('a truncated PSBT', _psbt.substring(0, 40)),
      (
        'a PSBT without its magic',
        base64.encode(base64.decode(_psbt).skip(5).toList()),
      ),
      ('an oversized string', 'A' * (maxEncodedBitcoinPsbtLength + 1)),
    ]) {
      test('refuses $name', () {
        expect(() => decodeBitcoinPsbt(input), throwsFormatException);
      });
    }
  });

  group('canonicalBitcoinPsbt', () {
    test('returns a valid PSBT re-serialized', () {
      expect(_ok(canonicalBitcoinPsbt(_psbt)), _psbt);
    });

    test('accepts a PSBT without input amounts: nothing is extracted', () {
      final psbt = _psbtWithoutInputAmount();
      expect(_ok(canonicalBitcoinPsbt(psbt)), psbt);
    });

    test('refuses what is not a PSBT', () {
      expect(
        _err(canonicalBitcoinPsbt(base64.encode(utf8.encode('psbt')))),
        isA<SyncInvalidTransactionFailure>(),
      );
    });
  });

  group('finalizeBitcoinPsbts', () {
    // A 2-of-2 multisig spend of three inputs, and the two signers' replies
    // trimmed of input data, as SeedSigner returns them.
    const unsigned =
        'cHNidP8BAKQCAAAAA6DLc9RAdKwWQb/7Nrq1FyAtDQ3e0w5E4LkLpcrwBL0aAAAAAAD9////78NG2vqjywKaa0QHfo6C44o1+odXeWZ43FfHy4bLdxABAAAAAP3///8rhueJha90HzgJ6alnJ1uvi0Zbq0JQoXnwDb0Cjn79DwAAAAAA/f///wHWCBAAAAAAABYAFDraKFKubXzlSvRQy8V4X+TwKhLXAAAAAE8BBDWHzwQJeplqgAAAAqmHnnoRR+XJd7gJt/PhLazKeWAfCBLJ4/OF/s0PqqF1AzK8fcttOUsU2k9a6Valj6kLb/Bh2gB7YuxenNz7LY5PFJkKc60wAACAAQAAgAAAAIACAACATwEENYfPBEgFouKAAAACOeERUyCmIJuSdQNDB1mxkahw4tc2UCtjxJQoQGnRCtQCZUSXwQF+nA8dl/RG6U1b9ViWJxkzNrDCCagYEWch72cUrnhJ4jAAAIABAACAAAAAgAIAAIAAAQErckUPAAAAAAAiACDwHjagvyTvVDVn+RqxW0xaMLODBm2IVCwDBQm5uK8rDQEFR1IhAi/hk/Tz0aHcNwsVyv86bqQj30sUexPlc738CqJg+flLIQKmgeTdVjPh9P+MPnsTPbFRcGGLPAO3iTyYBR7eYQC4VlKuIgYCL+GT9PPRodw3CxXK/zpupCPfSxR7E+VzvfwKomD5+UscrnhJ4jAAAIABAACAAAAAgAIAAIABAAAACgAAACIGAqaB5N1WM+H0/4w+exM9sVFwYYs8A7eJPJgFHt5hALhWHJkKc60wAACAAQAAgAAAAIACAACAAQAAAAoAAAAAAQErMHUAAAAAAAAiACAUS+ztgOw4wxEOYDdQEZp42Ii3sA39MdXZMWolM3s9VgEFR1IhAmdcnz6cgLhxNS0Lv3mz7OVOGunGsAlEsekZiQRDLDXHIQLfPg77+MKPe073vgkXRfWAZMxohe3ysPahJ0jIFl3GU1KuIgYCZ1yfPpyAuHE1LQu/ebPs5U4a6cawCUSx6RmJBEMsNcccrnhJ4jAAAIABAACAAAAAgAIAAIAAAAAAQgAAACIGAt8+Dvv4wo97Tve+CRdF9YBkzGiF7fKw9qEnSMgWXcZTHJkKc60wAACAAQAAgAAAAIACAACAAAAAAEIAAAAAAQEr8FUAAAAAAAAiACCcheUwIAj6XLtEe5QO+fTi25/ZvJGX9MuZkpghbW3VMgEFR1IhAkhWBpUeAB+UbbJc8f1fkEMEZgIChQVpMdJnD05uBtU4IQMUAdnwr2UVz6AhNBI5j6an4wHRGVX3uhSLaWy2qS70xlKuIgYCSFYGlR4AH5Rtslzx/V+QQwRmAgKFBWkx0mcPTm4G1TgcmQpzrTAAAIABAACAAAAAgAIAAIAAAAAARAAAACIGAxQB2fCvZRXPoCE0EjmPpqfjAdEZVfe6FItpbLapLvTGHK54SeIwAACAAQAAgAAAAIACAACAAAAAAEQAAAAAAA==';
    const firstSigned =
        'cHNidP8BAKQCAAAAA6DLc9RAdKwWQb/7Nrq1FyAtDQ3e0w5E4LkLpcrwBL0aAAAAAAD9////78NG2vqjywKaa0QHfo6C44o1+odXeWZ43FfHy4bLdxABAAAAAP3///8rhueJha90HzgJ6alnJ1uvi0Zbq0JQoXnwDb0Cjn79DwAAAAAA/f///wHWCBAAAAAAABYAFDraKFKubXzlSvRQy8V4X+TwKhLXAAAAAAAiAgKmgeTdVjPh9P+MPnsTPbFRcGGLPAO3iTyYBR7eYQC4VkcwRAIga3QJaZWl+pwWMjMc2PjxNIeFHeg6TF5bb57VYY5qg5cCIGRT9zijaAwbPkBMDqmKQSjEmqWSiAEDkRznqZYggIRGAQAiAgLfPg77+MKPe073vgkXRfWAZMxohe3ysPahJ0jIFl3GU0cwRAIgFEHGf3EbOMs/MPoWmbm/rBqSKyaST4XC+7WLqEsukgUCIFtimNwjtrGq4oI0QbIfJNC2HuedHKE9PyO7HULWTUfHAQAiAgJIVgaVHgAflG2yXPH9X5BDBGYCAoUFaTHSZw9ObgbVOEcwRAIgAsQjpMwk1Hz+LOIc4WWcR4dGA7h/IIqUPpqvVZup1HgCIDkKf/vx5xUQnI3ISjv5/vMd5qpXkMdy6mv8bnn881/pAQAA';
    const secondSigned =
        'cHNidP8BAKQCAAAAA6DLc9RAdKwWQb/7Nrq1FyAtDQ3e0w5E4LkLpcrwBL0aAAAAAAD9////78NG2vqjywKaa0QHfo6C44o1+odXeWZ43FfHy4bLdxABAAAAAP3///8rhueJha90HzgJ6alnJ1uvi0Zbq0JQoXnwDb0Cjn79DwAAAAAA/f///wHWCBAAAAAAABYAFDraKFKubXzlSvRQy8V4X+TwKhLXAAAAAAAiAgIv4ZP089Gh3DcLFcr/Om6kI99LFHsT5XO9/AqiYPn5S0cwRAIgMJcGjoczA/ht/oTuE30a5StXa9l72t5+jayaURudfnECIGw+ymYS2RDszHL+KXRuoiNjvAUiIIKE7wa7+RKORevBAQAiAgJnXJ8+nIC4cTUtC795s+zlThrpxrAJRLHpGYkEQyw1x0cwRAIgH5pFuC079UUXzPJU1ya57Lak9Yc4NkAttmOEsNphd/cCIBnVkzO/wVfD5dxWKXbqdHazwUirh2zcY1MIH1skRqkbAQAiAgMUAdnwr2UVz6AhNBI5j6an4wHRGVX3uhSLaWy2qS70xkcwRAIgVrv+vZ9iG1njv8wrSCuhhLIlkMRqk4lxnHBRMHTzVWUCIELRLHVXUTyL0rFWA8aNADWjkOB/pepeQst7u2GryIylAQAA';

    test('a trimmed signer reply finalizes against the PSBT it was given', () {
      final first = bdk.Psbt(psbtBase64: firstSigned);
      final second = bdk.Psbt(psbtBase64: secondSigned);
      final combined = first.combine(other: second);
      addTearDown(() {
        combined.dispose();
        second.dispose();
        first.dispose();
      });
      final finalized = _ok(
        finalizeBitcoinPsbts(
          unsignedBase64: unsigned,
          signedBase64: combined.serialize(),
        ),
      );
      final intended = (decodeBitcoinPsbt(unsigned));
      expect(finalized.txid, intended.txid);
      expect(finalized.inputs, hasLength(3));
      // Witnesses were added: the finalized bytes are no longer the skeleton.
      expect(finalized.size, greaterThan(intended.size));
      expect((decodeBitcoinTransaction(finalized.bytes)).txid, intended.txid);
    });

    test('one signature of two is not enough', () {
      expect(
        _err(
          finalizeBitcoinPsbts(
            unsignedBase64: unsigned,
            signedBase64: firstSigned,
          ),
        ),
        isA<SyncNotFinalizableFailure>(),
      );
    });

    test('an unsigned PSBT cannot be finalized', () {
      expect(
        _err(finalizeBitcoinPsbts(unsignedBase64: _psbt, signedBase64: _psbt)),
        isA<SyncNotFinalizableFailure>(),
      );
    });

    test('a PSBT for another transaction is not combined', () {
      expect(
        _err(
          finalizeBitcoinPsbts(
            unsignedBase64: _psbt,
            signedBase64: _psbtWithoutInputAmount(lockTime: '01000000'),
          ),
        ),
        isA<SyncNotFinalizableFailure>(),
      );
    });

    test('an unreadable signer reply is not a transaction', () {
      expect(
        _err(finalizeBitcoinPsbts(unsignedBase64: _psbt, signedBase64: 'x')),
        isA<SyncInvalidTransactionFailure>(),
      );
    });
  });

  group('addresses', () {
    const encodings = {
      BitcoinNetwork.mainnet: 'bc1',
      BitcoinNetwork.testnet: 'tb1',
      BitcoinNetwork.regtest: 'bcrt1',
    };

    test('an output script reads as its address on each network', () {
      for (final MapEntry(key: network, value: prefix) in encodings.entries) {
        final address = _ok(bitcoinScriptAddress(_p2wpkh, network));
        expect(address, startsWith(prefix));
        expect(_ok(bitcoinAddressScript(address, network)), _p2wpkh);
      }
    });

    test('a non-standard script has no address', () {
      expect(
        _err(bitcoinScriptAddress([0x6a, 0x01, 0x00], BitcoinNetwork.mainnet)),
        isA<SyncInvalidAddressFailure>(),
      );
    });

    test('signet is refused', () {
      expect(
        _err(bitcoinScriptAddress(_p2wpkh, BitcoinNetwork.signet)),
        isA<SyncUnsupportedNetworkFailure>(),
      );
      expect(
        _err(parseBitcoinAddress('tb1q', BitcoinNetwork.signet)),
        isA<SyncUnsupportedNetworkFailure>(),
      );
    });

    test('an address parses only on its own network', () {
      final mainnet = _ok(
        bitcoinScriptAddress(_p2wpkh, BitcoinNetwork.mainnet),
      );
      final testnet = _ok(
        bitcoinScriptAddress(_p2wpkh, BitcoinNetwork.testnet),
      );
      expect(
        _ok(parseBitcoinAddress(mainnet, BitcoinNetwork.mainnet)),
        mainnet,
      );
      expect(
        _ok(parseBitcoinAddress(testnet, BitcoinNetwork.testnet)),
        testnet,
      );
      expect(
        _err(parseBitcoinAddress(mainnet, BitcoinNetwork.testnet)),
        isA<SyncInvalidAddressFailure>(),
      );
      expect(
        _err(parseBitcoinAddress(testnet, BitcoinNetwork.mainnet)),
        isA<SyncInvalidAddressFailure>(),
      );
      expect(
        _err(parseBitcoinAddress('${mainnet}x', BitcoinNetwork.mainnet)),
        isA<SyncInvalidAddressFailure>(),
      );
    });

    test('an upper-case witness address reads canonically', () {
      final mainnet = _ok(
        bitcoinScriptAddress(_p2wpkh, BitcoinNetwork.mainnet),
      );
      expect(
        _ok(parseBitcoinAddress(mainnet.toUpperCase(), BitcoinNetwork.mainnet)),
        mainnet,
      );
    });
  });
}
