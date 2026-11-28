import 'dart:convert';
import 'dart:io';

import 'package:address_view/address_view.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/foundation.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/storage.dart';
import 'package:sync/sync.dart';
import 'package:sync/write.dart';

import 'initialization_result.dart';

/// Opt-in for an isolated local integration runner, never a production wallet.
const localRegtest = bool.fromEnvironment('BULL_REGTEST_VALIDATION');

/// Creates a fresh Bitcoin regtest wallet and funds two confirmed outputs.
/// The caller must run in an isolated application data directory and select
/// Environment.regtest before calling this helper.
Future<Wallet> fundedRegtestWallet() async {
  const host = String.fromEnvironment('BULL_REGTEST_HOST');
  if (!localRegtest ||
      !kDebugMode ||
      (host != '127.0.0.1' && host != '10.0.2.2')) {
    throw StateError('An isolated local debug regtest runner is required');
  }
  final rpc = _BitcoinRpc(host);
  final info = await rpc.call('getblockchaininfo', []);
  if (info is! Map || info['chain'] != 'regtest') {
    throw StateError('Bitcoin Core is not on regtest');
  }
  final secret = requireValue(
    await locator<Secrets>().generate(),
    'generate fixture secret',
  );
  const network = BitcoinNetwork.regtest;
  const scriptType = ScriptType.bip84;
  final id = 'wpkh([${secret.id.hex}/84h/1h/0h]):regtest';
  final key = WalletKey(id: id, network: network);
  final xpub = requireValue(
    await secret.derive.xpub(network: network, scriptType: scriptType),
    'derive fixture xpub',
  );
  final descriptors = requireValue(
    await secret.derive.descriptors.bitcoin(
      network: network,
      scriptType: scriptType,
    ),
    'derive fixture descriptors',
  );
  final native = locator<WalletNativeRuntime>();
  final inventory = locator<SecretsInventory>();
  requireValue(await native.prepareCreate(key), 'prepare fixture wallet');
  requireValue(
    await inventory.registerWallet(
      RegisteredWallet(
        id: id,
        secretFingerprint: secret.id.hex,
        masterFingerprint: secret.id.hex,
        signer: WalletSigner.local.name,
        network: 'bitcoinRegtest',
        xpub: xpub,
        externalDescriptor: descriptors.external,
        internalDescriptor: descriptors.internal,
        label: null,
        birthday: null,
        isDefault: false,
      ),
    ),
    'register fixture wallet',
  );
  final created = await native.create(key);
  if (created is Err) {
    requireValue(
      await inventory.removeWallet(id),
      'remove failed fixture wallet',
    );
  }
  requireValue(created, 'create fixture wallet');
  final addresses = locator<AddressView>();
  for (var i = 0; i < 2; i++) {
    final address = requireValue(
      await addresses.receiveAddress(walletId: id, advance: true),
      'issue fixture address',
    ).address;
    if (!address.startsWith('bcrt1')) {
      throw StateError('Expected a regtest address');
    }
    await rpc.call('sendtoaddress', [address, 0.001]);
  }
  await _mineBlock(rpc);
  requireValue(await native.initialize(), 'initialize Sync');
  final descriptor = requireValue(
    await locator<WalletCatalogPort>().find(key),
    'read fixture descriptor',
  );
  final deadline = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(deadline)) {
    requireValue(
      await locator<ElectrumSync>().execute(descriptor),
      'sync fixture wallet',
    );
    requireValue(await native.refresh(key), 'publish fixture wallet');
    final wallet = requireValue(
      await native.loadWallet(key),
      'load fixture wallet',
    );
    final coins = requireValue(wallet.coins.now.latest, 'read fixture coins');
    if (coins
            .whereType<BitcoinCoin>()
            .where((coin) => coin.confirmations > 0)
            .length >=
        2) {
      return wallet;
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('Electrum did not index two confirmed fixture outputs');
}

Future<void> _mineBlock(_BitcoinRpc rpc) async {
  final address = await rpc.call('getnewaddress', []);
  if (address is! String) throw StateError('Missing mining address');
  await rpc.call('generatetoaddress', [1, address]);
}

/// RPC is intentionally restricted to a disposable, loopback-only CI node.
final class _BitcoinRpc {
  final String host;
  _BitcoinRpc(this.host);

  Future<Object?> call(String method, List<Object> params) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 5)
      ..findProxy = (_) => 'DIRECT';
    try {
      final request = await client.postUrl(
        Uri.parse('http://$host:18443/wallet/ci'),
      );
      request.followRedirects = false;
      request.headers.contentType = ContentType.json;
      request.headers.set(
        HttpHeaders.authorizationHeader,
        'Basic ${base64Encode(utf8.encode('ci:ci'))}',
      );
      request.write(
        jsonEncode({
          'jsonrpc': '1.0',
          'id': 'integration',
          'method': method,
          'params': params,
        }),
      );
      final response = await request.close().timeout(
        const Duration(seconds: 30),
      );
      final body = await response
          .transform(utf8.decoder)
          .join()
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != HttpStatus.ok) {
        throw StateError(
          'Bitcoin RPC $method failed: HTTP ${response.statusCode}',
        );
      }
      final decoded = jsonDecode(body);
      if (decoded is! Map || decoded['error'] != null) {
        throw StateError('Bitcoin RPC $method failed');
      }
      return decoded['result'];
    } finally {
      client.close(force: true);
    }
  }
}
