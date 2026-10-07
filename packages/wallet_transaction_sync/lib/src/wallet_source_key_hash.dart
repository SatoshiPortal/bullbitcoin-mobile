import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'domain/wallet_network_key.dart';

String walletSourceKeyHash(WalletNetworkKey key) =>
    hashWalletSourceParts(key.walletId, key.chain, key.network);

String hashWalletSourceParts(String walletId, String chain, String network) =>
    sha256
        .convert(utf8.encode('$walletId\u0000$chain\u0000$network'))
        .toString();
