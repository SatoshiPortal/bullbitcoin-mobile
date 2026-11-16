import 'package:ark/ark.dart';
import 'package:ark/src/data/exit_archive/ark_exit_archive.dart';
import 'package:primitives/primitives.dart';
import 'package:test/test.dart';

import '../support/fake_exit_archive.dart';

void main() {
  final account = ArkAccountId(
    parent: Fingerprint('12345678'),
    network: BitcoinNetwork.regtest,
    serverIdentity: 'server',
  );
  final identity = ArkExitArchiveIdentity(
    account,
    '0.27.0+bark-0.8.1',
    'bip85-11811/bark-350h-0h',
    archiveId: 'fixture-archive',
  );
  test('private fake accepts exact contract and keeps unsupported coverage explicit', () async {
    final archive = FakeExitArchive(identity);
    final inputs = ['owned'];
    final result = await archive.begin(
      ArkExitCaptureStage.payment,
      operationId: 'operation',
      knownInputs: inputs,
    );
    final intent = (result as Ok<ArkExitCaptureIntent, ArkWalletFailure>).value;
    final restored = ArkExitCaptureIntent(
      identity,
      intent.sequence,
      intent.stage,
      operationId: intent.operationId,
      sourceRevision: intent.sourceRevision,
      knownInputs: intent.knownInputs,
    );
    expect(restored.matches(intent), isTrue);
    expect(await archive.failed(restored), isA<Ok>());
    final foreign = ArkExitCaptureIntent(
      ArkExitArchiveIdentity(
        account,
        identity.nativeVersion,
        identity.derivationProfile,
        archiveId: 'other',
      ),
      intent.sequence,
      intent.stage,
      operationId: intent.operationId,
      knownInputs: intent.knownInputs,
    );
    expect(await archive.failed(foreign), isA<Err>());
    inputs.clear();
    expect(intent.knownInputs, ['owned']);
    final proof = ArkExitProofVersion(
      vtxoId: 'owned',
      proofHash: 'a' * 64,
      fullHex: '00',
      encodingVersion: 1,
    );
    expect(
      await archive.commit(intent, ArkExitCaptureBatch(proofs: [proof])),
      isA<Ok>(),
    );
    final view =
        ((await archive.read()) as Ok<ArkExitArchiveView, ArkWalletFailure>)
            .value;
    expect(view.proofs, isEmpty);
    expect(archive.commits.single.proofs.single, proof);
    expect(view.state, ArkExitCaptureState.dirty);
    expect(
      view.issues,
      contains(ArkExitCaptureIssue.nativeCoverageUnavailable),
    );
    expect(view.acknowledgedThrough, 0);
    expect(() => view.proofs.clear(), throwsUnsupportedError);
    await archive.close();
  });
  test(
    'recording fake preserves calls and dirty intent after commit failure',
    () async {
      final archive = FakeExitArchive(identity);
      final first = ((await archive.begin(
        ArkExitCaptureStage.open,
      )) as Ok<ArkExitCaptureIntent, ArkWalletFailure>).value;
      final proof = ArkExitProofVersion(
        vtxoId: 'owned',
        proofHash: 'a' * 64,
        fullHex: '00',
        encodingVersion: 1,
      );
      await archive.commit(first, ArkExitCaptureBatch(proofs: [proof]));
      final next = ((await archive.begin(
        ArkExitCaptureStage.reconcile,
      )) as Ok<ArkExitCaptureIntent, ArkWalletFailure>).value;
      archive.failCommit = true;
      expect(
        await archive.commit(
          next,
          ArkExitCaptureBatch(
            proofs: [
              ArkExitProofVersion(
                vtxoId: 'owned',
                proofHash: 'b' * 64,
                fullHex: '01',
                encodingVersion: 1,
              ),
            ],
          ),
        ),
        isA<Err>(),
      );
      final view =
          ((await archive.read()) as Ok<ArkExitArchiveView, ArkWalletFailure>)
              .value;
      expect(view.proofs, isEmpty);
      expect(archive.commits.single.proofs.single, proof);
      expect(view.pending.last.sequence, next.sequence);
      expect(view.state, ArkExitCaptureState.dirty);
      await archive.close();
    },
  );
}
