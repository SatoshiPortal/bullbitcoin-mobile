import 'package:bull_exchange/src/settings/domain/entities/secure_file_upload.dart';
import 'package:bull_exchange/src/settings/domain/exchange_settings_failure.dart';
import 'package:bull_exchange/src/settings/domain/entities/exchange_document_to_upload.dart';
import 'package:bull_exchange/src/settings/domain/secure_file_upload_machine.dart';
import 'package:exchange/exchange.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:primitives/primitives.dart';

const _account = SecureFileUpload(
  userId: 'u',
  status: KycDocumentStatus.notUploaded,
);
const _inReview = SecureFileUpload(
  userId: 'u',
  status: KycDocumentStatus.underReview,
);
const _doc = ExchangeDocumentToUpload(bytes: [1], fileName: 'doc-u-ID');
const _statusFailure = ExchangeSettingsUploadStatusUnavailableFailure();
const _uploadFailure = ExchangeSettingsDocumentUploadFailure();

final _states = <SecureUploadState>[
  const UploadStatusLoading(1), // 0
  const UploadStatusFailed(1, _statusFailure), // 1
  const UploadReady(_account, 1), // 2
  const UploadReady(_account, 1, problem: _uploadFailure), // 3
  const UploadBlocked(SecureUploadStatus.inReview), // 4
  const UploadPicking(_account, 1), // 5
  const UploadSending(_account, 2), // 6
  const UploadDone(3), // 7
];

final _table = <String, (SecureUploadEvent, Map<int, SecureUploadState>)>{
  'status 1 loaded': (
    const UploadStatusLoaded(1, Ok(_account)),
    {0: const UploadReady(_account, 1)},
  ),
  'status 1 in review': (
    const UploadStatusLoaded(1, Ok(_inReview)),
    {0: const UploadBlocked(SecureUploadStatus.inReview)},
  ),
  'status 1 failed (SET-1)': (
    const UploadStatusLoaded(1, Err(_statusFailure)),
    {0: const UploadStatusFailed(1, _statusFailure)},
  ),
  'status 3 loaded (after an upload)': (
    const UploadStatusLoaded(3, Ok(_account)),
    {7: const UploadReady(_account, 3)},
  ),
  'status, stale attempt': (const UploadStatusLoaded(9, Ok(_account)), {}),
  'retry': (const UploadRetryPressed(), {1: const UploadStatusLoading(2)}),
  'upload pressed': (
    const UploadPressed(),
    {2: const UploadPicking(_account, 1), 3: const UploadPicking(_account, 1)},
  ),
  'picker dismissed': (
    const UploadPicked(Ok(null)),
    {5: const UploadReady(_account, 1)},
  ),
  'document picked (SET-5: picking is not uploading)': (
    const UploadPicked(Ok(_doc)),
    {5: const UploadSending(_account, 2)},
  ),
  'pick failed': (
    const UploadPicked(Err(ExchangeSettingsDocumentTooLargeFailure())),
    {
      5: const UploadReady(
        _account,
        1,
        problem: ExchangeSettingsDocumentTooLargeFailure(),
      ),
    },
  ),
  'upload answered (SET-4: confirmed every time)': (
    const UploadAnswered(2, Ok(null)),
    {6: const UploadDone(3)},
  ),
  'upload failed': (
    const UploadAnswered(2, Err(_uploadFailure)),
    {6: const UploadReady(_account, 2, problem: _uploadFailure)},
  ),
  'upload answer, stale attempt': (const UploadAnswered(1, Ok(null)), {}),
  'problem dismissed': (
    const UploadProblemDismissed(),
    {3: const UploadReady(_account, 1)},
  ),
};

void main() {
  group('every (state, event) pair', () {
    for (final MapEntry(key: name, value: (event, changes)) in _table.entries) {
      for (final (index, state) in _states.indexed) {
        test('$name from state $index', () {
          final next = transitionSecureUpload(state, event);
          if (changes[index] case final expected?) {
            expect(next.state, expected);
          } else {
            expect(identical(next.state, state), isTrue);
            expect(next.effects, isEmpty);
          }
        });
      }
    }
  });

  test('effects', () {
    expect(secureUploadStart().effects, const [FetchUploadStatus(1)]);
    expect(
      transitionSecureUpload(_states[1], const UploadRetryPressed()).effects,
      const [FetchUploadStatus(2)],
    );
    expect(
      transitionSecureUpload(_states[2], const UploadPressed()).effects,
      const [PickUploadDocument('u')],
    );
    expect(
      transitionSecureUpload(_states[5], const UploadPicked(Ok(_doc))).effects,
      const [SendUploadDocument(2, _doc)],
    );
    expect(
      transitionSecureUpload(
        _states[6],
        const UploadAnswered(2, Ok(null)),
      ).effects,
      const [FetchUploadStatus(3)],
    );
  });

  group('document status', () {
    final table = {
      KycDocumentStatus.notUploaded: SecureUploadStatus.upload,
      KycDocumentStatus.underReview: SecureUploadStatus.inReview,
      KycDocumentStatus.accepted: SecureUploadStatus.accepted,
      KycDocumentStatus.rejected: SecureUploadStatus.rejected,
      KycDocumentStatus.unknown: SecureUploadStatus.unknown,
    };
    test('names every KYC document status', () {
      expect(table.keys, containsAll(KycDocumentStatus.values));
    });
    for (final MapEntry(key: status, value: ui) in table.entries) {
      test('$status shows $ui', () {
        expect(secureUploadStatusOf(status), ui);
        final next = transitionSecureUpload(
          const UploadStatusLoading(1),
          UploadStatusLoaded(
            1,
            Ok(SecureFileUpload(userId: 'u', status: status)),
          ),
        ).state;
        expect(
          next is UploadReady,
          ui == SecureUploadStatus.upload || ui == SecureUploadStatus.rejected,
        );
      });
    }
  });

  test('every state is reachable from the start', () {
    final seen = <Type>{};
    final queue = <SecureUploadState>[secureUploadStart().state];
    final visited = <SecureUploadState>{};
    while (queue.isNotEmpty && visited.length < 500) {
      final state = queue.removeAt(0);
      if (!visited.add(state)) continue;
      seen.add(state.runtimeType);
      final attempt = switch (state) {
        UploadStatusLoading(:final attempt) ||
        UploadStatusFailed(:final attempt) ||
        UploadSending(:final attempt) ||
        UploadDone(:final attempt) => attempt,
        UploadReady(:final attempts) ||
        UploadPicking(:final attempts) => attempts,
        UploadBlocked() => 0,
      };
      for (final event in <SecureUploadEvent>[
        UploadStatusLoaded(attempt, const Ok(_account)),
        UploadStatusLoaded(attempt, const Ok(_inReview)),
        UploadStatusLoaded(attempt, const Err(_statusFailure)),
        const UploadRetryPressed(),
        const UploadPressed(),
        const UploadPicked(Ok(_doc)),
        const UploadPicked(Err(_uploadFailure)),
        UploadAnswered(attempt, const Ok(null)),
        const UploadProblemDismissed(),
      ]) {
        final next = transitionSecureUpload(state, event).state;
        if (!identical(next, state)) queue.add(next);
      }
    }
    expect(seen, {
      UploadStatusLoading,
      UploadStatusFailed,
      UploadReady,
      UploadBlocked,
      UploadPicking,
      UploadSending,
      UploadDone,
    });
  });
}
