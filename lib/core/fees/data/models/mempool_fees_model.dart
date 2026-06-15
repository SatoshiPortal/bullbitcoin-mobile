/// Wire model for the mempool fee endpoints (`/api/v1/fees/precise` and the
/// `/api/v1/fees/recommended` fallback). Pure serialization — no business
/// rules, no tier policy; that lives in the mapper/repository.
///
/// Every field is a `double`. The precise endpoint returns sub-1 sat/vByte
/// rates (e.g. `0.92`) but encodes whole values as JSON integers (e.g. `1`),
/// so a single payload can mix `int` and `double`. Reading each field as
/// `num` then `.toDouble()` accepts both; a bare `as int`/`as double` cast
/// throws on the other JSON number type ("type 'double' is not a subtype of
/// type 'int'").
class MempoolFeesModel {
  final double fastestFee;
  final double halfHourFee;
  final double hourFee;
  final double economyFee;
  final double minimumFee;

  const MempoolFeesModel({
    required this.fastestFee,
    required this.halfHourFee,
    required this.hourFee,
    required this.economyFee,
    required this.minimumFee,
  });

  factory MempoolFeesModel.fromJson(Map<String, dynamic> json) {
    double parse(String key) => (json[key] as num).toDouble();
    return MempoolFeesModel(
      fastestFee: parse('fastestFee'),
      halfHourFee: parse('halfHourFee'),
      hourFee: parse('hourFee'),
      economyFee: parse('economyFee'),
      minimumFee: parse('minimumFee'),
    );
  }
}
