import 'package:flutter_dotenv/flutter_dotenv.dart';

void setupConfigs() {}

final bbmempoolapi = dotenv.env['BB_MEMPOOL_API'] ?? 'mempool.bullbitcoin.com';
final openmempoolapi = dotenv.env['MEMPOOL_API'] ?? 'mempool.space';
final bbexchangeapi = dotenv.env['BB_API'] ?? 'api.bullbitcoin.com/price';
// final bbexchangeapi = dotenv.env['BB_API'] ?? 'pricer.bullbitcoin.dev/api';

const bbelectrum = 'electrum.bullbitcoin.com';
const openelectrum = 'electrum.blockstream.info';
const liquidElectrumUrl = 'blockstream.info:995';
const liquidElectrumTestUrl = 'blockstream.info:465';

const boltzTestnet = 'https://api.testnet.boltz.exchange';
const boltzMainnet = 'https://api.boltz.exchange';

final exchangeapi = bbexchangeapi;
final mempoolapi = bbmempoolapi;
