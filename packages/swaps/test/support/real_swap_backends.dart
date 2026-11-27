import 'package:flutter_test/flutter_test.dart'
    show AutomatedTestWidgetsFlutterBinding;
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';
import 'package:primitives/primitives.dart' show NetworkEnv;
import 'package:swaps/swaps.dart';

// The only substitutes are persistence/keychain and remote-chain backends.
// The database, row mapping, store, provider repository and driver are real.
class ReproKeychainBackend extends FakeSecureStoragePlatform {
  Map<String, String> get values => entries;

  SwapKeychain get capability {
    install();
    return Secrets(
      authority: unlockedSessionAuthority(),
      scratchDirectory: () async => '/unused',
    ).swapKeychain;
  }
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
    required NetworkEnv environment,
  }) async {
    knownLookups++;
    final operation = lookup;
    return operation == null ? true : await operation();
  }

  @override
  Future<LockupBroadcast> broadcast({
    required String signedTx,
    required bool isLiquid,
    required NetworkEnv environment,
    void Function()? requireAdmission,
  }) => throw StateError('A known transaction must never be rebroadcast');
}

class ReproElectrumBackend implements ElectrumRunner {
  @override
  Future<T> run<T>({
    required bool isLiquid,
    required NetworkEnv environment,
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
    required NetworkEnv environment,
  }) async => true;
}

// These integration-style unit tests talk to their own loopback HTTP server.
// Keep plugin bindings without replacing the real transport with HTTP 400.
class SwapNetworkTestBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}
