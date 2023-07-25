// ignore_for_file: prefer_single_quotes, unused_local_variable

import 'package:bb_mobile/_model/cold_card.dart';
import 'package:bb_mobile/_model/wallet.dart';
import 'package:bb_mobile/_pkg/bull_bitcoin_api.dart';
import 'package:bb_mobile/_pkg/mempool_api.dart';
import 'package:bb_mobile/_pkg/storage/secure_storage.dart';
import 'package:bb_mobile/_pkg/wallet/create.dart';
import 'package:bb_mobile/settings/bloc/settings_cubit.dart';
import 'package:bdk_flutter/bdk_flutter.dart' as bdk;
import 'package:dio/dio.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';

const ccJson = {
  "chain": "XTN",
  "xpub":
      "tpubD6NzVbkrYhZ4Xq4XyiwvmzGPCXzFJ9AsnX73R6gWv2XfGrvGwSCnpJegSjpSXnFj3tRdUC9YpKQvgxSqJ4TcdrCjQR7fSw3VRqGnQL5NtQA",
  "xfp": "EFAB2046",
  "account": 0,
  "bip49": {
    "xpub":
        "tpubDCw55JYr2oyHnevDv4CTVHXPWoxC3LjsyjzCCMCFNZgRh5jFCdMgNB3WFecRd777m8GCnFBk5z2fiUT8g8KZShZdF9iqWhKVdUfFDqKF6HG",
    "first": "2MwFTXMzizYWieC2JU1aKmmGqwe5FCsF4KA",
    "deriv": "m/49'/1'/0'",
    "xfp": "31B4BA66",
    "name": "p2wpkh-p2sh",
    "_pub":
        "upub5E4ee4iQsVPPxyA1xnrVf6uWfnRCE6GKgmqEVcTStdntnVcrNS1uMYQFwzet6tC7kJNsvEtCAu8yNS7q8BEHAZ4XaXtG5SCoELsuJ9CS2Cz"
  },
  "bip44": {
    "xpub":
        "tpubDC4aoM5HbUhASitj53NF232tkuGdPwKfUbSNa64puihCRgZ8L81N8p1VfqdC7y5QtANSJqsLup4smgkfNLTKHpnw9dd5xNXg6jCGTrncm6h",
    "first": "mjyKkvsMhTjEpNqbt4vD5kD9GDoHzStFES",
    "deriv": "m/44'/1'/0'",
    "xfp": "7DEF5A46",
    "name": "p2pkh"
  },
  "bip84": {
    "xpub":
        "tpubDCBtCtWDzqBZRjMzFbtSDFvTQkKhN2gdKyAG6cDVGqGo9zeUDwCuL73XEszmJc1Do7aE8rxtzoDdkEm8GvX4FPQrqpZHgwhpTNAUALq9kd7",
    "first": "tb1qcpmjxkw90dvsy7emhdpvxehe3z0vpw8eerz4ct",
    "deriv": "m/84'/1'/0'",
    "xfp": "38012D14",
    "name": "p2wpkh",
    "_pub":
        "vpub5Y9j5KLhzC99TLnu8hL6bAQ5jgw9VQCZx7XXBGNaAum9JWMJeQ2gwY4QxRzonHk9Bvoi2LFuYNgVHV3PSfqnmUbN3YR8qbQcKxSmd7xW4bn"
  }
};

