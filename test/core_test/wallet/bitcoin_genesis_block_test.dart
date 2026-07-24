import 'package:bb_mobile/core/wallet/domain/entities/bitcoin_genesis_block.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet_birthday_checkpoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BitcoinGenesisBlock', () {
    test('mainnet is height 0 with a valid 64-hex hash', () {
      expect(BitcoinGenesisBlock.mainnet.height, 0);
      expect(
        RegExp(r'^[0-9a-f]{64}$').hasMatch(BitcoinGenesisBlock.mainnet.hash),
        isTrue,
      );
    });

    test('testnet is height 0 with a valid 64-hex hash', () {
      expect(BitcoinGenesisBlock.testnet.height, 0);
      expect(
        RegExp(r'^[0-9a-f]{64}$').hasMatch(BitcoinGenesisBlock.testnet.hash),
        isTrue,
      );
    });

    test('mainnet and testnet have distinct genesis blocks', () {
      expect(
        BitcoinGenesisBlock.mainnet.hash,
        isNot(BitcoinGenesisBlock.testnet.hash),
      );
      expect(
        BitcoinGenesisBlock.mainnet.timestamp,
        isNot(BitcoinGenesisBlock.testnet.timestamp),
      );
    });

    test('timestamps are UTC', () {
      expect(BitcoinGenesisBlock.mainnet.timestamp.isUtc, isTrue);
      expect(BitcoinGenesisBlock.testnet.timestamp.isUtc, isTrue);
    });

    test('forNetwork(isTestnet: false) returns mainnet', () {
      expect(
        BitcoinGenesisBlock.forNetwork(isTestnet: false),
        same(BitcoinGenesisBlock.mainnet),
      );
    });

    test('forNetwork(isTestnet: true) returns testnet', () {
      expect(
        BitcoinGenesisBlock.forNetwork(isTestnet: true),
        same(BitcoinGenesisBlock.testnet),
      );
    });

    test('the constants build a valid WalletBirthdayCheckpoint', () {
      final genesis = BitcoinGenesisBlock.mainnet;

      expect(
        () => WalletBirthdayCheckpoint(
          requestedBirthday: genesis.timestamp,
          blockTimestamp: genesis.timestamp,
          blockHeight: genesis.height,
          blockHash: genesis.hash,
        ),
        returnsNormally,
      );
    });
  });
}
