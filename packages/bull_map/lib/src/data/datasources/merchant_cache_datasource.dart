import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:bull_map/src/data/models/merchant_model.dart';

/// The device copy of BTC Map's places: one JSON file in the directory the
/// app gives [BullMap.init]. Disposable data that can always be fetched again, so it stays out
/// of the app database and its migration chain.
class MerchantCacheDatasource {
  static const _fileName = 'btc_map_places.json';

  /// Bumped when [MerchantModel.apiFields] grows: an older file lacks the new
  /// fields, and an incremental sync would never fill them in for places that
  /// do not change, so it is rejected and fully re-downloaded.
  static const _formatVersion = 1;

  final Directory _directory;

  MerchantCacheDatasource(this._directory);

  /// The stored places, or an empty list when nothing was stored yet.
  ///
  /// Throws [FileSystemException] or [FormatException] when the file exists
  /// but cannot be read.
  Future<List<MerchantModel>> read() async {
    final file = _file;
    if (!await file.exists()) return const [];
    final content = await file.readAsString();
    return Isolate.run(() => _decode(content));
  }

  /// Replaces the stored places. Written to a temporary file then renamed, so
  /// a crash mid-write never leaves a truncated cache behind.
  ///
  /// Throws [FileSystemException] when the file cannot be written.
  Future<void> write(List<MerchantModel> places) async {
    final file = _file;
    final content = await Isolate.run(
      () => jsonEncode({
        'version': _formatVersion,
        'places': [for (final place in places) place.toJson()],
      }),
    );
    // Unique per write: two syncs (the map closed and reopened mid-download)
    // never share a temporary file, and the last complete write wins.
    final temporary = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    await temporary.writeAsString(content, flush: true);
    await temporary.rename(file.path);
  }

  File get _file => File('${_directory.path}/$_fileName');

  static List<MerchantModel> _decode(String content) {
    final json = jsonDecode(content);
    if (json is! Map<String, Object?> || json['version'] != _formatVersion) {
      throw const FormatException('Unknown merchant cache format');
    }
    return parseMerchantModels(json['places']);
  }
}
