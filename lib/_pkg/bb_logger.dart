import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:logger/logger.dart';

class BBLogger {
  late File _logFile;
  late Logger _logger;

  init() async {
    const bool isProduction = true; // bool.fromEnvironment('dart.vm.product');
    if (isProduction) {
      await _initLogFile();
    }
    _logger = Logger(
      printer: HybridPrinter(
          PrettyPrinter(printEmojis: false, colors: !isProduction),
          info: SimplePrinter(colors: !isProduction)),
      output: isProduction ? FileOutput(_logFile) : ConsoleOutput(),
    );

    // Write initial log
    _logger.i('App session started');
  }

  Future<void> _initLogFile() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    String fileName = 'log_${DateTime.now().millisecondsSinceEpoch}.txt';
    _logFile = File('${appDocDir.path}/$fileName');
    print('${appDocDir.path}/$fileName');

    if (!await _logFile.exists()) {
      await _logFile.create();
    }
  }

  void log(String message) {
    _logger.i(message);
    // print(message);
  }

  void error(String message, StackTrace stackTrace) {
    _logger.e(message, stackTrace: stackTrace);
    print(message);
    print(stackTrace);
  }

  Future<List<File>> listLogFiles() async {
    final directory = await getApplicationDocumentsDirectory();
    final List<FileSystemEntity> entities = directory.listSync();
    final List<File> logFiles = entities
        .whereType<File>()
        .where((file) => file.path.split('/').last.startsWith('log_'))
        .toList();
    return logFiles.reversed.toList();
  }

  Future<String> readLogFile(File file) async {
    return await file.readAsString();
  }
}

class FileOutput extends LogOutput {
  final File logFile;

  FileOutput(this.logFile);

  @override
  void output(OutputEvent event) async {
    final logMessages = event.lines
        .map((line) => '${DateTime.now().toIso8601String()} - $line')
        .join('\n');
    await logFile.writeAsString('$logMessages\n', mode: FileMode.append);
  }
}