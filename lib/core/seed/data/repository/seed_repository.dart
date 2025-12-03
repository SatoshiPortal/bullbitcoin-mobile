import 'package:bb_mobile/core/seed/data/datasources/seed_datasource.dart';
import 'package:bb_mobile/core/seed/data/models/seed_model.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:flutter/foundation.dart';

class SeedRepository {
  final SeedDatasource _source;

  const SeedRepository({required SeedDatasource source}) : _source = source;

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
      log.info(
        'Failed to create seed from mnemonic: $e',
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
      log.info(
        'Failed to create seed from bytes: $e',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }

  Future<Seed> get(String fingerprint) async {
    try {
      final model = await _source.get(fingerprint);
      return model.toEntity();
    } catch (e, stackTrace) {
      log.info(
        'Failed to get seed with fingerprint $fingerprint: $e',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }

  Future<bool> exists(String fingerprint) async {
    try {
      return await _source.exists(fingerprint);
    } catch (e, stackTrace) {
      log.info(
        'Failed to check if seed exists with fingerprint $fingerprint: $e',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> delete(String fingerprint) => _source.delete(fingerprint);

  Future<List<MnemonicSeed>> getAllMnemonicSeeds() async {
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
            final seed = model.toEntity() as MnemonicSeed;
            mnemonicSeeds.add(seed);
          }
        }

        return mnemonicSeeds;
      }

      // Convert models to entities in isolate to avoid blocking UI
      // (toEntity() triggers expensive fingerprint computation)
      return await compute(convertToMnemonicSeedsInIsolate, models);
    } catch (e, stackTrace) {
      log.info(
        'Failed to get all mnemonic seeds: $e',
        error: e,
        trace: stackTrace,
      );
      rethrow;
    }
  }
}
