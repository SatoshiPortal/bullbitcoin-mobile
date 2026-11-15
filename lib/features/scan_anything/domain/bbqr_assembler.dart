import 'package:bb_mobile/core/bbqr/bbqr_options.dart';

final class BbqrProgress {
  final int received;
  final int total;
  final String type;
  final List<String>? completeParts;

  const BbqrProgress({
    required this.received,
    required this.total,
    required this.type,
    this.completeParts,
  });

  bool get isComplete => completeParts != null;
}

class BbqrAssembler {
  final Map<int, String> _parts = {};
  BbqrOptions? _options;

  static bool isPart(String payload) => BbqrOptions.isValid(payload);

  BbqrProgress add(String payload) {
    final scanned = BbqrOptions.decode(payload);
    final current = _options;
    if (current != null &&
        (current.total != scanned.total ||
            current.encoding != scanned.encoding ||
            current.type != scanned.type)) {
      _parts.clear();
    }
    _options = scanned;
    _parts[scanned.share] = payload;

    final isComplete = _parts.length == scanned.total;
    final progress = BbqrProgress(
      received: _parts.length,
      total: scanned.total,
      type: scanned.type,
      completeParts: isComplete
          ? [for (var i = 0; i < scanned.total; i++) _parts[i] ?? '']
          : null,
    );
    if (isComplete) reset();
    return progress;
  }

  void reset() {
    _parts.clear();
    _options = null;
  }
}
