import 'package:swaps/swaps.dart';

// The only substitutes are persistence/keychain and remote-chain backends.
// The database, row mapping, store, provider repository and driver are real.
class ReproKeychainBackend implements SecretStore {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class ReproChainBackend implements LockupChain {
  int knownLookups = 0;
  Future<bool> Function()? lookup;

  @override
  Future<String?> txidOf({
    required String signedTx,
    required bool isLiquid,
  }) async => 'a' * 64;

  @override
  Future<bool> isKnown({
    required String txid,
    required String signedTx,
    required bool isLiquid,
    required bool isTestnet,
  }) async {
    knownLookups++;
    final operation = lookup;
    return operation == null ? true : await operation();
  }

  @override
  Future<LockupBroadcast> broadcast({
    required String signedTx,
    required bool isLiquid,
    required bool isTestnet,
    void Function()? requireAdmission,
  }) => throw StateError('A known transaction must never be rebroadcast');
}

class ReproElectrumBackend implements ElectrumRunner {
  @override
  Future<T> run<T>({
    required bool isLiquid,
    required bool isTestnet,
    required Future<T> Function(ElectrumConnection) operation,
    bool Function(Object)? isTransient,
  }) => operation(
    const ElectrumConnection(
      url: 'tcp://127.0.0.1:1',
      validateDomain: false,
      timeout: 1,
    ),
  );

  @override
  Future<bool> usesCustomServers({
    required bool isLiquid,
    required bool isTestnet,
  }) async => true;
}
