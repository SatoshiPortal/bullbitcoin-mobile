import 'dart:async';

import 'package:bip85/src/domain/manage_bip85_usecase.dart';
import 'package:bip85/src/presentation/bip85_cubit.dart';
import 'package:bip85/src/presentation/bip85_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preferences/preferences.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/bip85.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

typedef _Revealed =
    Result<List<({Bip85Derivation derivation, String entropy})>, SecretFailure>;

class _Child extends Fake implements Bip85Derivation {}

class _Inventory extends Fake implements WalletInventory {
  @override
  Future<Result<WalletSelection, SecretFailure>> walletsForNetwork(
    Network network,
  ) async => Ok(
    walletSelectionForTesting([
      walletRegistrationForTesting(
        id: 'wallet-a',
        network: BitcoinNetwork.mainnet,
        isDefault: true,
        masterFingerprint: Fingerprint('0a1b2c3d'),
      ),
    ]),
  );
}

class _Preferences extends Fake implements ActiveEnvironmentReader {
  @override
  Future<Result<Environment, PreferencesFailure>>
  readActiveEnvironment() async => const Ok(Environment.mainnet);
}

class _Derivations extends Fake implements Bip85Derivations {
  var reveals = <Completer<_Revealed>>[];
  var renames = <Completer<Result<void, SecretFailure>>>[];

  @override
  Future<_Revealed> reveal(Fingerprint parent) {
    final gate = Completer<_Revealed>();
    reveals.add(gate);
    return gate.future;
  }

  @override
  Future<Result<void, SecretFailure>> rename(
    Bip85Derivation derivation,
    String? alias,
  ) {
    final gate = Completer<Result<void, SecretFailure>>();
    renames.add(gate);
    return gate.future;
  }
}

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  late _Derivations derivations;
  late StreamController<bool> locks;
  late Bip85EntropyCubit cubit;
  late List<Bip85EntropyState> states;

  setUp(() {
    derivations = _Derivations();
    locks = StreamController<bool>.broadcast(sync: true);
    cubit = Bip85EntropyCubit(
      ManageBip85Usecase(derivations, _Inventory(), _Preferences()),
      locks.stream,
    );
    states = [];
    final subscription = cubit.stream.listen(states.add);
    addTearDown(() async {
      await subscription.cancel();
      await cubit.close();
      await locks.close();
    });
  });

  test(
    'a revocation during a rename drops its result and its reload',
    () async {
      final pending = cubit.aliasDerivation(_Child(), 'label');
      await _settle();
      expect(cubit.state.isLoading, isTrue);

      locks.add(true);
      derivations.renames.single.complete(const Ok(null));
      await pending;
      await _settle();

      expect(
        derivations.reveals,
        isEmpty,
        reason: 'no reload for the old session',
      );
      expect(cubit.state.isLoading, isFalse);
      expect(cubit.state.derivations, isEmpty);
      expect(cubit.state.failure, isNull);
    },
  );

  test(
    'a revocation during a reveal publishes nothing and unlock reloads',
    () async {
      final init = cubit.init();
      await _settle();
      locks.add(true);
      derivations.reveals.single.complete(
        Ok([(derivation: _Child(), entropy: 'x')]),
      );
      await init;
      await _settle();

      expect(
        states.where((state) => state.derivations.isNotEmpty),
        isEmpty,
        reason: 'nothing the old session revealed reaches the screen',
      );

      locks.add(false);
      await _settle();
      expect(derivations.reveals, hasLength(2));
      derivations.reveals.last.complete(
        Ok([(derivation: _Child(), entropy: 'y')]),
      );
      await _settle();
      expect(cubit.state.derivations, hasLength(1));
    },
  );
}
