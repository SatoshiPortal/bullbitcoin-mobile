import 'package:meta/meta.dart';

/// One BTC Map place: the JSON object the v4 REST API returns, kept as is so
/// the device cache stores exactly what the API sent. Each field is read with
/// a typed getter; one of an unexpected type reads as null rather than failing
/// a sync of tens of thousands of places. Validation happens in the mapper.
@immutable
final class MerchantModel {
  /// The `fields` of a full sync, the keys read below. Payment methods have
  /// no documented field; the API passes OpenStreetMap tags through as
  /// `osm:<tag>`. `deleted_at` is left out: asking for it makes the server
  /// include deleted places, which a first download has no use for.
  static const apiFields =
      'id,lat,lon,name,icon,address,opening_hours,phone,website,email,twitter,'
      'facebook,instagram,telegram,description,required_app_url,'
      'osm:payment:onchain,osm:payment:lightning,'
      'osm:payment:lightning_contactless,verified_at,updated_at';

  /// The `fields` of an incremental sync: deletions are how the cache learns
  /// to evict a place.
  static const syncFields = '$apiFields,deleted_at';

  final int id;
  final Map<String, Object?> _json;

  MerchantModel._(this.id, this._json);

  /// Throws a [FormatException] when [json] is not a place.
  factory MerchantModel.fromJson(Object? json) {
    if (json is! Map<String, Object?>) {
      throw const FormatException('Place is not a JSON object');
    }
    final id = json['id'];
    if (id is! int) throw const FormatException('Place has no integer id');
    return MerchantModel._(id, Map.unmodifiable(json));
  }

  double? get lat => _double('lat');
  double? get lon => _double('lon');
  String? get name => _string('name');

  /// BTC Map's Material icon name for the kind of place, e.g. `local_cafe`.
  String? get icon => _string('icon');
  String? get address => _string('address');
  String? get openingHours => _string('opening_hours');
  String? get phone => _string('phone');
  String? get website => _string('website');
  String? get email => _string('email');
  String? get twitter => _string('twitter');
  String? get facebook => _string('facebook');
  String? get instagram => _string('instagram');
  String? get telegram => _string('telegram');
  String? get description => _string('description');
  String? get requiredAppUrl => _string('required_app_url');

  /// Raw OpenStreetMap `payment:*` tag values, usually `yes` or `no`.
  String? get paymentOnchain => _string('osm:payment:onchain');
  String? get paymentLightning => _string('osm:payment:lightning');
  String? get paymentLightningContactless =>
      _string('osm:payment:lightning_contactless');

  DateTime? get verifiedAt {
    final parsed = _date('verified_at');
    if (parsed == null) return null;
    return DateTime.utc(parsed.year, parsed.month, parsed.day);
  }

  DateTime? get updatedAt => _date('updated_at')?.toUtc();
  DateTime? get deletedAt => _date('deleted_at')?.toUtc();
  bool get isDeleted => deletedAt != null;

  Map<String, Object?> toJson() => _json;

  double? _double(String key) => switch (_json[key]) {
    final num value => value.toDouble(),
    _ => null,
  };

  String? _string(String key) => switch (_json[key]) {
    final String value => value,
    _ => null,
  };

  DateTime? _date(String key) => switch (_json[key]) {
    final String value => DateTime.tryParse(value),
    _ => null,
  };
}

/// Parses a JSON array of places, skipping any entry that is not a place
/// rather than failing the whole list. Top-level so it can run in another
/// isolate.
List<MerchantModel> parseMerchantModels(Object? json) {
  if (json is! List) throw const FormatException('Places is not a JSON array');
  final places = <MerchantModel>[];
  for (final entry in json) {
    try {
      places.add(MerchantModel.fromJson(entry));
    } on FormatException {
      continue;
    }
  }
  return places;
}
