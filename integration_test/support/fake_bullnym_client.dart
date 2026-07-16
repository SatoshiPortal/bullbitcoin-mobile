import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_actions.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_backup_blob.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_client_port.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_error.dart';
import 'package:bb_mobile/features/bullnym/domain/bullnym_registration.dart';

enum FakeBullnymMode {
  live,
  inactiveWithPreviousNym,
  registrationMissing,
  serverUnreachable,
}

/// In-memory Bullnym boundary for Get Paid lifecycle tests.
///
/// The object intentionally survives local app-state wipes so tests can model
/// automatic remote recovery. Registration and backup faults share one mode;
/// later product fakes can add independent product-specific modes.
class FakeBullnymClient implements BullnymClientPort {
  FakeBullnymMode mode = FakeBullnymMode.live;
  String nym = 'alice';

  final List<String> registeredNyms = [];
  final Map<String, BullnymBackupHead> _backups = {};

  String get _lightningAddress => '$nym@example.invalid';

  String _backupKey(BullnymBackupStream stream, String npubHex) =>
      '${stream.wireName}|$npubHex';

  @override
  Future<BullnymRegisterResult> register(BullnymRegisterRequest request) async {
    if (mode == FakeBullnymMode.serverUnreachable) throw _unavailable();
    registeredNyms.add(request.nym);
    nym = request.nym;
    mode = FakeBullnymMode.live;
    return BullnymRegisterResult(nym: nym, lightningAddress: _lightningAddress);
  }

  @override
  Future<void> deleteRegistration(
    BullnymDeleteRegistrationRequest request,
  ) async {}

  @override
  Future<BullnymLookupResult> lookupRegistration({
    required String npubHex,
  }) async {
    return switch (mode) {
      FakeBullnymMode.live => BullnymLookupResult(
        nym: nym,
        active: true,
        lightningAddress: _lightningAddress,
      ),
      FakeBullnymMode.inactiveWithPreviousNym => BullnymLookupResult(
        nym: nym,
        active: false,
      ),
      FakeBullnymMode.registrationMissing => throw _missing(),
      FakeBullnymMode.serverUnreachable => throw _unavailable(),
    };
  }

  @override
  Future<BullnymBackupHead> fetchBackup(
    BullnymBackupFetchRequest request,
  ) async {
    if (mode == FakeBullnymMode.serverUnreachable) throw _unavailable();
    return _backups[_backupKey(request.stream, request.npubHex)] ??
        BullnymBackupHead.absent(generation: 0, etag: null);
  }

  @override
  Future<BullnymBackupStoreReceipt> storeBackup(
    BullnymBackupStoreRequest request,
  ) async {
    if (mode == FakeBullnymMode.serverUnreachable) throw _unavailable();
    final key = _backupKey(request.stream, request.npubHex);
    final current = _backups[key];
    if (request.expectedEtag != current?.etag) throw _conflict();
    final etag = computeWalletBackupEtag(
      stream: request.stream,
      npubHex: request.npubHex,
      generation: request.generation,
      ciphertextSha256: request.ciphertextSha256,
    );
    _backups[key] = BullnymBackupHead.present(
      generation: request.generation,
      etag: etag,
      ciphertext: request.ciphertext,
      ciphertextSha256: request.ciphertextSha256,
      updatedAtSecs: request.timestamp,
    );
    return BullnymBackupStoreReceipt(
      generation: request.generation,
      etag: etag,
    );
  }

  @override
  Future<BullnymBackupDeleteReceipt> deleteBackup(
    BullnymBackupDeleteRequest request,
  ) async {
    if (mode == FakeBullnymMode.serverUnreachable) throw _unavailable();
    final key = _backupKey(request.stream, request.npubHex);
    final current = _backups[key];
    if (request.expectedEtag != current?.etag) throw _conflict();
    final etag = computeWalletBackupEtag(
      stream: request.stream,
      npubHex: request.npubHex,
      generation: request.generation,
      ciphertextSha256: '',
    );
    _backups[key] = BullnymBackupHead.absent(
      generation: request.generation,
      etag: etag,
    );
    return BullnymBackupDeleteReceipt(
      generation: request.generation,
      etag: etag,
    );
  }

  BullnymException _missing() => const BullnymException.serverRejectedRequest(
    code: 'NymNotFound',
    diagnosticReason: 'no registration for public key',
    statusCode: 404,
    retryable: false,
  );

  BullnymException _unavailable() =>
      const BullnymException.serverRejectedRequest(
        code: 'ServiceUnavailable',
        diagnosticReason: 'fake service unavailable',
        statusCode: 503,
        retryable: true,
      );

  BullnymException _conflict() => const BullnymException.serverRejectedRequest(
    code: 'BackupConflict',
    diagnosticReason: 'backup etag mismatch',
    statusCode: 409,
    retryable: false,
  );
}
