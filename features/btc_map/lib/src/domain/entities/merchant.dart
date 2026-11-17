import 'package:meta/meta.dart';

import 'package:btc_map/src/domain/entities/geo_point.dart';

/// The kinds of place the map lets a user filter by, the same set btcmap.org
/// offers. A place outside all of them is still listed under "all".
enum MerchantCategory {
  restaurants,
  shopping,
  groceries,
  coffee,
  atms,
  hotels,
  beauty,
}

/// A way a merchant takes bitcoin, from its OpenStreetMap `payment:*` tags.
enum MerchantPaymentMethod { onchain, lightning, lightningContactless }

/// How much a merchant's listing can be trusted today.
enum MerchantVerification {
  /// A contributor confirmed the place within the last year.
  recent,

  /// Confirmed once, but more than a year ago: it may no longer take bitcoin.
  outdated,

  /// Nobody has ever confirmed the place.
  never,
}

/// A place that accepts bitcoin, as listed by BTC Map from OpenStreetMap tags.
@immutable
final class Merchant {
  /// The window BTC Map itself uses to call a place verified.
  static const _verificationValidityYears = 1;

  final int id;
  final GeoPoint location;

  /// Null when OpenStreetMap has no name for the place.
  final String? name;

  /// Null for a kind of place none of the filters covers.
  final MerchantCategory? category;
  final String? address;

  /// Raw OpenStreetMap `opening_hours` value, e.g. `Mo-Fr 08:00-12:00`.
  final String? openingHours;
  final String? phone;
  final String? email;
  final String? description;
  final Uri? website;

  /// Social profiles (X, Facebook, Instagram, Telegram), in that order.
  final List<Uri> socialLinks;

  /// An extra app the merchant's payment QR code needs, when it is not a
  /// standard bitcoin or lightning one.
  final Uri? requiredAppUrl;

  /// BTC Map's own page for the place: comments, photos, and how to verify it.
  final Uri? btcMapUrl;
  final Set<MerchantPaymentMethod> paymentMethods;

  /// The calendar day of the last confirmation, as UTC midnight.
  final DateTime? verifiedAt;

  Merchant({
    required this.id,
    required this.location,
    String? name,
    this.category,
    String? address,
    String? openingHours,
    String? phone,
    String? email,
    String? description,
    this.website,
    this.socialLinks = const [],
    this.requiredAppUrl,
    this.btcMapUrl,
    this.paymentMethods = const {},
    this.verifiedAt,
  }) : name = _blankToNull(name),
       address = _blankToNull(address),
       openingHours = _blankToNull(openingHours),
       phone = _blankToNull(phone),
       email = _validEmail(email),
       description = _blankToNull(description) {
    if (id <= 0) throw ArgumentError.value(id, 'id', 'must be positive');
  }

  /// Opening hours split into their `;`-separated rules, one per line.
  List<String> get openingHoursRules => [
    for (final rule in openingHours?.split(';') ?? const <String>[])
      if (rule.trim().isNotEmpty) rule.trim(),
  ];

  /// Whether the listing was confirmed within the last year, as of [now].
  MerchantVerification verificationAt(DateTime now) {
    final verified = verifiedAt;
    if (verified == null) return MerchantVerification.never;
    final cutoff = DateTime.utc(
      now.year - _verificationValidityYears,
      now.month,
      now.day,
    );
    return verified.isAfter(cutoff)
        ? MerchantVerification.recent
        : MerchantVerification.outdated;
  }

  /// Whether the place shows under [category]; null means every category.
  bool isIn(MerchantCategory? category) =>
      category == null || this.category == category;

  /// The name lowercased once, for search: comparing tens of thousands of
  /// places on each keystroke must not lowercase them again every time.
  late final String searchName = name?.toLowerCase() ?? '';
  late final String? _searchAddress = address?.toLowerCase();

  /// Whether [query] matches this merchant's name or address, ignoring case.
  /// An empty query matches nothing: search shows no list until the user types.
  bool matches(String query) => matchesLowercase(query.trim().toLowerCase());

  /// [matches] for a query already trimmed and lowercased.
  bool matchesLowercase(String needle) =>
      needle.isNotEmpty &&
      (searchName.contains(needle) ||
          (_searchAddress?.contains(needle) ?? false));

  /// Whether the name itself starts with [query], the strongest search match.
  bool nameStartsWith(String query) {
    final needle = query.trim().toLowerCase();
    return needle.isNotEmpty && searchName.startsWith(needle);
  }

  static String? _blankToNull(String? value) {
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// One address with an `@` and no spaces, or null: the tag is free text and
  /// must not turn into a malformed `mailto:` link.
  static String? _validEmail(String? value) {
    final email = _blankToNull(value);
    if (email == null) return null;
    final at = email.indexOf('@');
    final valid =
        at > 0 &&
        at == email.lastIndexOf('@') &&
        at < email.length - 1 &&
        !email.contains(RegExp(r'\s'));
    return valid ? email : null;
  }
}

extension MerchantsInCategory on List<Merchant> {
  /// The merchants under [category]; with null, this same list, so a caller
  /// can tell by identity that nothing was filtered out.
  List<Merchant> inCategory(MerchantCategory? category) => category == null
      ? this
      : where((merchant) => merchant.isIn(category)).toList(growable: false);
}
