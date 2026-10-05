class LogEntryModel {
  final String rawLine;
  final String? timestampText;
  final String rawLevel;
  final List<String> columns;

  const LogEntryModel({
    required this.rawLine,
    required this.timestampText,
    required this.rawLevel,
    required this.columns,
  });

  factory LogEntryModel.fromRawLine(String rawLine) {
    final columns = rawLine.split('\t');
    return LogEntryModel(
      rawLine: rawLine,
      timestampText: columns.isEmpty ? null : columns.first,
      rawLevel: columns.length > 1 ? columns[1] : '',
      columns: columns,
    );
  }
}
