import 'package:bb_mobile/features/scan_anything/domain/entities/scanned_content.dart';

final class ScanHistoryEntry {
  final ScannedContent content;
  final DateTime time;

  const ScanHistoryEntry({required this.content, required this.time});
}

class ScanHistory {
  static const maxEntries = 20;

  final List<ScanHistoryEntry> _entries = [];

  List<ScanHistoryEntry> get entries => List.unmodifiable(_entries);

  void add(ScannedContent content, {required DateTime time}) {
    final text = content.copyText;
    if (text == null) return;
    _entries.removeWhere(
      (entry) =>
          entry.content.runtimeType == content.runtimeType &&
          entry.content.copyText == text,
    );
    _entries.insert(0, ScanHistoryEntry(content: content, time: time));
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
  }

  void clear() => _entries.clear();
}
