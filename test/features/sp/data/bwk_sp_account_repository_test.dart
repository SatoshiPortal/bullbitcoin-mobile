import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:bb_mobile/features/sp/data/bwk_sp_account_repository.dart';
import 'package:bb_mobile/features/sp/data/datasources/bwk_sp_account_datasource.dart';
import 'package:bb_mobile/features/sp/data/datasources/sp_account_files_datasource.dart';
import 'package:bb_mobile/features/sp/data/sp_storage_names.dart';
import 'package:bb_mobile/features/sp/domain/entities/sp_tx_draft.dart';
import 'package:bb_mobile/features/sp/domain/sp_failure.dart';
import 'package:bull_sdk/bdk.dart' as bdk;
import 'package:bull_sdk/bull_sdk.dart';
import 'package:bull_sdk/bwk.dart';
// The FFI entry point's interface: the custody package signs through bwk's
// stateless signer, which a test observes in place of the native library.
// ignore: implementation_imports
import 'package:bull_sdk/src/rust/frb_generated.dart' show BullSdkApi;
import 'package:convert/convert.dart' as convert;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:primitives/primitives.dart';
import 'package:secrets/secrets.dart';
import 'package:secrets/testing.dart';

import '../sp_fakes.dart';

// Tests for the live-session side of the adapter. No real FFI session is ever
// established: the datasource is injected, so a fake stands in for the Rust
// account and every error the boundary is supposed to map can be thrown at it.
// The account directory has its own adapter and its own test.

/// The live bwk account, as far as a send reaches it: finalize and the
/// receiving path. Every member it does not stub throws.
class _MockSpAccount extends Mock implements SpAccount {}

/// Stands in for the FFI entry point, answering bwk's silent payments signer
/// only: records what the custody package lent it and returns [signed], or
/// throws [error]. [onSign] runs inside the call, so a test can change the
/// session while the PSBT is being signed.
final class _SignerApi implements BullSdkApi {
  int calls = 0;
  List<int>? psbt;
  String? spendAtCall;
  String? xprv;
  Uint8List signed = _signedPsbt;
  Object? error;
  void Function()? onSign;

  void reset() {
    calls = 0;
    psbt = spendAtCall = xprv = error = onSign = null;
    signed = _signedPsbt;
  }

  @override
  Future<Uint8List> dartBwkApiSpSignerSignSilentPaymentPsbt({
    required List<int> psbt,
    required List<int> bSpend,
    String? taprootAccountXprv,
  }) async {
    calls++;
    this.psbt = List.of(psbt);
    spendAtCall = convert.hex.encode(bSpend);
    xprv = taprootAccountXprv;
    onSign?.call();
    final failure = error;
    if (failure != null) throw failure;
    return signed;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnsupportedError('${invocation.memberName}');
}

/// Stands in for the bwk FFI. [disposeError] models a "dispose timed out",
/// where the inner lock is still held.
class _FakeFfiDatasource extends BwkSpAccountDatasource {
  _FakeFfiDatasource({
    this.session = true,
    this.disposeError,
    this.stopScanError,
    this.scanOnceError,
    this.createError,
    SpAccount? account,
  }) : account = account ?? _MockSpAccount();

  final Object? disposeError;
  final Object? createError;

  /// The live account. A test may swap it to model a session replaced while
  /// a call was in flight.
  SpAccount account;
  final Map<String, TxSimulation> simulations = {};
  final _notifications = StreamController<SpNotification>.broadcast();

  /// What reached the broadcast, so a test can assert the signed bytes.
  String? broadcastHex;

  /// The descriptors the most recent create was handed, so a test can assert
  /// what crossed the FFI boundary.
  ({SpNetwork network, String sp, String taproot})? createdWith;
  final Object? stopScanError;
  final Object? scanOnceError;
  bool session;

  @override
  bool get hasSession => session;

  @override
  Future<void> dispose() async {
    final error = disposeError;
    if (error != null) throw error;
    session = false;
  }

  @override
  Future<void> createFromDescriptors({
    required SpNetwork network,
    required String spDescriptor,
    required String taprootDescriptor,
    required String blindbitUrl,
    required String electrumUrl,
    required String dataDir,
    required int fetchConcurrencyFactor,
    required int matchConcurrencyFactor,
  }) async {
    final error = createError;
    if (error != null) throw error;
    createdWith = (
      network: network,
      sp: spDescriptor,
      taproot: taprootDescriptor,
    );
    session = true;
  }

  @override
  void setElectrumUrl(String url) {}

  @override
  Future<void> startElectrum() async {}

  @override
  Stream<SpNotification> init() => _notifications.stream;

