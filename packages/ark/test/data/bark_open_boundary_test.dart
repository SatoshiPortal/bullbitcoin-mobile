import 'package:ark/ark.dart';
import 'package:ark/src/data/ark_native_session.dart';
import 'package:ark/src/data/bark_native_opener.dart';
import 'package:bark_bitcoin/bark_bitcoin.dart' as bark;
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

final class _Stages implements ArkStageRunner {
  @override
  Future<T> run<T>(String name, Future<T> Function() action) => action();
}

final class _Wallet implements bark.Wallet {
  final String identity;
  bool disposed = false;
  _Wallet(this.identity);
  @override
  String fingerprint() => identity;
  @override
  bark.RecoveryStatus recoveryStatus() => bark.NotRunRecoveryStatus();
  @override
  void dispose() => disposed = true;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected native call');
}

final class _Onchain implements bark.OnchainWallet {
  bool disposed = false;
  @override
  void dispose() => disposed = true;
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected onchain call');
}

final class Boundary implements BarkOpenBoundary {
  bark.DatadirInfo? metadata;
  bool files = false;
  int onchainOpens = 0;
  int walletOpens = 0;
  bool? create;
  final String identity;
  late final wallet = _Wallet(identity);
  final onchain = _Onchain();
  Boundary(this.identity);
  @override
  bark.DatadirInfo? inspect(String datadir) => metadata;
  @override
  bool hasData(String datadir) => files;
  @override
  Future<bark.OnchainWallet> openOnchain({
    required bark.Network network,
    required String mnemonic,
    required bark.Config config,
    required String datadir,
  }) async {
    onchainOpens++;
    return onchain;
  }

  @override
  Future<bark.Wallet> openWallet({
    required bark.Network network,
    required String mnemonicOrSeed,
    required bark.Config config,
    required bark.WalletOpenArgs args,
  }) async {
    walletOpens++;
    create = args.createIfNotExists;
    return wallet;
  }
}

void main() {
  // Explicit public BIP39 all-zero entropy vector; never printed or persisted.
  final words = Mnemonic(List<int>.filled(16, 0), Language.english).sentence;
  const identity = '53bdf6b1';
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'test',
  );
  final config = ArkAccountConfig(
    id: account,
    arkUrl: Uri.parse('http://localhost:1'),
    primaryEsploraUrl: Uri.parse('http://localhost:2'),
  );
  Future<ArkNativeSession> open(
    Boundary boundary, {
    String? stored,
    bool prior = false,
    void Function(ArkRecoveryStatus, String)? onOpened,
  }) => BarkNativeOpener(boundary: boundary).open(
    config: config,
    datadir: 'fixture',
    mnemonic: words,
    childFingerprint: Fingerprint(identity),
    chainSource: config.primaryEsploraUrl,
    create: true,
    expectedFingerprint: stored,
    nativePreviouslyAdmitted: prior,
    onNativeAdmission: () {},
    stages: _Stages(),
    onOnchainOpened: () {},
    onOpened: onOpened ?? (recovery, fingerprint) {},
  );
  bark.DatadirInfo metadata(String value) => bark.DatadirInfo(
    dbFile: 'fixture/db.sqlite',
    network: bark.Network.regtest,
    fingerprint: value,
  );
  test(
    'same-network foreign datadir is refused before either mutable opener',
    () async {
      final boundary = Boundary(identity)
        ..metadata = metadata('deadbeef')
        ..files = true;
      await expectLater(open(boundary), throwsA(isA<ArkBoundaryException>()));
      expect(boundary.onchainOpens, 0);
      expect(boundary.walletOpens, 0);
    },
  );
  test(
    'stored identity mismatch is refused before mutable onchain open',
    () async {
      final boundary = Boundary(identity)
        ..metadata = metadata(identity)
        ..files = true;
      await expectLater(
        open(boundary, stored: 'deadbeef', prior: true),
        throwsA(isA<ArkBoundaryException>()),
      );
      expect(boundary.onchainOpens, 0);
    },
  );
  test('missing properties after known identity cannot be recreated', () async {
    final boundary = Boundary(identity);
    await expectLater(
      open(boundary, stored: identity, prior: true),
      throwsA(isA<ArkBoundaryException>()),
    );
    expect(boundary.onchainOpens, 0);
  });
  test(
    'partial onchain admission cannot be treated as pristine creation',
    () async {
      final boundary = Boundary(identity)..files = true;
      await expectLater(
        open(boundary, prior: true),
        throwsA(isA<ArkBoundaryException>()),
      );
      expect(boundary.onchainOpens, 0);
    },
  );
  test('proven pre-native state permits first creation', () async {
    final boundary = Boundary(identity);
    final session = await open(boundary);
    expect(boundary.onchainOpens, 1);
    expect(boundary.create, isTrue);
    session.close();
  });
  test(
    'intact matching native state is adopted with creation disabled',
    () async {
      final boundary = Boundary(identity)
        ..metadata = metadata(identity)
        ..files = true;
      final session = await open(boundary, stored: identity, prior: true);
      expect(boundary.create, isFalse);
      expect(boundary.onchainOpens, 1);
      session.close();
    },
  );
  for (final existing in [false, true]) {
    test(
      'wallet mismatch disposes handles without publication existing=$existing',
      () async {
        final boundary = Boundary('deadbeef');
        if (existing) {
          boundary.metadata = metadata(identity);
          boundary.files = true;
        }
        var published = false;
        await expectLater(
          open(
            boundary,
            stored: existing ? identity : null,
            prior: existing,
            onOpened: (_, _) => published = true,
          ),
          throwsA(
            isA<ArkBoundaryException>().having(
              (e) => e.failure.reason,
              'reason',
              ArkFailureReason.identityMismatch,
            ),
          ),
        );
        expect(boundary.walletOpens, 1);
        expect(boundary.wallet.disposed, isTrue);
        expect(boundary.onchain.disposed, isTrue);
        expect(published, isFalse);
      },
    );
  }
}
