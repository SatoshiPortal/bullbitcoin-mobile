class BbqrOptions {
  static const header = 'B\$';

  final String encoding;
  final String type;
  final int total;
  final int share;

  BbqrOptions({
    required this.encoding,
    required this.type,
    required this.total,
    required this.share,
  });
}

class BbqrService {
  static bool isValid(String code) {
    try {
      decodeOptions(code);
      return true;
    } catch (e) {
      return false;
    }
  }

  static BbqrOptions decodeOptions(String code) {
    if (code.length < 6) throw "Encoded string is too short";
    if (code.substring(0, 2) != "B\$") throw "Invalid header: expected 'B\$'";

    final totalQRCodes = int.parse(code.substring(4, 6), radix: 36);
    final sequenceNumber = int.parse(code.substring(6, 8), radix: 36);

    return BbqrOptions(
      // encoding: BbqrEncoding.fromString(code[2]),
      encoding: code[2],
      type: code[3],
      total: totalQRCodes,
      share: sequenceNumber,
    );
  }
}
