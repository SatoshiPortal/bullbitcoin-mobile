import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/seed_failure.dart';
import 'package:bb_mobile/core/seed/domain/seed_verification_port.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:meta/meta.dart';

class SeedRepository implements SeedVerificationPort {
  final SeedDatasource _source;

  const SeedRepository({required this._source});

  Future<MnemonicSeed> createFromMnemonic({
    required List<String> mnemonicWords,
    String? passphrase,
  }) async {
    try {
      final model = SeedModel.mnemonic(
        mnemonicWords: mnemonicWords,
        passphrase: passphrase,
      );
      await _source.store(fingerprint: model.masterFingerprint, seed: model);
      return model.toEntity() as MnemonicSeed;
    } catch (e, stackTrace) {
      log.severe(
        message: 'Failed to create seed from mnemonic',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }

  Future<Seed> createFromBytes({required Uint8List bytes}) async {
    try {
      final model = SeedModel.bytes(bytes: bytes);
      await _source.store(fingerprint: model.masterFingerprint, seed: model);
      return model.toEntity();
    } catch (e, stackTrace) {
      log.severe(
        message: 'Failed to create seed from bytes',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }

  Future<Seed> get(String fingerprint) async {
    try {
      final model = await _source.get(fingerprint);
      // Run toEntity() in isolate to avoid blocking UI with PBKDF2 + bip32
      final entity = await compute(_toEntityInIsolate, model);
      return entity;
    } catch (e, stackTrace) {
      log.severe(
        message: 'Failed to get seed with fingerprint',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }

  @pragma('vm:entry-point')
  static Seed _toEntityInIsolate(SeedModel model) => model.toEntity();

  String fingerprintFor({
    required List<String> mnemonicWords,
    String? passphrase,
  }) {
    return SeedModel.mnemonic(
      mnemonicWords: mnemonicWords,
      passphrase: passphrase,
    ).masterFingerprint;
  }

  Future<bool> exists(String fingerprint) async {
    try {
      return await _source.exists(fingerprint);
    } catch (e, stackTrace) {
      log.severe(
        message: 'Failed to check if seed exists with fingerprint',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }

  @override
  Future<bool> matchesXpubs({
    required String fingerprint,
    required List<({String derivationPath, String xpub})> keys,
  }) async {
    if (keys.isEmpty || !await exists(fingerprint)) return false;
    final seed = await get(fingerprint);
    return keys.every(
      (key) => Bip32Derivation.seedMatchesXpub(
        seedBytes: seed.bytes,
        derivationPath: key.derivationPath,
        xpub: key.xpub,
      ),
    );
  }

  @useResult
  Future<Result<void, SeedDeleteFailure>> delete(String fingerprint) async {
    try {
      await _source.delete(fingerprint);
      return const Ok(null);
    } catch (e, st) {
      log.severe(message: 'Failed to delete seed', error: e, trace: st);
      return Err(SeedDeleteFailure(e.toString()));
    }
  }

  @useResult
  Future<Result<List<MnemonicSeed>, SeedFetchFailure>>
  getAllMnemonicSeeds() async {
    try {
      final models = await _source.getAll();
      // Top-level function for isolate processing
      @pragma('vm:entry-point')
      List<MnemonicSeed> convertToMnemonicSeedsInIsolate(
        List<SeedModel> models,
      ) {
        final mnemonicSeeds = <MnemonicSeed>[];
        for (final model in models) {
          if (model is MnemonicSeedModel) {
            mnemonicSeeds.add(model.toEntity() as MnemonicSeed);
          }
        }
        return mnemonicSeeds;
      }

      // Convert models to entities in isolate to avoid blocking UI
      // (toEntity() triggers expensive fingerprint computation)
      return Ok(await compute(convertToMnemonicSeedsInIsolate, models));
    } catch (e, st) {
      log.severe(
        message: 'Failed to get all mnemonic seeds',
        error: e,
        trace: st,
      );
      return Err(SeedFetchFailure(e.toString()));
    }
  }
}
