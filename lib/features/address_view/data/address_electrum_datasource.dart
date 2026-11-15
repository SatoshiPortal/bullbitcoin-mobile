import 'dart:async';
import 'dart:convert';
import 'dart:io' show Socket;

import 'package:bb_mobile/core/electrum/data/electrum_socket_connector.dart';
import 'package:bb_mobile/core/electrum/domain/ports/electrum_servers_port.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_connection.dart';
import 'package:bb_mobile/core/electrum/domain/value_objects/electrum_server_url.dart';
import 'package:bb_mobile/features/address_view/data/address_overview_model.dart';
import 'package:bb_mobile/features/address_view/data/electrum_scripthash.dart';
import 'package:bb_mobile/features/electrum_settings/domain/electrum_server_network.dart';
import 'package:bb_mobile/features/wallet/public/wallet_facade.dart'
    show Network;
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_tor/tor.dart';

final class AddressNetworkUnsupportedException implements Exception {
  const AddressNetworkUnsupportedException();
}

final class AddressInvalidException implements Exception {
  const AddressInvalidException();
}

final class AddressElectrumException implements Exception {
  final String label;

  const AddressElectrumException(this.label);
}

typedef ScriptPubkeyResolver =
    List<int> Function(String address, Network network);

List<int> bdkScriptPubkey(String address, Network network) {
  final bdkNetwork = switch (network) {
    Network.bitcoinMainnet => bdk.Network.bitcoin,
    Network.bitcoinTestnet => bdk.Network.testnet,
    Network.bitcoinRegtest => bdk.Network.regtest,
    Network.liquidMainnet ||
    Network.liquidTestnet ||
    Network.liquidRegtest => throw const AddressNetworkUnsupportedException(),
  };
  try {
    return bdk.Address(
      address: address,
      network: bdkNetwork,
    ).scriptPubkey().toBytes();
  } catch (_) {
    throw const AddressInvalidException();
  }
}

class AddressElectrumDatasource {
  final ElectrumServersPort _servers;
  final ElectrumSocketConnector _socketConnector;
  final ScriptPubkeyResolver _scriptPubkey;

  const AddressElectrumDatasource({
    required this._servers,
    required this._socketConnector,
    this._scriptPubkey = bdkScriptPubkey,
  });

  Future<AddressOverviewModel> fetch({
    required String address,
    required Network network,
  }) async {
    final serverNetwork = switch (network) {
      Network.bitcoinMainnet => ElectrumServerNetwork.bitcoinMainnet,
      Network.bitcoinTestnet => ElectrumServerNetwork.bitcoinTestnet,
      Network.bitcoinRegtest => ElectrumServerNetwork.bitcoinRegtest,
      Network.liquidMainnet ||
      Network.liquidTestnet ||
      Network.liquidRegtest => throw const AddressNetworkUnsupportedException(),
    };
    final scripthash = electrumScripthash(_scriptPubkey(address, network));

    return _servers.runWithFallback(
      network: serverNetwork,
      operation: (connection) => _query(connection, scripthash),
    );
  }

  Future<AddressOverviewModel> _query(
    ElectrumConnection connection,
    String scripthash,
  ) async {
    final serverUri = ElectrumServerUrl(connection.url).uri;
    if (serverUri == null) {
      throw const AddressElectrumException('unusable server address');
    }

    final socks5 = connection.socks5?.trim();
    final hasProxy = socks5 != null && socks5.isNotEmpty;
    final proxy = hasProxy ? TorProxyEndpoint.tryParse(socks5) : null;
    if (hasProxy && proxy == null) {
      throw const AddressElectrumException('unusable SOCKS5 proxy');
    }

    final timeout = Duration(seconds: connection.effectiveTimeout);

    Socket? socket;
    try {
      socket = await _socketConnector.connect(
        server: serverUri,
        timeout: timeout,
        proxy: proxy,
        allowBadCertificate: !connection.validateDomain,
      );

      socket.writeln(
        json.encode({
          'id': AddressOverviewModel.balanceRequestId,
          'method': 'blockchain.scripthash.get_balance',
          'params': [scripthash],
        }),
      );
      socket.writeln(
        json.encode({
          'id': AddressOverviewModel.historyRequestId,
          'method': 'blockchain.scripthash.get_history',
          'params': [scripthash],
        }),
      );

      final lines = await utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .take(2)
          .toList()
          .timeout(timeout);

      return AddressOverviewModel.fromResponseLines(lines);
    } on AddressElectrumException {
      rethrow;
    } catch (e) {
      throw AddressElectrumException('${e.runtimeType}');
    } finally {
      socket?.destroy();
    }
  }
}
