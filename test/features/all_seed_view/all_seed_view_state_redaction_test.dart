import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/bloc_observer.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/all_seed_view/presentation/all_seed_view_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

// Obviously-fake fixtures: the all-zero BIP39 test vector and a joke
// passphrase.
const _words = [
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'abandon',
  'about',
];
const _passphrase = 'hunter2';

class _Holder extends Cubit<AllSeedViewState> {
  _Holder(super.initialState);

  void put(AllSeedViewState next) => emit(next);
}

void main() {
  MnemonicSeed seed(String fingerprint) =>
      Seed.mnemonic(
            mnemonicWords: _words,
            passphrase: _passphrase,
            bytes: Uint8List.fromList(List<int>.generate(64, (i) => i)),
            masterFingerprint: fingerprint,
          )
          as MnemonicSeed;

  late AllSeedViewState state;

  setUp(() {
    state = AllSeedViewState(
      existingWallets: [seed('73c5da0a')],
      oldWallets: [seed('01234567')],
      loading: false,
      isUnlocked: true,
    );
  });

  Matcher redacted() => allOf(
    isNot(contains('abandon')),
    isNot(contains('about')),
    isNot(contains(_passphrase)),
  );

  test('the state carrying the seeds does not print them', () {
    // `AllSeedViewState` holds every wallet's mnemonic. Its Freezed
    // `toString` interpolates the lists, so the protection has to come from
    // `MnemonicSeed.toString` itself.
    expect(state.toString(), redacted());
    expect(state.allSeeds.toString(), redacted());
  });

  test('the bloc observer log line does not print them', () {
    // `AppBlocObserver.onChange` formats exactly this line. It is currently
    // behind a hardcoded `_showConsoleLogs = false`, and this test exists so
    // that flipping that flag back on cannot leak seeds: the line is built
    // here the same way, unconditionally.
    final holder = _Holder(const AllSeedViewState());
    addTearDown(holder.close);
    final change = Change(currentState: holder.state, nextState: state);

    final line =
        'State in bloc ${holder.runtimeType} changed from '
        '${change.currentState} to ${change.nextState}';
    expect(line, redacted());

    // And the observer itself stays silent while the flag is off.
    expect(() => AppBlocObserver().onChange(holder, change), returnsNormally);
  });

  test('the line survives a round trip through the log file', () async {
    final dir = Directory.systemTemp.createTempSync('bb_seed_state_log');
    addTearDown(() => dir.deleteSync(recursive: true));
    final logger = Logger.replace(directory: dir);
    await logger.ensureLogsExist();

    logger.fine('State in bloc AllSeedViewCubit changed from x to $state');
    await logger.flush();

    expect(await logger.logsFile.readAsString(), redacted());
  });
}
