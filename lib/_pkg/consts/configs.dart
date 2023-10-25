import 'package:flutter_dotenv/flutter_dotenv.dart';

void setupConfigs() {}

final bbmempoolapi = dotenv.env['BB_MEMPOOL_API'] ?? 'mempool.bullbitcoin.com';
final openmempoolapi = dotenv.env['MEMPOOL_API'] ?? 'mempool.space';
final bbexchangeapi = dotenv.env['BB_API'] ?? 'api.bullbitcoin.com/price';

const bbelectrum = 'electrum.bullbitcoin.com';
const openelectrum = 'electrum.blockstream.info';

final exchangeapi = bbexchangeapi;
final mempoolapi = bbmempoolapi;
