import 'dart:isolate';

import 'package:bull_sdk/bdk.dart' as bdk;

import 'cbf_native_owner.dart';

import '../../domain/wallet_source_configuration.dart';

abstract interface class BdkCbfUpdate {
  void apply(bdk.Wallet wallet);
  void dispose();
}

final class _NativeCbfUpdate implements BdkCbfUpdate {
  final bdk.Update update;
  _NativeCbfUpdate(this.update);
  @override
  void apply(bdk.Wallet wallet) => wallet.applyUpdate(update: update);
  @override
  void dispose() => update.dispose();
}

abstract interface class BdkCbfReactiveNode {
  void run();
  Future<SendPort?> prepare();
  void renewLease();
  Map<String, BdkCbfUpdate>? pollUpdates();
  List<bdk.Info> drainInfo();
  void drainWarnings();
  bdk.CbfStatus status();
  bool get isTerminated;
  Future<void> submit(bdk.Transaction transaction);
  void shutdown();
  void dispose();
}

typedef BdkCbfReactiveNodeFactory =
    BdkCbfReactiveNode Function(
      List<bdk.Wallet> wallets,
      BdkCbfConfiguration configuration,
    );

final class NativeBdkCbfReactiveNode implements BdkCbfReactiveNode {
  final bdk.CbfComponents _components;

  CbfNativeOwner? _owner;
  bool _stopping = false;

  NativeBdkCbfReactiveNode.fromComponents(this._components);

  static BdkCbfReactiveNode create(
    List<bdk.Wallet> wallets,
    BdkCbfConfiguration configuration,
  ) {
    var builder = bdk.CbfBuilder();
    void replace(bdk.CbfBuilder next) {
      builder.dispose();
      builder = next;
    }

    try {
      replace(builder.connections(connections: 2));
      replace(
        builder.ownerLeaseMillis(
          ttlMillis: BdkCbfConfiguration.ownerLease.inMilliseconds,
        ),
      );
      replace(builder.configureTimeoutMillis(handshake: 2000, response: 5000));
      final port = configuration.socksPort;
      if (port != null) {
        final address = bdk.IpAddress.fromIpv4(q1: 127, q2: 0, q3: 0, q4: 1);
        try {
          replace(
            builder.socks5Proxy(
              proxy: bdk.Socks5Proxy(address: address, port: port),
            ),
          );
        } finally {
          address.dispose();
        }
      }
      // Multi-wallet construction requires the default SyncScanType. Recovery
      // anchors are persisted in the wallets before this call.
      return NativeBdkCbfReactiveNode.fromComponents(
        builder.buildWithWallets(wallets: wallets),
      );
    } finally {
      builder.dispose();
    }
  }

  @override
  void run() => _components.node.run();
  @override
  Future<SendPort?> prepare() async {
    final owner = await CbfNativeOwner.start(_components.client);
    _owner = owner;
    if (_stopping) owner.stopping();
    return owner.commands;
  }

  @override
  void renewLease() => _components.client.renewLease();
  @override
  Map<String, BdkCbfUpdate>? pollUpdates() => _components.client
      .pollUpdates()
      ?.map((id, update) => MapEntry(id, _NativeCbfUpdate(update)));
  @override
  List<bdk.Info> drainInfo() => _components.client.drainInfo();
  @override
  void drainWarnings() => _components.client.drainWarnings();
  @override
  bdk.CbfStatus status() => _components.client.status();
  @override
  bool get isTerminated => _components.node.isTerminated();
  @override
  Future<void> submit(bdk.Transaction transaction) {
    final owner = _owner;
    if (owner == null) throw StateError('CBF node was not prepared');
    return owner.submit(transaction.serialize());
  }

  @override
  void shutdown() {
    _stopping = true;
    _owner?.stopping();
    try {
      _components.client.shutdown();
    } on bdk.NodeStoppedCbfException {
      /* Join still required. */
    }
  }

  @override
  void dispose() {
    _components.client.dispose();
    _components.node.dispose();
  }
}
