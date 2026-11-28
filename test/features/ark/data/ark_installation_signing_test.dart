import 'package:ark/funding.dart';
import 'package:ark/ark.dart' show ArkWalletFailure;

import 'dart:io';

import 'package:bull_ark/ark_wallet_setup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

import 'ark_funding_test_fixture.dart';

final class _UnreadablePreferences extends InMemorySharedPreferencesAsync {
  _UnreadablePreferences() : super.empty();

  @override
  Future<Set<String>> getKeys(
    GetPreferencesParameters parameters,
    SharedPreferencesOptions options,
  ) async => throw const FormatException('Unreadable preferences inventory');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  SharedPreferencesAsyncPlatform? previousPreferences;
  setUp(() {
    directory = Directory.systemTemp.createTempSync('ark-never-provisioned-');
    previousPreferences = SharedPreferencesAsyncPlatform.instance;
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = previousPreferences;
    directory.deleteSync(recursive: true);
  });
  Future<ArkInstallationState> inspect() => ArkInstallationState.inspect(
    documents: directory,
    fundingPath: '${directory.path}/ark-funding.sqlite',
  );
  Future<Result<void, ArkWalletFailure>> admit(
    ArkInstallationState state, {
    Network network = BitcoinNetwork.regtest,
  }) => ArkFundingSigningGuard(authority: null, installation: state).admit(
    walletId: 'ordinary',
    network: network,
    unsignedPsbt: publicFundingPsbt,
  );

  test(
    'positive absence admits ordinary regtest without creating any Ark state',
    () async {
      final state = await inspect();
      expect(state.wasNeverProvisioned, isTrue);
      expect(await admit(state), isA<Ok>());
      expect(directory.listSync(), isEmpty);
    },
  );

  for (final name in [
    'ark',
    'ark-funding.sqlite',
    'ark-funding.sqlite.initialized',
    'ark-funding.sqlite-wal',
    'ark-funding.sqlite-shm',
    'ark-funding.sqlite-journal',
  ]) {
    test(
      'surviving $name denies signing and cannot become fresh after removal',
      () async {
        final file = File('${directory.path}/$name')
          ..writeAsStringSync('surviving custody');
        final state = await inspect();
        expect(state.wasNeverProvisioned, isFalse);
        expect(await admit(state), isA<Err>());
        file.deleteSync();
        expect(await admit(state), isA<Err>());
      },
    );
  }

  test(
    'initialized but incomplete account metadata refuses ordinary signing',
    () async {
      final ark = Directory('${directory.path}/ark')..createSync();
      File('${ark.path}/accounts.sqlite.initialized')
          .writeAsStringSync('ark-accounts:1\n');
      final state = await inspect();
      expect(await admit(state), isA<Err>());
      expect(File('${ark.path}/accounts.sqlite').existsSync(), isFalse);
    },
  );

  test('a broken Ark symlink cannot certify absence', () async {
    Link('${directory.path}/ark').createSync('${directory.path}/missing');
    expect(await admit(await inspect()), isA<Err>());
  });

  test(
    'a retained disabled preference is still evidence of prior provisioning',
    () async {
      await SharedPreferencesAsync().setBool(
        'ark.enabled.existing-account',
        false,
      );
      final state = await inspect();
      expect(state.wasNeverProvisioned, isFalse);
      expect(await admit(state), isA<Err>());
      await SharedPreferencesAsync().clear();
      expect(await admit(state), isA<Err>());
    },
  );

  test('fresh evidence is checked again when the signer is admitted', () async {
    final state = await inspect();
    expect(state.wasNeverProvisioned, isTrue);
    Directory('${directory.path}/ark').createSync();
    expect(await admit(state), isA<Err>());
    Directory('${directory.path}/ark').deleteSync();
    expect(await admit(state), isA<Err>());
  });

  test('unreadable preferences do not certify absence', () async {
    SharedPreferencesAsyncPlatform.instance = _UnreadablePreferences();
    final state = await inspect();
    expect(state.wasNeverProvisioned, isFalse);
    expect(await admit(state), isA<Err>());
  });

  test('missing preferences backend leaves absence unproven without crashing startup', () async {
    SharedPreferencesAsyncPlatform.instance = null;
    final state = await inspect();
    expect(state.wasNeverProvisioned, isFalse);
    expect(await admit(state), isA<Err>());
  });

  test('an unreadable documents inventory cannot certify absence', () async {
    directory.deleteSync();
    File(directory.path).writeAsStringSync('wrong entry type');
    final state = await inspect();
    expect(await admit(state), isA<Err>());
    File(directory.path).deleteSync();
    directory.createSync();
  });

  for (final network in LiquidNetwork.values) {
    test(
      'absence never admits an unsupported future/non-Bitcoin $network',
      () async {
        expect(await admit(await inspect(), network: network), isA<Err>());
      },
    );
  }
}