void main() {
  // bool checkHex(String s) {
  //   return int.tryParse(s) != null;

  //   // final pattern = RegExp(r'^#?([0-9a-fA-F]{3}|[0-9a-fA-F]{6})$');
  //   // return pattern.hasMatch(s);

  //   // // Size of string
  //   // final int n = s.length;

  //   // // Iterate over string
  //   // for (int i = 0; i < n; i++) {
  //   //   final String ch = s[i];

  //   //   // Check if the character is invalid
  //   //   if ((ch.compareTo('0') < 0 || ch.compareTo('9') > 0) &&
  //   //       (ch.compareTo('A') < 0 || ch.compareTo('F') > 0)) {
  //   //     return false;
  //   //   }
  //   // }

  //   // // Return true if all characters are valid
  //   // return true;
  // }

  testWidgets('create 12 mne', (_) async {
    final mne = await bdk.Mnemonic.create(bdk.WordCount.Words12);
    expect(mne.asString().split(' ').length, 12);
  });

  testWidgets('create wallet from string', (_) async {
    // const priv =
    // 'tprv8ZgxMBicQKsPdQeKoeaGn3iLf7JJskBJEZhaMtLpXhL22K6uzHiR2S3EdnkMf1cSBmur4gjKgKN6QmGmi5nHPNzuEeLssSMgfCWer9JyrAx';

    // const descrpriv = "pkh($priv/44'/1'/0'/0/*)";

    const pub =
        'tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz';

    // const x1 = "pkh([ddffda99/44'/1'/0']$pub/1/*)";
    // const x2 = "pkh([ddffda99/44'/1'/0']$pub/0/*)";

    // const y1 = "pkh($pub/44'/1'/0'/0/*)";
    // const y2 = "pkh($pub/44'/1'/0'/1/*)";

    // const x1 = "pkh([ddffda99/44'/1'/0']$pub/1/0/*)";
    // const x2 = "pkh([ddffda99/44'/1'/0']$pub/0/0/*)";
    // const xx = "pkh([ddffda99/44'/1'/0']$pub/<0;1>/*)";
    const x1 = "pkh([ddffda99/44'/1'/0']$pub/1/*)";
    const x2 = "pkh([ddffda99/44'/1'/0']$pub/0/*)";

    // const fingr = '0x1234abcd';
    // final isHex = checkHex(fingr);

    // wpkh([0f056943/84h/0h/0h]xpub6CaWStGvcXqM8BH3Grg4Ae1SrRhXPN67Sr3HJoEZLmz51QaR9a7wSD5gRBVtTSH7mKsfoAEScB8jRPsWX1VBayBFYKUNwG7JqhWczbq4U99/<0;1>/*)#l07d6h6y

    // const d1 = "pkh($pub/0/*)";
    // const d2 = "pkh($pub/1/*)";

    try {
      final descriptor = await bdk.Descriptor.create(
        descriptor: x2,
        network: bdk.Network.Testnet,
      );
      final cdescriptor = await bdk.Descriptor.create(
        descriptor: x1,
        network: bdk.Network.Testnet,
      );

      final wallet = await bdk.Wallet.create(
        descriptor: descriptor,
        changeDescriptor: cdescriptor,
        network: bdk.Network.Testnet,
        databaseConfig: const bdk.DatabaseConfig.memory(),
      );

      final dio = Dio();

      final settingsCubit = SettingsCubit(
        storage: SecureStorage(),
        bbAPI: BullBitcoinAPI(dio),
        mempoolAPI: MempoolAPI(dio),
        walletCreate: WalletCreate(),
      );
      await Future.delayed(2.seconds);

      await wallet.sync(settingsCubit.state.blockchain!);
      final balance = await wallet.getBalance();
      final txs = await wallet.listTransactions(true);

      expect(balance.total, isPositive);
    } catch (e) {
      print(e);
      rethrow;
    }
    // 12070
    // 78538
    // 90608
  });

  testWidgets('create wallet from bdk', (_) async {
    const xpub =
        'tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz';

    final descriptorKey = await bdk.DescriptorPublicKey.fromString(xpub);

    final cdescriptor = await bdk.Descriptor.newBip44Public(
      fingerPrint: 'ddddda99',
      publicKey: descriptorKey,
      network: bdk.Network.Testnet,
      keychain: bdk.KeychainKind.Internal,
    );

    final descriptor = await bdk.Descriptor.newBip44Public(
      fingerPrint: 'ddddda99',
      publicKey: descriptorKey,
      network: bdk.Network.Testnet,
      keychain: bdk.KeychainKind.External,
    );

    final wallet = await bdk.Wallet.create(
      descriptor: descriptor,
      changeDescriptor: cdescriptor,
      network: bdk.Network.Testnet,
      databaseConfig: const bdk.DatabaseConfig.memory(),
    );

    final dio = Dio();

    final settingsCubit = SettingsCubit(
      storage: SecureStorage(),
      bbAPI: BullBitcoinAPI(dio),
      mempoolAPI: MempoolAPI(dio),
      walletCreate: WalletCreate(),
    );

    await Future.delayed(2.seconds);

    await wallet.sync(settingsCubit.state.blockchain!);

    final balance = await wallet.getBalance();
    final txs = await wallet.listTransactions(true);

    expect(balance.total, isPositive);

    // final derivation = await bdk.DerivationPath.create(path: path);
    // descriptorKey = await descriptorKey.derive(derivation);
  });

  testWidgets('create wallet from coldcard', (_) async {
    try {
      final coldcard = ColdCard.fromJson(ccJson);

      final (ww, _) = Wallet.fromColdCard(
        coldCard: coldcard,
        walletPurpose: ScriptType.bip49,
        isTestNet: true,
      );

      final walletCreate = WalletCreate();

      final (w, rr) = await walletCreate.loadBdkWallet(
        ww!,
        fromStorage: false,
      );

      if (rr != null) throw rr;

      final (_, wallet) = w!;

      final dio = Dio();

      final settingsCubit = SettingsCubit(
        storage: SecureStorage(),
        bbAPI: BullBitcoinAPI(dio),
        mempoolAPI: MempoolAPI(dio),
        walletCreate: WalletCreate(),
      );
      settingsCubit.toggleTestnet();

      await Future.delayed(2.seconds);

      await wallet.sync(settingsCubit.state.blockchain!);

      final balance = await wallet.getBalance();
      final txs = await wallet.listTransactions(true);

      expect(txs.length, isPositive);
    } catch (e) {
      print(e);
      rethrow;
    }
  });

  testWidgets('create wallet from coldcard', (_) async {
    try {
      final coldcard = ColdCard.fromJson(ccJson);

      final (ww, _) = Wallet.fromColdCard(
        coldCard: coldcard,
        walletPurpose: ScriptType.bip49,
        isTestNet: true,
      );

      final walletCreate = WalletCreate();

      final (w, rr) = await walletCreate.loadBdkWallet(
        ww!,
        fromStorage: false,
      );

      if (rr != null) throw rr;

      final (_, wallet) = w!;

      final dio = Dio();

      final settingsCubit = SettingsCubit(
        storage: SecureStorage(),
        bbAPI: BullBitcoinAPI(dio),
        mempoolAPI: MempoolAPI(dio),
        walletCreate: WalletCreate(),
      );
      settingsCubit.toggleTestnet();

      await Future.delayed(2.seconds);

      await wallet.sync(settingsCubit.state.blockchain!);

      final balance = await wallet.getBalance();
      final txs = await wallet.listTransactions(true);

      expect(txs.length, isPositive);
    } catch (e) {
      print(e);
      rethrow;
    }
  });

  testWidgets('T', (widgetTester) async {
    try {
      final words = [].join(' ');
      final mne = await bdk.Mnemonic.fromString(words);

      final descriptor = await bdk.DescriptorSecretKey.create(
        network: bdk.Network.Bitcoin,
        mnemonic: mne,
        password: '',
      );

      int bal = 0;

      for (var i = 0; i < 3; i++) {
        late bdk.Descriptor internal;
        late bdk.Descriptor external;

        if (i == 0) {
          internal = await bdk.Descriptor.newBip49(
            secretKey: descriptor,
            network: bdk.Network.Bitcoin,
            keychain: bdk.KeychainKind.Internal,
          );

          external = await bdk.Descriptor.newBip49(
            secretKey: descriptor,
            network: bdk.Network.Bitcoin,
            keychain: bdk.KeychainKind.External,
          );
        }
        if (i == 1) {
          internal = await bdk.Descriptor.newBip84(
            secretKey: descriptor,
            network: bdk.Network.Bitcoin,
            keychain: bdk.KeychainKind.Internal,
          );

          external = await bdk.Descriptor.newBip84(
            secretKey: descriptor,
            network: bdk.Network.Bitcoin,
            keychain: bdk.KeychainKind.External,
          );
        }
        if (i == 2) {
          internal = await bdk.Descriptor.newBip44(
            secretKey: descriptor,
            network: bdk.Network.Bitcoin,
            keychain: bdk.KeychainKind.Internal,
          );

          external = await bdk.Descriptor.newBip44(
            secretKey: descriptor,
            network: bdk.Network.Bitcoin,
            keychain: bdk.KeychainKind.External,
          );
        }

        final wallet = await bdk.Wallet.create(
          descriptor: external,
          changeDescriptor: internal,
          network: bdk.Network.Bitcoin,
          databaseConfig: const bdk.DatabaseConfig.memory(),
        );

        final electrum = await bdk.Blockchain.create(
          config: const bdk.BlockchainConfig.electrum(
            config: bdk.ElectrumConfig(
              retry: 3,
              stopGap: 20,
              timeout: 5,
              url: 'ssl://electrum.blockstream.info:50002',
              validateDomain: true,
            ),
          ),
        );

        await wallet.sync(electrum);

        final balance = await wallet.getBalance();

        bal += balance.total;
      }

      expect(bal, isPositive);
    } catch (e) {
      print(e);
      rethrow;
    }
  });
}

