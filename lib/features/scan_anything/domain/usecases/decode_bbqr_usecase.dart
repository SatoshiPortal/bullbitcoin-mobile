import 'dart:convert';

import 'package:bb_mobile/features/scan_anything/domain/scan_anything_failure.dart';
import 'package:bull_logger/bull_logger.dart';
import 'package:convert/convert.dart';
import 'package:meta/meta.dart';
import 'package:primitives/primitives.dart' show Err, Ok, Result;

typedef BbqrJoiner = Future<List<int>> Function(List<String> parts);

class DecodeBbqrUsecase {
  final BbqrJoiner _join;

  const DecodeBbqrUsecase({required this._join});

  @useResult
  Future<Result<String, ScanAnythingFailure>> execute({
    required List<String> parts,
    required String type,
  }) async {
    try {
      final data = await _join(parts);
      return switch (type) {
        'P' => Ok(base64.encode(data)),
        'T' => Ok(hex.encode(data)),
        'U' || 'J' => Ok(utf8.decode(data)),
        _ => const Err(ScanAnythingUnrecognizedFailure()),
      };
    } catch (e) {
      log.warning('Scan anything: BBQr decode failed (${e.runtimeType})');
      return const Err(ScanAnythingUnrecognizedFailure());
    }
  }
}
