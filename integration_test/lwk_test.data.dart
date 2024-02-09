import 'package:boltz_dart/boltz_dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lwk_dart/lwk_dart.dart';

const lNetwork = LiquidNetwork.Testnet;
const lElectrumUrl = 'blockstream.info:465';

const swapMnemonic =
    'bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon bacon';
const swapIndex = 0;
const network = Chain.Testnet;
const electrumUrl = 'electrum.bullbitcoin.com:60002';
const boltzUrl = 'https://api.testnet.boltz.exchange';
const testTimeout = Timeout(Duration(minutes: 30));

const fundingLWalletMnemonic =
    'fossil install fever ticket wisdom outer broken aspect lucky still flavor dial';
