import 'dart:convert';
import 'dart:io';

import 'package:bb_mobile/core/logging/data/log_model.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/core/utils/logger.dart' as logging;
import 'package:path_provider/path_provider.dart';

abstract class LogDatasource {
  Future<void> addLog(LogModel log);
  Future<void> truncateLogs({required DateTime from, required DateTime until});
  Future<void> clearLogs();
}

class LocalFileLogDatasource implements LogDatasource {
  LocalFileLogDatasource();

  @override
  Future<void> addLog(LogModel log) async {
    try {
      final file = await _getFile();
      final encoded = jsonEncode(log.toJson());
      await file.writeAsString('$encoded\n', mode: FileMode.append);
    } catch (e) {
      // Logging failures are not fatal
      logging.log.warning('Logging to file failed: $e');
    }
  }

  @override
  Future<void> truncateLogs({
    required DateTime from,
    required DateTime until,
  }) async {
    try {
      final file = await _getFile();
      if (!await file.exists()) return;

      final lines = await file.readAsLines();

      final filteredLines = lines.where((line) {
        try {
          final Map<String, dynamic> json =
              jsonDecode(line) as Map<String, dynamic>;
          final log = LogModel.fromJson(json);
          return log.timestamp.isBefore(from) || log.timestamp.isAfter(until);
        } catch (_) {
          return true; // keep malformed lines
        }
      });

      await file.writeAsString('${filteredLines.join('\n')}\n');
    } catch (e) {
      logging.log.warning('Truncating log file failed: $e');
    }
  }

  @override
  Future<void> clearLogs() async {
    try {
      final file = await _getFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      logging.log.severe('Removing log file failed: $e');
    }
  }

  Future<File> _getFile() async {
    const fileName = SettingsConstants.logFileName;
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$fileName');
  }
}