  // Mirrors the real datasource: no live session, no account.
  @override
  SpAccount get liveAccount =>
      session ? account : throw StateError('no live SP session');

  @override
  SpNetwork network() => SpNetwork.bitcoin;

  @override
  TxSimulation? pinnedSimulation(String id) => simulations[id];

  @override
  Future<void> broadcast({required String txHex}) async {
    broadcastHex = txHex;
    _notifications.add(const SpNotification.broadcasted(txid: 'txid-1'));
  }

  @override
  Future<void> stopScan() async {
    final error = stopScanError;
    if (error != null) throw error;
  }

  @override
  Future<void> scanOnce({int? startHeight}) async {
    final error = scanOnceError;
    if (error != null) throw error;
  }
}

/// The test keystore, with a hook run on every read: lets a test change the
/// session while the secret is being fetched.
class _HookedStorage extends FakeSecureStoragePlatform {
  _HookedStorage({required super.entries, required this.onRead});

  final void Function() onRead;

  @override
  Future<String?> read({
    required String key,
    required Map<String, String> options,
  }) {
    onRead();
    return super.read(key: key, options: options);
  }
}

void main() {
  late Directory tempDir;
  late FakeSecureStoragePlatform storage;
  late Secrets secrets;
  late SilentPaymentDescriptors scanKey;
  final signer = _SignerApi();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(_simulation());
    BullSdk.initMock(api: signer);
    storage = FakeSecureStoragePlatform()..install();
    secrets = Secrets(scratchDirectory: () async => Directory.systemTemp.path);
    final stored = await secrets.import(words: spTestWords);
    final secret = (stored as Ok<Secret, SecretFailure>).value;
    scanKey =
        (await secret.derive.descriptors.silentPayment(
                  network: BitcoinNetwork.mainnet,
                )
                as Ok<SilentPaymentDescriptors, SecretFailure>)
            .value;
  });

  setUp(() {
    signer.reset();
    tempDir = Directory.systemTemp.createTempSync('sp_repo_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          return tempDir.path;
        });
  });

  tearDown(() {
    storage.locked = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // best-effort; some tests intentionally leave locked state
      }
    }
  });

  BwkSpAccountRepository makeRepo({BwkSpAccountDatasource? ffi}) =>
      BwkSpAccountRepository(
        ffi: ffi ?? BwkSpAccountDatasource(),
        files: SpAccountFilesDatasource(),
        secrets: secrets,
      );

  Directory accountDirOf() =>
      Directory('${tempDir.path}/${SpStorageNames.accountName}');

  Future<Result<void, SpFailure>> createOn(BwkSpAccountRepository repo) =>
      repo.createFromScanKey(
        scanKey: scanKey,
        blindbitUrl: 'http://blindbit.example',
        electrumUrl: 'tcp://electrum.example:50001',
      );

  group('createFromScanKey lock clearing', () {
    test(
      'clears every stale advisory lock before opening the account',
      () async {
        accountDirOf().createSync();
        final locks = [
          for (final name in SpStorageNames.lockFiles)
            File('${accountDirOf().path}/$name')..writeAsStringSync(''),
        ];
        expect(locks.every((f) => f.existsSync()), isTrue);

        // The FFI create cannot run in a unit test, so it fails. The lock
        // clearing happens first, which is what this asserts.
        await createOn(makeRepo(ffi: _FakeFfiDatasource(session: false)));

        expect(locks.every((f) => f.existsSync()), isFalse);
      },
    );

    test('the header store lock is one of the cleared locks', () {
      expect(SpStorageNames.lockFiles, contains(SpStorageNames.headerLockFile));
    });
  });

  group('createFromScanKey single-owner guard', () {
    test('a live session is refused instead of opening a second one', () async {
      final repo = makeRepo(ffi: _FakeFfiDatasource());

      final created = await createOn(repo);

      expect(
        (created as Err<void, SpFailure>).failure,
        isA<SpSessionBusy>(),
        reason: 'a second live SpAccount would leak the first one',
      );
      expect(repo.hasSession, isTrue, reason: 'the guard disposes nothing');
      expect(accountDirOf().existsSync(), isFalse);
    });

    test('the refused create leaves the stale locks alone', () async {
      // The strong form of "bails before doing any work": lock clearing runs
      // right after the guard, so a surviving lock pins the early return.
      accountDirOf().createSync();
      final lock = File('${accountDirOf().path}/${SpStorageNames.lockFile}')
        ..writeAsStringSync('');

      await createOn(makeRepo(ffi: _FakeFfiDatasource()));

      expect(lock.existsSync(), isTrue);
    });
  });

  group('dispose stream teardown', () {
    test(
      'a clean session dispose tears down the notification streams',
      () async {
        final repo = makeRepo(ffi: _FakeFfiDatasource());

        expect(await repo.dispose(), isA<Ok<void, SpFailure>>());

        expect(repo.notifStreamTornDown, isTrue);
      },
    );

    test(
      'a timed-out session dispose keeps the streams and session live',
      () async {
        final repo = makeRepo(
          ffi: _FakeFfiDatasource(
            disposeError: const SpError.disposeTimedOut(),
          ),
        );

        final disposed = await repo.dispose();

        expect(
          (disposed as Err<void, SpFailure>).failure,
          isA<SpSessionBusy>(),
          reason: 'the timeout must reach the caller as its own failure',
        );
        // The stream plumbing is NOT torn down, so the still-live session keeps
        // pushing notifications instead of going dark on a transient timeout.
        expect(repo.notifStreamTornDown, isFalse);
        expect(repo.hasSession, isTrue);
        expect(repo.isScanningCached, isFalse);
      },
    );

    test('dispose with no session is a no-op', () async {
      final repo = makeRepo(ffi: _FakeFfiDatasource(session: false));

      expect(await repo.dispose(), isA<Ok<void, SpFailure>>());
      expect(repo.notifStreamTornDown, isFalse);
    });
  });

  group('teardown bracket', () {
    test('a nested teardown keeps the guard held for the outer one', () {
      final repo = makeRepo(ffi: _FakeFfiDatasource());

      repo.beginTeardown(); // recreate
      repo.beginTeardown(); // revoke, started while the recreate runs
      repo.endTeardown(); // revoke finishes first

      expect(
        repo.teardownInProgress,
        isTrue,
        reason: 'the recreate still holds it, so no self-heal may create',
      );

      repo.endTeardown();

      expect(repo.teardownInProgress, isFalse);
    });

    test('an unbalanced release cannot drive the depth negative', () {
      final repo = makeRepo(ffi: _FakeFfiDatasource());

      repo.endTeardown();
      repo.beginTeardown();

      expect(repo.teardownInProgress, isTrue);
    });
  });

  group('scanOnce and the scanning flag', () {
    test('a refused scan leaves the running scan owning the flag', () async {
      final repo = makeRepo(
        ffi: _FakeFfiDatasource(
          scanOnceError: const SpError.scannerAlreadyRunning(),
        ),
      );

      final result = await repo.scanOnce();

      expect((result as Err<void, SpFailure>).failure, isA<SpScanBusy>());
      expect(
        repo.isScanningCached,
        isTrue,
        reason: 'the winner of the race still has a scan running',
      );
    });

    test('any other failure clears the flag this call set', () async {
      final repo = makeRepo(
        ffi: _FakeFfiDatasource(
          scanOnceError: const SpError.other(message: 'boom'),
        ),
      );

      final result = await repo.scanOnce();

      expect((result as Err<void, SpFailure>).failure, isA<SpUnexpected>());
      expect(repo.isScanningCached, isFalse);
    });

    test('a started scan holds the flag', () async {
      final repo = makeRepo(ffi: _FakeFfiDatasource());

      final result = await repo.scanOnce();

      expect(result, isA<Ok<void, SpFailure>>());
      expect(repo.isScanningCached, isTrue);
    });
  });

  group('FFI error mapping', () {
    // Asserted through a real call rather than the mapper in isolation, so the
    // test also pins that the boundary actually routes throws through it.
    Future<SpFailure> failureFromStopScan(Object thrown) async {
      final repo = makeRepo(ffi: _FakeFfiDatasource(stopScanError: thrown));
      return (await repo.stopScan() as Err<void, SpFailure>).failure;
    }

    test('a drifted simulation maps to SpSimulationDrifted', () async {
      final failure = await failureFromStopScan(
        const SpError.simulationDrifted(detail: 'coin abc:0 not found'),
      );

      expect(failure, isA<SpSimulationDrifted>());
      expect(failure.logMessage, contains('abc:0'));
    });

    test('a dispose timeout maps to SpSessionBusy', () async {
      expect(
        await failureFromStopScan(const SpError.disposeTimedOut()),
        isA<SpSessionBusy>(),
      );
    });

    test('a running scanner maps to SpScanBusy', () async {
      expect(
        await failureFromStopScan(const SpError.scannerAlreadyRunning()),
        isA<SpScanBusy>(),
      );
    });

    test('refused descriptors map to SpCredentialRefused, without bwk\'s '
        'reason', () async {
      final failure = await failureFromStopScan(
        const SpError.invalidDescriptor(reason: 'sp(secret)'),
      );

      expect(failure, isA<SpCredentialRefused>());
      expect(failure.logMessage, isNot(contains('secret')));
    });

    test(
      'a signer refusal maps to SpSigningRefused, without bwk\'s reason',
      () async {
        final failure = await failureFromStopScan(
          const SpError.signing(reason: 'input 0'),
        );

        expect(failure, isA<SpSigningRefused>());
        expect(failure.logMessage, isNot(contains('input 0')));
      },
    );

    test(
      'a signed PSBT that differs maps to SpSignedTransactionMismatch',
      () async {
        expect(
          await failureFromStopScan(
            const SpError.signedPsbtMismatch(detail: 'fee differs'),
          ),
          isA<SpSignedTransactionMismatch>(),
        );
      },
    );

    test('a failed verification maps to SpVerificationFailed', () async {
      expect(
        await failureFromStopScan(
          const SpError.verification(reason: 'dleq proof'),
        ),
        isA<SpVerificationFailed>(),
      );
    });

    test('anything else maps to the catch-all', () async {
      expect(
        await failureFromStopScan(const SpError.other(message: 'boom')),
        isA<SpUnexpected>(),
      );
      expect(
        await failureFromStopScan(StateError('not an SpError')),
        isA<SpUnexpected>(),
      );
    });
  });

  group('createFromScanKey session credential', () {
    test('opens a watch-only account from the scan credential and remembers '
        'which secret it watches', () async {
      final ffi = _FakeFfiDatasource(session: false);
      final repo = makeRepo(ffi: ffi);

      expect(await createOn(repo), isA<Ok<void, SpFailure>>());

      expect(ffi.createdWith, (
        network: SpNetwork.bitcoin,
        sp: scanKey.sp,
        taproot: scanKey.taproot,
      ));
      expect(repo.sessionFingerprint, scanKey.fingerprint);
    });

    test('forgets the secret once the session is disposed', () async {
      final repo = makeRepo(ffi: _FakeFfiDatasource(session: false));
      await createOn(repo);

      expect(await repo.dispose(), isA<Ok<void, SpFailure>>());

      expect(repo.sessionFingerprint, isNull);
    });

    test('a failed create remembers nothing and reports fixed text', () async {
      final repo = makeRepo(
        ffi: _FakeFfiDatasource(
          session: false,
          createError: SpError.other(message: scanKey.sp),
        ),
      );

      final failure = (await createOn(repo) as Err<void, SpFailure>).failure;

      expect(failure, isA<SpUnexpected>());
      expect(failure.logMessage, 'SP account create failed');
      expect(repo.sessionFingerprint, isNull);
    });

    test(
      'refused descriptors are SpCredentialRefused, with fixed text',
      () async {
        final repo = makeRepo(
          ffi: _FakeFfiDatasource(
            session: false,
            createError: SpError.invalidDescriptor(reason: scanKey.sp),
          ),
        );

        final failure = (await createOn(repo) as Err<void, SpFailure>).failure;

        expect(failure, isA<SpCredentialRefused>());
        expect(failure.logMessage, 'SP account create refused its descriptors');
        expect(repo.sessionFingerprint, isNull);
      },
    );
  });

  group('finalizeSignBroadcast signs through the custody package and '
      'finalizes on the live account', () {
    final simulation = _simulation();
    final draft = SpTxDraft(
      id: 'draft-1',
      inputs: [],
      outputs: [],
      feeSat: Sats.zero,
      changeSat: Sats.zero,
    );

    late _MockSpAccount account;
    late _FakeFfiDatasource ffi;

    Future<BwkSpAccountRepository> openSession() async {
      account = _MockSpAccount();
      ffi = _FakeFfiDatasource(session: false, account: account);
      ffi.simulations[draft.id] = simulation;
      final repo = makeRepo(ffi: ffi);
      expect(await createOn(repo), isA<Ok<void, SpFailure>>());
      return repo;
    }

    void stubFinalize(Future<Uint8List> Function() answer) {
      when(
        () => account.finalize(
          simulation: any(named: 'simulation'),
          signedPsbt: any(named: 'signedPsbt'),
        ),
      ).thenAnswer((_) => answer());
      _stubOwned(account, _recognisedChange());
    }

    void verifyNeverFinalized(_MockSpAccount a) => verifyNever(
      () => a.finalize(
        simulation: any(named: 'simulation'),
        signedPsbt: any(named: 'signedPsbt'),
      ),
    );

    test('lends the spend keys to bwk\'s signer for the pinned PSBT, '
        'finalizes the signed PSBT on the same account and broadcasts the '
        'transaction as hex', () async {
      final repo = await openSession();
      final tx = _signedTx();
      stubFinalize(() async => tx);

      final result = await repo.finalizeSignBroadcast(draft: draft);

      expect((result as Ok<String, SpFailure>).value, 'txid-1');
      expect(ffi.broadcastHex, _hex(tx));
      expect(signer.calls, 1);
      expect(signer.psbt, simulation.psbt);
      expect(signer.spendAtCall, matches(RegExp(r'^[0-9a-f]{64}$')));
      expect(
        signer.xprv,
        startsWith('xprv'),
        reason: 'the mainnet BIP86 account key, never the master key',
      );
      final captured = verify(
        () => account.finalize(
          simulation: captureAny(named: 'simulation'),
          signedPsbt: captureAny(named: 'signedPsbt'),
        ),
      ).captured;
      expect(captured[0], same(simulation));
      expect(captured[1], _signedPsbt);
    });

    test('a coin set drifted since the simulation maps to SpSimulationDrifted '
        'so the user is asked to confirm again', () async {
      final repo = await openSession();
      stubFinalize(
        () async =>
            throw const SpError.simulationDrifted(detail: 'coin abc:0 gone'),
      );

      final result = await repo.finalizeSignBroadcast(draft: draft);

      expect((result as Err).failure, isA<SpSimulationDrifted>());
      expect(ffi.broadcastHex, isNull, reason: 'nothing is broadcast');
    });

    test('a signed PSBT that differs from its simulation maps to '
        'SpSignedTransactionMismatch', () async {
      final repo = await openSession();
      stubFinalize(
        () async =>
            throw const SpError.signedPsbtMismatch(detail: 'fee differs'),
      );

      final result = await repo.finalizeSignBroadcast(draft: draft);

      expect((result as Err).failure, isA<SpSignedTransactionMismatch>());
      expect(ffi.broadcastHex, isNull);
    });

    test('a failed BIP375 verification maps to SpVerificationFailed', () async {
      final repo = await openSession();
      stubFinalize(
        () async => throw const SpError.verification(reason: 'dleq proof'),
      );

      final result = await repo.finalizeSignBroadcast(draft: draft);

      expect((result as Err).failure, isA<SpVerificationFailed>());
      expect(ffi.broadcastHex, isNull);
    });

    test(
      'a locked keystore maps to SpKeystoreLocked and never reaches bwk',
      () async {
        final repo = await openSession();
        storage.locked = true;

        final result = await repo.finalizeSignBroadcast(draft: draft);

        expect((result as Err).failure, isA<SpKeystoreLocked>());
        expect(signer.calls, 0);
        verifyNeverFinalized(account);
        expect(ffi.broadcastHex, isNull);
      },
    );

    test('a PSBT the signer refuses is SpSigningRefused with the type only, '
        'and nothing is finalized', () async {
      final repo = await openSession();
      signer.error = const SpError.signing(reason: 'input 0 is not ours');

      final result = await repo.finalizeSignBroadcast(draft: draft);

      final failure = (result as Err).failure;
      expect(failure, isA<SpSigningRefused>());
      expect(failure.logMessage, isNot(contains('input 0')));
      verifyNeverFinalized(account);
      expect(ffi.broadcastHex, isNull);
    });

    test('without a live session nothing is signed', () async {
      final repo = makeRepo(ffi: _FakeFfiDatasource(session: false));

      final result = await repo.finalizeSignBroadcast(draft: draft);

      expect((result as Err).failure, isA<SpSimulationDrifted>());
      expect(signer.calls, 0);
    });

    Future<Result<String, SpFailure>> signWhileFetching(
      void Function() change,
    ) async {
      final repo = await openSession();
      _HookedStorage(entries: storage.entries, onRead: change).install();
      try {
        return await repo.finalizeSignBroadcast(draft: draft);
      } finally {
        storage.install();
      }
    }

    test('a session disposed while the secret is fetched is reported as no '
        'session, not thrown', () async {
      final result = await signWhileFetching(() => ffi.session = false);

      expect((result as Err).failure, isA<SpNotSetUp>());
      expect(signer.calls, 0);
      verifyNeverFinalized(account);
      expect(ffi.broadcastHex, isNull);
    });

    test('a session replaced while the secret is fetched signs nothing and '
        'finalizes on neither account', () async {
      final replacement = _MockSpAccount();

      final result = await signWhileFetching(() => ffi.account = replacement);

      expect((result as Err).failure, isA<SpNotSetUp>());
      expect(signer.calls, 0);
      verifyNeverFinalized(account);
      verifyNeverFinalized(replacement);
      expect(ffi.broadcastHex, isNull);
    });

    test('a session replaced while the PSBT is signed finalizes on neither '
        'account', () async {
      final repo = await openSession();
      final replacement = _MockSpAccount();
      signer.onSign = () => ffi.account = replacement;

      final result = await repo.finalizeSignBroadcast(draft: draft);

      expect((result as Err).failure, isA<SpNotSetUp>());
      verifyNeverFinalized(account);
      verifyNeverFinalized(replacement);
      expect(ffi.broadcastHex, isNull);
    });
  });

  group('finalizeSignBroadcast checks the signed transaction against the '
      'simulation', () {
    final draft = SpTxDraft(
      id: 'draft-1',
      inputs: [],
      outputs: [],
      feeSat: Sats.zero,
      changeSat: Sats.zero,
    );

    late _MockSpAccount account;
    late _FakeFfiDatasource ffi;

    Future<BwkSpAccountRepository> signing(
      Uint8List tx, {
      TxSimulation? simulation,
      Future<List<SpOwnedOutput>> Function()? owned,
    }) async {
      account = _MockSpAccount();
      ffi = _FakeFfiDatasource(session: false, account: account);
      ffi.simulations[draft.id] = simulation ?? _simulation();
      final repo = makeRepo(ffi: ffi);
      expect(await createOn(repo), isA<Ok<void, SpFailure>>());
      when(
        () => account.finalize(
          simulation: any(named: 'simulation'),
          signedPsbt: any(named: 'signedPsbt'),
        ),
      ).thenAnswer((_) async => tx);
      if (owned != null) {
        when(
          () => account.ownedOutputs(txBytes: any(named: 'txBytes')),
        ).thenAnswer((_) => owned());
      } else {
        _stubOwned(account, _recognisedChange());
      }
      return repo;
    }

    Future<void> expectRefused(BwkSpAccountRepository repo) async {
      final result = await repo.finalizeSignBroadcast(draft: draft);

      expect((result as Err).failure, isA<SpSignedTransactionMismatch>());
      expect(ffi.broadcastHex, isNull, reason: 'nothing is broadcast');
    }

    test('a transaction that matches is broadcast, its outputs matched by '
        'index whatever order the simulation lists them in', () async {
      final signed = _signedTx();
      final repo = await signing(
        signed,
        simulation: _simulation(reversed: true),
      );

      final result = await repo.finalizeSignBroadcast(draft: draft);

      expect((result as Ok<String, SpFailure>).value, 'txid-1');
      expect(ffi.broadcastHex, _hex(signed));
    });

    test('an extra input is refused', () async {
      final repo = await signing(
        _signedTx(inputs: [..._simulatedInputs, ('c' * 64, 2)]),
      );

      await expectRefused(repo);
    });

    test('a missing input is refused', () async {
      final repo = await signing(_signedTx(inputs: [_simulatedInputs.first]));

      await expectRefused(repo);
    });

    test('a different input is refused', () async {
      final repo = await signing(
        _signedTx(inputs: [_simulatedInputs.first, ('b' * 64, 0)]),
      );

      await expectRefused(repo);
    });

    test('a wrong amount is refused', () async {
      final repo = await signing(
        _signedTx(
          outputs: [
            (_standardSat, _standardScript()),
            (_spSat - 500, _p2tr(0x22)),
            (_changeSat, _p2tr(0x33)),
          ],
        ),
      );

      await expectRefused(repo);
    });

    test('the standard recipient amount moved to another output is refused '
        'even though the amounts are unchanged', () async {
      final repo = await signing(
        _signedTx(
          outputs: [
            (_spSat, _standardScript()),
            (_standardSat, _p2tr(0x22)),
            (_changeSat, _p2tr(0x33)),
          ],
        ),
      );

      await expectRefused(repo);
    });

    test('the standard recipient paid to another script is refused', () async {
      final repo = await signing(
        _signedTx(
          outputs: [
            (_standardSat, _p2tr(0x44)),
            (_spSat, _p2tr(0x22)),
            (_changeSat, _p2tr(0x33)),
          ],
        ),
      );

      await expectRefused(repo);
    });

    test('a fee other than the simulated one is refused', () async {
      final repo = await signing(
        _signedTx(),
        simulation: _simulation(feeSat: _feeSat - 100),
      );

      await expectRefused(repo);
    });

    test('an extra output is refused', () async {
      final repo = await signing(
        _signedTx(outputs: [..._simulatedOutputs(), (546, _p2tr(0x55))]),
      );

      await expectRefused(repo);
    });

    test('a missing change output is refused', () async {
      final repo = await signing(
        _signedTx(outputs: _simulatedOutputs().take(2).toList()),
      );

      await expectRefused(repo);
    });

    test('a silent payment output that is not taproot is refused', () async {
      final repo = await signing(
        _signedTx(
          outputs: [
            (_standardSat, _standardScript()),
            (_spSat, _standardScript()),
            (_changeSat, _p2tr(0x33)),
          ],
        ),
      );

      await expectRefused(repo);
    });

    test('a simulation that pays another silent payment address than the '
        'confirmed recipient is refused', () async {
      final repo = await signing(
        _signedTx(),
        simulation: _simulation(paidSpAddress: 'sp1-someone-else'),
      );

      await expectRefused(repo);
    });

    test('a simulation whose change does not add up is refused', () async {
      final repo = await signing(
        _signedTx(),
        simulation: _simulation(changeSat: _changeSat, statedChangeSat: 1),
      );

      await expectRefused(repo);
    });

    test('bytes that are not a transaction are refused', () async {
      final repo = await signing(Uint8List.fromList([0x02, 0x00, 0xab]));

      await expectRefused(repo);
    });

    test('the receiving path is asked about the extracted transaction, on '
        'the account that finalized it', () async {
      final signed = _signedTx();
      final repo = await signing(signed);

      await repo.finalizeSignBroadcast(draft: draft);

      final captured = verify(
        () => account.ownedOutputs(txBytes: captureAny(named: 'txBytes')),
      ).captured;
      expect(captured.single, signed);
    });

    test('change the receiving path does not recognise is refused', () async {
      final repo = await signing(
        _signedTx(),
        owned: () async => [
          SpOwnedOutput(
            vout: 2,
            amountSat: BigInt.from(_changeSat),
            isChange: false,
          ),
        ],
      );

      await expectRefused(repo);
    });

    test('change of another amount is refused', () async {
      final repo = await signing(
        _signedTx(),
        owned: () async => _recognisedChange(sat: _changeSat - 1),
      );

      await expectRefused(repo);
    });

    test('two change outputs are refused', () async {
      final repo = await signing(
        _signedTx(),
        owned: () async => [
          ..._recognisedChange(),
          ..._recognisedChange(vout: 1),
        ],
      );

      await expectRefused(repo);
    });

    test('change found where none was simulated is refused', () async {
      final simulation = _simulation(
        changeSat: 0,
        feeSat: _feeSat + _changeSat,
      );
      final repo = await signing(
        _signedTx(outputs: _simulatedOutputs().take(2).toList()),
        simulation: simulation,
        owned: () async => _recognisedChange(sat: 546),
      );

      await expectRefused(repo);
    });

    test('without change, a transaction whose owned outputs hold no change '
        'is broadcast', () async {
      final simulation = _simulation(
        changeSat: 0,
        feeSat: _feeSat + _changeSat,
      );
      final signed = _signedTx(outputs: _simulatedOutputs().take(2).toList());
      final repo = await signing(
        signed,
        simulation: simulation,
        owned: () async => const [],
      );

      final result = await repo.finalizeSignBroadcast(draft: draft);

      expect((result as Ok<String, SpFailure>).value, 'txid-1');
      expect(ffi.broadcastHex, _hex(signed));
    });

    test('a receiving path that fails is refused with fixed text', () async {
      final repo = await signing(
        _signedTx(),
        owned: () async =>
            throw const SpError.other(message: 'input not owned: secret'),
      );

      final result = await repo.finalizeSignBroadcast(draft: draft);

      final failure = (result as Err).failure;
      expect(failure, isA<SpSignedTransactionMismatch>());
      expect(failure.logMessage, isNot(contains('secret')));
      expect(ffi.broadcastHex, isNull, reason: 'nothing is broadcast');
    });
  });
}

