import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:lwk/lwk.dart' as lwk;

void setupConfigs() {}
final bbmempoolapi = dotenv.env['BB_MEMPOOL_API'] ?? 'mempool.bullbitcoin.com';
final openmempoolapi = dotenv.env['MEMPOOL_API'] ?? 'mempool.space';
final bbexchangeapi = dotenv.env['BB_API'] ?? 'api.bullbitcoin.com/price';
// final bbexchangeapi = dotenv.env['BB_API'] ?? 'pricer.bullbitcoin.dev/api';

const bbelectrumMain = 'wes.bullbitcoin.com:50002';
const openelectrumMain = 'blockstream.info:700';
// BB test currently not operational
const bbelectrumTest = 'wes.bullbitcoin.com:60002';
const openelectrumTest = 'blockstream.info:993';

const liquidElectrumUrl = 'blockstream.info:995';
const liquidElectrumTestUrl = 'blockstream.info:465';
const bbLiquidElectrumUrl = 'les.bullbitcoin.com:995';
const bbLiquidElectrumTestUrl = 'blockstream.info:465';

const boltzTestnetUrl = 'api.testnet.boltz.exchange/v2';
const boltzMainnetUrl = 'api.boltz.exchange/v2';

final exchangeapi = bbexchangeapi;
final mempoolapi = openmempoolapi; //bbmempoolapi;

const liquidMempool = 'https://liquid.network';
const liquidMempoolTestnet = 'https://liquid.network/testnet';

const liquidMainnetAssetId = lwk.lBtcAssetId;
const liquidTestnetAssetId = lwk.lTestAssetId;

//Backups
final keyServerUrl = dotenv.env['KEY_SERVER'] ?? 'http://localhost:3000';
final keyServerPublicKey = dotenv.env['KEY_SERVER_PUBLIC_KEY'] ??
    '6a04ab98d9e4774ad806e302dddeb63bea16b5cb5f223ee77478e861bb583eb3';
final onionUrl = dotenv.env['ONION_ENDPOINT'] ?? 'http://localhost:80';
const defaultBackupPath = 'backups';
