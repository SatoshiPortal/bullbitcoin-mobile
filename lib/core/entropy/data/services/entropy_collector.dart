import 'dart:async';

import 'package:bb_mobile/core/entropy/data/services/entropy_pool.dart';
import 'package:bb_mobile/core/entropy/domain/entropy_source.dart';
import 'package:bb_mobile/core/errors/bull_exception.dart';
import 'package:bb_mobile/core/utils/logger.dart';

/// Runs a set of [EntropySource]s concurrently and folds their output into
/// the [EntropyPool].
///
/// Policy: a failed or timed-out optional source is skipped — it contributes
/// nothing but must never block wallet creation. A failed mandatory source
/// aborts, because the mandatory sources are the pool's security floor.
class EntropyCollector {
  EntropyCollector({
    required EntropyPool pool,
    required List<EntropySource> sources,
    this.perSourceTimeout = const Duration(seconds: 3),
  }) : _pool = pool,
       _sources = sources;

  final EntropyPool _pool;
  final List<EntropySource> _sources;
  final Duration perSourceTimeout;

  Future<void> collectAll() async {
    await Future.wait(_sources.map(_collectOne));
  }

  Future<void> _collectOne(EntropySource source) async {
    try {
      final data = await source.collect().timeout(perSourceTimeout);
      if (source.mandatory) {
        // The privileged path: validates identity and minimum length, and
        // is the only way to satisfy the pool's mandatory gate.
        _pool.mixMandatory(source.name, data);
      } else {
        _pool.mix(source.name, data);
      }
      for (var i = 0; i < data.length; i++) {
        data[i] = 0;
      }
    } catch (e) {
      if (source.mandatory) {
        throw MandatoryEntropySourceFailedException(source.name, e);
      }
      log.warning('Optional entropy source ${source.name} skipped: $e');
    }
  }
}

class MandatoryEntropySourceFailedException extends BullException {
  MandatoryEntropySourceFailedException(String source, Object cause)
    : super('Mandatory entropy source $source failed: $cause');
}