//   external = await bdk.Descriptor.create(
//   descriptor: wallet.externalDescriptor,
//   network: bdk.Network.Testnet,
// );
// internal = await bdk.Descriptor.create(
//   descriptor: wallet.internalDescriptor,
//   network: bdk.Network.Testnet,
// );

//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//
//

//   BdkException.unExpected(e: called `Result::unwrap()` on an `Err` value:
// Descriptor(HardenedDerivationXpub))

//   BdkException.miniscript(e: "))))

// const _t1 =
//     'tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz';

// const _d1 =
//     "wpkh(tprv8ZgxMBicQKsPcthqtyCtGtGzJhWXNC5QwGek1GQMs9vxHFrqhfXzdL5tstUWjLfm8JNeY7TvG2PxrfY5F8edd1JLyXqb2e86JhG4icehVAy/84'/1'/0'/1/*)#7420nc5y";

// const _t2 =
//     "wpkh(tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz/44/1/0/1/*)";

// const _d2 =
//     "wpkh([ddffda99/84'/1'/0']tpubDDnLoUnx37yzHvcifbUWBmdGmQj1ZGVEtZgLSAHgzqLF4en9ZSAf9MuvEah3NrSUoAhHW8UnERsHeyumfqCt1RiY4JBcuRYwBEEAgFd8xQh/0/*)#e6cds43y";

