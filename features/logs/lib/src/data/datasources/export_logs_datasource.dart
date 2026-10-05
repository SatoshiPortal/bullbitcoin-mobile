import 'package:bull_logger/bull_logger.dart';

abstract interface class ExportLogsDatasource {
  Future<bool> export(List<String> lines);
}

class FilePickerLogsDatasource implements ExportLogsDatasource {
  const FilePickerLogsDatasource();

  @override
  Future<bool> export(List<String> lines) => exportLogsAsFile(lines);
}
