import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:btc_map/src/data/models/merchant_model.dart';

/// What the cache holds: the places, and the `updated_at` the next
/// incremental sync starts after.
typedef MerchantCacheContent = ({List<MerchantModel> places, DateTime? cursor});

/// The device copy of BTC Map's places: one JSON file in the directory the
/// app gives [BullMap.init]. Disposable data that can always be fetched again,
/// so it stays out of the app database and its migration chain.
class MerchantCacheDatasource {
  static const _fileName = 'btc_map_places.json';

  /// Bumped when [MerchantModel.apiFields] grows: an older file lacks the new
  /// fields, and an incremental sync would never fill them in for places that
  /// do not change, so it is rejected and fully re-downloaded.
  static const _formatVersion = 1;

  /// A temporary file older than this belongs to a write that never finished
  /// (the app was killed, or the disk was full).
  static const _staleTemporaryAge = Duration(minutes: 10);

  final Directory _directory;

  MerchantCacheDatasource(this._directory);

  /// The stored places, or nothing when nothing was stored yet.
  ///
  /// Throws [FileSystemException] or [FormatException] when the file exists
  /// but cannot be read.
  Future<MerchantCacheContent> read() async {
    final file = _file;
    if (!await file.exists()) return (places: <MerchantModel>[], cursor: null);
    final content = await file.readAsString();
    return Isolate.run(() => _decode(content));
  }

  /// Replaces the stored places. Written to a temporary file then renamed, so
  /// a crash mid-write never leaves a truncated cache behind.
  ///
  /// Throws [FileSystemException] when the file cannot be written.
  Future<void> write(List<MerchantModel> places, {DateTime? cursor}) async {
    await _deleteStaleTemporaryFiles();
    final file = _file;
    final content = await Isolate.run(
      () => jsonEncode({
        'version': _formatVersion,
        if (cursor != null) 'cursor': cursor.toUtc().toIso8601String(),
        'places': [for (final place in places) place.toJson()],
      }),
    );
    // Unique per write: two syncs (the map closed and reopened mid-download)
    // never share a temporary file, and the last complete write wins.
    final temporary = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.writeAsString(content, flush: true);
      await temporary.rename(file.path);
    } finally {
      // Gone after a successful rename; a partial file after a failed write.
      if (await temporary.exists()) await temporary.delete();
    }
  }

  File get _file => File('${_directory.path}/$_fileName');

  Future<void> _deleteStaleTemporaryFiles() async {
    final prefix = '${_file.path}.';
    final cutoff = DateTime.now().subtract(_staleTemporaryAge);
    try {
      await for (final entry in _directory.list()) {
        if (entry is! File ||
            !entry.path.startsWith(prefix) ||
            !entry.path.endsWith('.tmp')) {
          continue;
        }
        if ((await entry.lastModified()).isBefore(cutoff)) {
          await entry.delete();
        }
      }
    } on FileSystemException {
      // Best effort: a leftover only costs space until the next write.
    }
  }

  static MerchantCacheContent _decode(String content) {
    final json = jsonDecode(content);
    if (json is! Map<String, Object?> || json['version'] != _formatVersion) {
      throw const FormatException('Unknown merchant cache format');
    }
    final cursor = json['cursor'];
    return (
      places: parseMerchantModels(json['places']),
      cursor: cursor is String ? DateTime.tryParse(cursor)?.toUtc() : null,
    );
  }
}