// const _d3 =
//     "pkh([ddffda99/44'/1'/0']tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz/0/*)#23krdrn4";

// const _z1 =
//     'zpub6qrjqR4sNQqcq3MbPTgNEQ33Dhz8VSU9G7o88FwKWpAMsoYbVbSMVxGtHx2829QkdMJCNrGuwEnF49KJAvXwkLQerAGmWEwpoQAQ7pMBFmV';

// //pkh([ddffda99/44'/1'/0']tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz/0/*)#23krdrn4
// // pkh([258ee68c/44'/1'/0']tpubDGkapRgaKKcdaEtBkHfcWBDsrUWh1Lubu7JWEyPdU3LTkJQmxMz6qKzWVcAuSNyWjRe7kJ9EVzk6BosPSP5GvfR6SuB913zP1jqUxsjBUsQ/0/*)#75nf0v7a

// //  pkh([ddffda99/44'/1'/0']tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz/0/*)#23krdrn4
// //i pkh([ddffda99/44'/1'/0']tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz/0/*)#23krdrn4
// //a pkh([ddffda99/44'/1'/0']tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz/0/*)#23krdrn4
// //  pkh([ddffda99/44'/1'/0']tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz/0/*)#23krdrn4

// //  pkh([ddffda99/44'/1'/0']tpubDC5phKKvZNyMBySbRhQW6t1AkutpvxpAbPacFw38eM2DpiMRZAUBXooGNaBUzVKsST56w1osYwEuRtmqsEpKw4fw8mYWm3jbsjMGnYrgbUz/0/*)#23krdrn4