// A pinned simulation and the transaction bwk would extract for it: two inputs,
// a standard recipient, a silent payment recipient and change, at vouts 0, 1
// and 2.
const _standardAddress = 'bc1qar0srrr7xfkvy5l643lydnw9re59gtzzwf5mdq';
const _spAddress = 'sp1-recipient';
const _standardSat = 40000;
const _spSat = 30000;
const _changeSat = 39000;
const _feeSat = 1000;
final _simulatedInputs = <(String, int)>[('a' * 64, 0), ('b' * 64, 1)];

/// The unsigned PSBT the simulation carries and the signed one bwk's signer
/// returns: opaque bytes here, which only the account reads.
final _unsignedPsbt = Uint8List.fromList([0x70, 0x73, 0x62, 0x74, 0xff, 0x01]);
final _signedPsbt = Uint8List.fromList([0x70, 0x73, 0x62, 0x74, 0xff, 0x02]);

/// [reversed] lists the simulated outputs last vout first; [paidSpAddress] is
/// the silent payment address the simulation resolved for the confirmed
/// recipient; [statedChangeSat] is the change the simulation states, by
/// default the amount of its change output.
TxSimulation _simulation({
  int feeSat = _feeSat,
  int changeSat = _changeSat,
  int? statedChangeSat,
  bool reversed = false,
  String paidSpAddress = _spAddress,
}) {
  final txOutputs = [
    SimulatedOutput(
      vout: 0,
      amountSat: BigInt.from(_standardSat),
      destination: const OutputDestination.address(address: _standardAddress),
      isChange: false,
    ),
    SimulatedOutput(
      vout: 1,
      amountSat: BigInt.from(_spSat),
      destination: OutputDestination.silentPayment(
        address: paidSpAddress,
        scanKey: '02${'1' * 64}',
        spendKey: '03${'2' * 64}',
      ),
      isChange: false,
    ),
    if (changeSat > 0)
      SimulatedOutput(
        vout: 2,
        amountSat: BigInt.from(changeSat),
        destination: OutputDestination.silentPayment(
          address: 'sp1-own-change',
          scanKey: '02${'3' * 64}',
          spendKey: '03${'4' * 64}',
          label: 0,
        ),
        isChange: true,
      ),
  ];
  return TxSimulation(
    inputs: [
      UnifiedCoinView(
        source: CoinSource.sp,
        outpoint: '${'a' * 64}:0',
        amountSat: BigInt.from(60000),
        status: UnifiedCoinStatus.unspent,
      ),
      UnifiedCoinView(
        source: CoinSource.taproot,
        outpoint: '${'b' * 64}:1',
        amountSat: BigInt.from(50000),
        status: UnifiedCoinStatus.unspent,
      ),
    ],
    outputs: [
      RecipientView.standard(
        address: _standardAddress,
        amountSat: BigInt.from(_standardSat),
        isMax: false,
      ),
      RecipientView.sp(
        address: _spAddress,
        amountSat: BigInt.from(_spSat),
        isMax: false,
      ),
    ],
    txOutputs: reversed ? txOutputs.reversed.toList() : txOutputs,
    feeSat: BigInt.from(feeSat),
    changeSat: BigInt.from(statedChangeSat ?? changeSat),
    feeRateSatVb: BigInt.two,
    psbt: _unsignedPsbt,
  );
}

