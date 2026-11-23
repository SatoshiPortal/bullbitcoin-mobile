import 'package:preferences/preferences.dart'
    show ActiveEnvironmentReader, Environment;
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:signers/signers.dart' show SignerDevice;
import 'package:sync/sync.dart' show Wallet, WalletKey, SyncFailure;

import '../send_source.dart';
import '../send_failure.dart';

class LoadSendSourcesUsecase {
  final WalletInventory _inventory;
  final Future<Result<Wallet, SyncFailure>> Function(WalletKey) _loadWallet;
  final Future<Result<SignerDevice?, Failure>> Function(String) _readDevice;
  final ActiveEnvironmentReader _environment;
  final Future<Result<void, SyncFailure>> Function(WalletKey) _synchronize;
  final Stream<WalletKey> _finished;

  const LoadSendSourcesUsecase(
    this._inventory,
    this._loadWallet,
    this._readDevice,
    this._environment, {
    required Future<Result<void, SyncFailure>> Function(WalletKey) synchronize,
    required Stream<WalletKey> finished,
  }) : _synchronize = synchronize,
       _finished = finished;

  Future<Result<List<SendSource>, SendFailure>> execute() async {
    final Environment environment;
    switch (await _environment.readActiveEnvironment()) {
      case Ok(:final value):
        environment = value;
      case Err(:final failure):
        return Err(SendUnexpectedFailure(failure.logMessage));
    }
    final List<Network> networks = switch (environment) {
      Environment.mainnet => [BitcoinNetwork.mainnet, LiquidNetwork.mainnet],
      Environment.testnet => [BitcoinNetwork.testnet, LiquidNetwork.testnet],
      Environment.regtest => [BitcoinNetwork.regtest, LiquidNetwork.regtest],
    };
    final registrations = <WalletRegistration>[];
    for (final network in networks) {
      switch (await _inventory.walletsForNetwork(network)) {
        case Ok(:final value)
            when value.isComplete &&
                value.wallets.every((wallet) => wallet.network == network):
          registrations.addAll(value.wallets);
        case _:
          return const Err(
            SendUnexpectedFailure('Incomplete wallet inventory'),
          );
      }
    }
    if (registrations.isEmpty) {
      return const Err(
        SendUnexpectedFailure('No wallets for the active environment'),
      );
    }
    registrations.sort((a, b) => a.id.compareTo(b.id));
    final sources = <SendSource>[];
    for (final wallet in registrations) {
      switch (await _source(wallet)) {
        case Ok(:final value):
          sources.add(value);
        case Err(:final failure):
          return Err(failure);
      }
    }
    return Ok(sources);
  }

  Future<Result<SendSource?, SendFailure>> read(
    String id, {
    bool sync = false,
  }) async {
    switch (await _inventory.readWallet(id)) {
      case Err(failure: WalletRegistrationNotFoundFailure()):
        return const Ok(null);
      case Err(:final failure):
        return Err(SendUnexpectedFailure(failure.logMessage));
      case Ok(:final value) when value.id == id:
        return _source(value, synchronize: sync);
      case Ok():
        return const Err(SendUnexpectedFailure('Wallet identity mismatch'));
    }
  }

  Future<Result<SendSource, SendFailure>> _source(
    WalletRegistration wallet, {
    bool synchronize = false,
  }) async {
    final key = WalletKey(id: wallet.id, network: wallet.network);
    final SignerDevice? device;
    switch (await _readDevice(wallet.id)) {
      case Ok(:final value):
        device = value;
      case Err(:final failure):
        return Err(SendUnexpectedFailure(failure.logMessage));
    }
    if (synchronize) {
      if (await _synchronize(key) case Err(:final failure)) {
        return Err(SendUnexpectedFailure(failure.logMessage));
      }
    }
    final balance = switch (await _loadWallet(key)) {
      Ok(:final value) when value.key == key =>
        value.balances.now.data?.totalSat,
      _ => null,
    };
    if (synchronize && balance == null) {
      return const Err(SendUnexpectedFailure('Wallet balance unavailable'));
    }
    return Ok(SendSource(wallet, balance, device));
  }

  Stream<Result<SendSource?, SendFailure>> watchFinished(WalletKey key) =>
      _finished.where((event) => event == key).asyncMap((_) async {
        final result = await read(key.id);
        if (result case Ok(value: final source?)
            when source.network != key.network) {
          return const Err(SendUnexpectedFailure('Wallet identity mismatch'));
        }
        return result;
      });
}
