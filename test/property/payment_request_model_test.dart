import 'package:bb_mobile/core/utils/payment_request.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:test/test.dart';

/// Tests for PaymentRequest sealed class properties and getters.
///
/// These verify the data model layer — constructing each variant and
/// checking that getters (amountSat, isTestnet, name, type checks)
/// return correct values. This is pure Dart, no FFI needed.
///
/// Why this matters: The PaymentRequest type is used throughout the send
/// flow to make routing decisions. If isTestnet returns wrong, funds
/// could be sent to a testnet address on mainnet (lost forever).
///
/// Target: lib/core/utils/payment_request.dart
void main() {
  group('PaymentRequest.bitcoin', () {
    test('mainnet bitcoin has correct properties', () {
      const req = PaymentRequest.bitcoin(
        address: 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq',
        isTestnet: false,
      );
      expect(req.isTestnet, isFalse);
      expect(req.isBitcoinAddress, isTrue);
      expect(req.isLiquidAddress, isFalse);
      expect(req.isBolt11, isFalse);
      expect(req.isBip21, isFalse);
      expect(req.isPsbt, isFalse);
      expect(req.isLnAddress, isFalse);
      expect(req.amountSat, isNull);
      expect(req.name, equals('Bitcoin Onchain'));
    });

    test('testnet bitcoin has isTestnet true', () {
      const req = PaymentRequest.bitcoin(
        address: 'tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx',
        isTestnet: true,
      );
      expect(req.isTestnet, isTrue);
    });
  });

  group('PaymentRequest.liquid', () {
    test('mainnet liquid has correct properties', () {
      const req = PaymentRequest.liquid(
        address: 'VJLCbLBTCdxhWyjVLdjcSmGAksVMtabYg5',
        isTestnet: false,
      );
      expect(req.isTestnet, isFalse);
      expect(req.isLiquidAddress, isTrue);
      expect(req.isBitcoinAddress, isFalse);
      expect(req.amountSat, isNull);
      expect(req.name, equals('Liquid Onchain'));
    });

    test('testnet liquid has isTestnet true', () {
      const req = PaymentRequest.liquid(
        address: 'tlq1qqtest',
        isTestnet: true,
      );
      expect(req.isTestnet, isTrue);
    });
  });

  group('PaymentRequest.bolt11', () {
    test('mainnet bolt11 has correct properties', () {
      const req = PaymentRequest.bolt11(
        invoice: 'lnbc1000n1ptest',
        amountSat: 1000,
        paymentHash: 'abc123',
        description: 'test payment',
        expiresAt: 1700000000,
        isTestnet: false,
      );
      expect(req.isBolt11, isTrue);
      expect(req.amountSat, equals(1000));
      expect(req.isTestnet, isFalse);
      expect(req.name, equals('Bolt11'));
    });

    test('testnet bolt11 has isTestnet true', () {
      const req = PaymentRequest.bolt11(
        invoice: 'lntb1000n1ptest',
        amountSat: 500,
        paymentHash: 'def456',
        expiresAt: 1700000000,
        isTestnet: true,
      );
      expect(req.isTestnet, isTrue);
    });

    test('bolt11 with zero amount', () {
      const req = PaymentRequest.bolt11(
        invoice: 'lnbc1ptest',
        amountSat: 0,
        paymentHash: 'ghi789',
        expiresAt: 1700000000,
        isTestnet: false,
      );
      expect(req.amountSat, equals(0));
    });

    test('bolt11 default description is empty string', () {
      const req = PaymentRequest.bolt11(
        invoice: 'lnbc1ptest',
        amountSat: 100,
        paymentHash: 'jkl012',
        expiresAt: 1700000000,
        isTestnet: false,
      );
      expect((req as Bolt11PaymentRequest).description, equals(''));
    });
  });

  group('PaymentRequest.bip21', () {
    test('bip21 with amount has correct amountSat', () {
      const req = PaymentRequest.bip21(
        network: Network.bitcoinMainnet,
        uri: 'bitcoin:bc1qtest?amount=0.001',
        address: 'bc1qtest',
        amountSat: 100000,
      );
      expect(req.isBip21, isTrue);
      expect(req.amountSat, equals(100000));
      expect(req.isTestnet, isFalse);
      expect(req.name, equals('BIP21'));
    });

    test('bip21 without amount has null amountSat', () {
      const req = PaymentRequest.bip21(
        network: Network.bitcoinMainnet,
        uri: 'bitcoin:bc1qtest',
        address: 'bc1qtest',
      );
      expect(req.amountSat, isNull);
    });

    test('bip21 testnet network returns isTestnet true', () {
      const req = PaymentRequest.bip21(
        network: Network.bitcoinTestnet,
        uri: 'bitcoin:tb1qtest',
        address: 'tb1qtest',
      );
      expect(req.isTestnet, isTrue);
    });

    test('bip21 liquid mainnet returns isTestnet false', () {
      const req = PaymentRequest.bip21(
        network: Network.liquidMainnet,
        uri: 'liquidnetwork:VJLtest',
        address: 'VJLtest',
      );
      expect(req.isTestnet, isFalse);
    });

    test('bip21 liquid testnet returns isTestnet true', () {
      const req = PaymentRequest.bip21(
        network: Network.liquidTestnet,
        uri: 'liquidtestnet:tlq1test',
        address: 'tlq1test',
      );
      expect(req.isTestnet, isTrue);
    });

    test('bip21 default values for optional fields', () {
      const req = PaymentRequest.bip21(
        network: Network.bitcoinMainnet,
        uri: 'bitcoin:bc1qtest',
        address: 'bc1qtest',
      );
      final bip21Req = req as Bip21PaymentRequest;
      expect(bip21Req.label, equals(''));
      expect(bip21Req.message, equals(''));
      expect(bip21Req.lightning, equals(''));
      expect(bip21Req.pj, equals(''));
      expect(bip21Req.pjos, equals(''));
    });

    test('bip21 with payjoin params preserves them', () {
      const req = PaymentRequest.bip21(
        network: Network.bitcoinMainnet,
        uri: 'bitcoin:bc1qtest?pj=https://pj.example.com&pjos=0',
        address: 'bc1qtest',
        pj: 'https://pj.example.com',
        pjos: '0',
      );
      final bip21Req = req as Bip21PaymentRequest;
      expect(bip21Req.pj, equals('https://pj.example.com'));
      expect(bip21Req.pjos, equals('0'));
    });
  });

  group('PaymentRequest.lnAddress', () {
    test('lnAddress has correct properties', () {
      const req = PaymentRequest.lnAddress(
        address: 'user@walletofsatoshi.com',
      );
      expect(req.isLnAddress, isTrue);
      expect(req.isBolt11, isFalse);
      expect(req.isTestnet, isFalse); // LN addresses are always mainnet
      expect(req.amountSat, isNull);
      expect(req.name, equals('Lightning Address'));
    });
  });

  group('PaymentRequest.ark', () {
    test('ark has correct properties', () {
      const req = PaymentRequest.ark(address: 'ark:someaddress');
      expect(req.isTestnet, isFalse);
      expect(req.amountSat, isNull);
      expect(req.name, equals('ARK'));
    });
  });

  group('PaymentRequest.psbt', () {
    test('psbt has correct properties', () {
      const req = PaymentRequest.psbt(psbt: 'cHNidP8BAH0CAAAA');
      expect(req.isPsbt, isTrue);
      expect(req.isTestnet, isFalse);
      expect(req.amountSat, isNull);
      expect(req.name, equals('PSBT'));
    });
  });

  group('PaymentRequest type exclusivity', () {
    // Only ONE type check should be true for each variant (except ARK — see below)
    test('6 variants with boolean getters each have exactly one flag true', () {
      final variants = <PaymentRequest>[
        const PaymentRequest.bitcoin(address: 'bc1q', isTestnet: false),
        const PaymentRequest.liquid(address: 'lq1', isTestnet: false),
        const PaymentRequest.lnAddress(address: 'user@host'),
        const PaymentRequest.bolt11(
          invoice: 'lnbc',
          amountSat: 0,
          paymentHash: 'h',
          expiresAt: 0,
          isTestnet: false,
        ),
        const PaymentRequest.bip21(
          network: Network.bitcoinMainnet,
          uri: 'bitcoin:x',
          address: 'x',
        ),
        const PaymentRequest.psbt(psbt: 'p'),
      ];

      for (final v in variants) {
        final flags = [
          v.isBitcoinAddress,
          v.isLiquidAddress,
          v.isLnAddress,
          v.isBolt11,
          v.isBip21,
          v.isPsbt,
        ];
        final trueCount = flags.where((f) => f).length;
        expect(trueCount, equals(1),
            reason: '${v.name} should have exactly 1 type flag true, got $trueCount');
      }
    });

    test('ARK variant has zero boolean flags (no isArk getter exists)', () {
      // KNOWN UPSTREAM GAP: No `bool get isArk` exists on PaymentRequest.
      // See project_upstream_findings.md #5.
      const ark = PaymentRequest.ark(address: 'ark:test');
      final flags = [
        ark.isBitcoinAddress,
        ark.isLiquidAddress,
        ark.isLnAddress,
        ark.isBolt11,
        ark.isBip21,
        ark.isPsbt,
      ];
      final trueCount = flags.where((f) => f).length;
      expect(trueCount, equals(0),
          reason: 'ARK has no isArk getter — all 6 flags should be false');
    });

    test('different types with same address string are not equal', () {
      // Bug this catches: Freezed equality comparing only fields, not type
      const bitcoin = PaymentRequest.bitcoin(address: 'x', isTestnet: false);
      const liquid = PaymentRequest.liquid(address: 'x', isTestnet: false);
      expect(bitcoin, isNot(equals(liquid)),
          reason: 'Different payment types must not be equal even with same address');
    });
  });

  group('isTestnet correctness across all variants', () {
    test('all 4 networks map correctly', () {
      expect(Network.bitcoinMainnet.isTestnet, isFalse);
      expect(Network.bitcoinTestnet.isTestnet, isTrue);
      expect(Network.liquidMainnet.isTestnet, isFalse);
      expect(Network.liquidTestnet.isTestnet, isTrue);
    });

    test('lnAddress always returns false for isTestnet', () {
      const req = PaymentRequest.lnAddress(address: 'user@host.com');
      expect(req.isTestnet, isFalse,
          reason: 'Lightning addresses have no testnet concept');
    });

    test('ARK always returns false for isTestnet', () {
      const req = PaymentRequest.ark(address: 'ark:test');
      expect(req.isTestnet, isFalse);
    });

    test('PSBT always returns false for isTestnet', () {
      const req = PaymentRequest.psbt(psbt: 'cHNidA==');
      expect(req.isTestnet, isFalse);
    });
  });

  group('Freezed copyWith correctness', () {
    test('bip21 copyWith preserves unmodified fields', () {
      // Bug this catches: Freezed codegen error silently zeroing fields on copy
      const original = PaymentRequest.bip21(
        network: Network.bitcoinMainnet,
        uri: 'bitcoin:bc1qtest?amount=0.001',
        address: 'bc1qtest',
        amountSat: 100000,
        label: 'Merchant',
        lightning: 'lnbc500n1p0test',
        pj: 'https://pj.example.com',
      );
      final copied = (original as Bip21PaymentRequest).copyWith(label: 'Updated');
      expect(copied.amountSat, equals(100000),
          reason: 'amountSat must survive copyWith');
      expect(copied.address, equals('bc1qtest'));
      expect(copied.label, equals('Updated'));
      expect(copied.lightning, equals('lnbc500n1p0test'),
          reason: 'lightning field must survive copyWith');
      expect(copied.pj, equals('https://pj.example.com'),
          reason: 'payjoin field must survive copyWith');
    });
  });

  group('BIP21 field preservation', () {
    test('bip21 with lightning field preserves it', () {
      const req = PaymentRequest.bip21(
        network: Network.bitcoinMainnet,
        uri: 'bitcoin:bc1qtest?lightning=lnbc500n1p0',
        address: 'bc1qtest',
        lightning: 'lnbc500n1p0',
      );
      expect((req as Bip21PaymentRequest).lightning, equals('lnbc500n1p0'),
          reason: 'Lightning field in unified BIP21 must be preserved');
    });

    test('bip21 with non-empty label and message', () {
      const req = PaymentRequest.bip21(
        network: Network.bitcoinMainnet,
        uri: 'bitcoin:bc1qtest?label=Bull+Bitcoin&message=Payment',
        address: 'bc1qtest',
        label: 'Bull Bitcoin',
        message: 'Payment',
      );
      final bip21 = req as Bip21PaymentRequest;
      expect(bip21.label, equals('Bull Bitcoin'));
      expect(bip21.message, equals('Payment'));
    });

    test('bip21 amountSat of 0 is distinct from null', () {
      const withZero = PaymentRequest.bip21(
        network: Network.bitcoinMainnet,
        uri: 'bitcoin:bc1q?amount=0',
        address: 'bc1q',
        amountSat: 0,
      );
      const withNull = PaymentRequest.bip21(
        network: Network.bitcoinMainnet,
        uri: 'bitcoin:bc1q',
        address: 'bc1q',
      );
      expect(withZero.amountSat, equals(0),
          reason: 'amountSat=0 means "pay exactly zero"');
      expect(withNull.amountSat, isNull,
          reason: 'amountSat=null means "any amount"');
      expect(withZero.amountSat, isNot(equals(withNull.amountSat)),
          reason: '0 and null are semantically different');
    });
  });
}