/// What bwk's receiving path reports for [_signedTx]: the change it found.
List<SpOwnedOutput> _recognisedChange({int sat = _changeSat, int vout = 2}) => [
  SpOwnedOutput(vout: vout, amountSat: BigInt.from(sat), isChange: true),
];

void _stubOwned(SpAccount account, List<SpOwnedOutput> owned) => when(
  () => account.ownedOutputs(txBytes: any(named: 'txBytes')),
).thenAnswer((_) async => owned);

Uint8List _standardScript() => bdk.Address(
  address: _standardAddress,
  network: bdk.Network.bitcoin,
).scriptPubkey().toBytes();

// A taproot output script: the silent payment recipient's and the change's are
// derived at signing time, so any key stands in for them.
Uint8List _p2tr(int fill) =>
    Uint8List.fromList([0x51, 0x20, ...List.filled(32, fill)]);

List<(int, Uint8List)> _simulatedOutputs() => [
  (_standardSat, _standardScript()),
  (_spSat, _p2tr(0x22)),
  (_changeSat, _p2tr(0x33)),
];

/// A legacy-serialized transaction: unsigned, which is all the check reads.
Uint8List _signedTx({
  List<(String, int)>? inputs,
  List<(int, Uint8List)>? outputs,
}) {
  final bytes = BytesBuilder();
  void u32(int v) => bytes.add(
    (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List(),
  );
  void u64(int v) => bytes.add(
    (ByteData(8)..setUint64(0, v, Endian.little)).buffer.asUint8List(),
  );
  final ins = inputs ?? _simulatedInputs;
  final outs = outputs ?? _simulatedOutputs();
  u32(2);
  bytes.addByte(ins.length);
  for (final (txid, vout) in ins) {
    // Txids are displayed big-endian and serialized little-endian.
    bytes.add(
      [
        for (var i = 0; i < txid.length; i += 2)
          int.parse(txid.substring(i, i + 2), radix: 16),
      ].reversed.toList(),
    );
    u32(vout);
    bytes.addByte(0);
    u32(0xfffffffd);
  }
  bytes.addByte(outs.length);
  for (final (value, script) in outs) {
    u64(value);
    bytes.addByte(script.length);
    bytes.add(script);
  }
  u32(0);
  return bytes.toBytes();
}

String _hex(Uint8List bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
