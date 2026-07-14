const String bullnymPermanentNamesV1Policy = 'permanent_names_v1';

/// Server route slugs that cannot be claimed as a nym.
///
/// This mirrors Bullnym's `src/reserved_nyms.rs`. It is an immediate-feedback
/// filter only; the server remains authoritative for every claim.
const Set<String> bullnymReservedNyms = {
  'register',
  'health',
  'ready',
  'version',
  'webhook',
  'lnurlp',
  'api',
  'img',
  'donation-page',
  'well-known',
  'admin',
  'static',
  'assets',
  'favicon',
  'robots',
  'sitemap',
  'about',
  'terms',
  'privacy',
  'support',
  'help',
  'login',
  'logout',
  'signup',
  'settings',
  'account',
  'dashboard',
  'test',
  'i',
  'invoice',
  'invoices',
  'pos',
  'a',
};

/// Alias-only reservations in addition to [bullnymReservedNyms].
const Set<String> bullnymReservedAliases = {
  ...bullnymReservedNyms,
  '0',
  '1',
  'bullbitcoin',
  'bull-bitcoin',
  'bullpay',
  'bullnym',
  'bull',
  'bitcoin',
};

final RegExp _publicNamePattern = RegExp(
  r'^(?:[a-z0-9]|[a-z0-9][a-z0-9-]{0,30}[a-z0-9])$',
);

/// An exact normalized Bullnym public name.
///
/// Construction rejects whitespace, uppercase text, invalid characters,
/// leading/trailing hyphens, and values outside 1-32 ASCII characters. The
/// claim factories additionally apply the server's current reservation lists.
final class BullnymPublicName {
  final String value;

  const BullnymPublicName._(this.value);

  factory BullnymPublicName(String value) {
    if (!_publicNamePattern.hasMatch(value)) {
      throw ArgumentError.value(
        value,
        'value',
        'must be 1-32 lowercase ASCII letters, digits, or internal hyphens',
      );
    }
    return BullnymPublicName._(value);
  }

  factory BullnymPublicName.nymClaim(String value) {
    final name = BullnymPublicName(value);
    if (name.isReservedNym) {
      throw ArgumentError.value(value, 'value', 'is reserved by Bullnym');
    }
    return name;
  }

  factory BullnymPublicName.aliasClaim(String value) {
    final name = BullnymPublicName(value);
    if (name.isReservedAlias) {
      throw ArgumentError.value(
        value,
        'value',
        'is reserved as a Bullnym alias',
      );
    }
    return name;
  }

  bool get isReservedNym => bullnymReservedNyms.contains(value);

  bool get isReservedAlias => bullnymReservedAliases.contains(value);

  @override
  bool operator ==(Object other) =>
      other is BullnymPublicName && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Lifetime public-name quota returned by Bullnym.
final class BullnymQuota {
  final int used;
  final int cap;
  final int remaining;

  const BullnymQuota._({
    required this.used,
    required this.cap,
    required this.remaining,
  });

  factory BullnymQuota({
    required int used,
    required int cap,
    required int remaining,
  }) {
    if (used < 0 || cap < 0 || used > cap || remaining != cap - used) {
      throw ArgumentError.value(
        {'used': used, 'cap': cap, 'remaining': remaining},
        'quota',
        'must be non-negative and internally consistent',
      );
    }
    return BullnymQuota._(used: used, cap: cap, remaining: remaining);
  }
}

/// Public `/version` capability information used before any registration
/// exists. Unknown or absent policies intentionally do not enable name UX.
final class BullnymVersionInfo {
  final String? publicNamePolicy;

  const BullnymVersionInfo({required this.publicNamePolicy});

  bool get supportsPermanentNamesV1 =>
      publicNamePolicy == bullnymPermanentNamesV1Policy;
}

/// Post-registration consistency view for the permanent-name contract.
final class BullnymPublicNameStatus {
  final BullnymPublicName nym;
  final BullnymPublicName? alias;
  final bool lightningAddressOnline;
  final String publicNamePolicy;
  final BullnymQuota quota;

  const BullnymPublicNameStatus({
    required this.nym,
    required this.alias,
    required this.lightningAddressOnline,
    required this.publicNamePolicy,
    required this.quota,
  });

  bool get supportsPermanentNamesV1 =>
      publicNamePolicy == bullnymPermanentNamesV1Policy;
}

/// Alias writes have exactly two states: preserve the lifetime claim, or make
/// the first non-empty claim. Clear/replace/deactivate cannot be represented.
sealed class BullnymAliasIntent {
  const BullnymAliasIntent._();

  const factory BullnymAliasIntent.preserve() = BullnymAliasPreserve;

  factory BullnymAliasIntent.claim(BullnymPublicName alias) {
    if (alias.isReservedAlias) {
      throw ArgumentError.value(alias.value, 'alias', 'is reserved');
    }
    return BullnymAliasClaim._(alias);
  }
}

final class BullnymAliasPreserve extends BullnymAliasIntent {
  const BullnymAliasPreserve() : super._();
}

final class BullnymAliasClaim extends BullnymAliasIntent {
  final BullnymPublicName alias;

  const BullnymAliasClaim._(this.alias) : super._();
}

/// Structured ownership information attached to stable conflict codes.
sealed class BullnymOwnedNameDetails {
  final BullnymPublicName name;

  const BullnymOwnedNameDetails(this.name);
}

final class BullnymOwnedNymDetails extends BullnymOwnedNameDetails {
  final String? domain;

  const BullnymOwnedNymDetails({required BullnymPublicName nym, this.domain})
    : super(nym);

  BullnymPublicName get nym => name;
}

final class BullnymOwnedAliasDetails extends BullnymOwnedNameDetails {
  const BullnymOwnedAliasDetails({required BullnymPublicName alias})
    : super(alias);

  BullnymPublicName get alias => name;
}

/// A server-returned public surface URL that has crossed the Bullnym trust
/// boundary. Product features receive only [value], never an unchecked URL.
final class BullnymPublicUrl {
  static const int maxLength = 2048;

  final String value;

  const BullnymPublicUrl._(this.value);

  factory BullnymPublicUrl.validated({
    required String value,
    required Uri trustedPublicOrigin,
    required BullnymPublicName nym,
    required BullnymPublicName? alias,
    required String kind,
  }) {
    final uri = Uri.tryParse(value);
    final origin = trustedPublicOrigin;
    final expectedPath = switch ((kind, alias)) {
      ('payment_page', BullnymPublicName(:final value)) => '/a/$value',
      ('pos', BullnymPublicName(:final value)) => '/a/$value/pos',
      ('payment_page', null) => '/${nym.value}',
      ('pos', null) => '/${nym.value}/pos',
      _ => throw ArgumentError.value(kind, 'kind', 'unsupported surface kind'),
    };

    if (!_isTrustedOrigin(origin) ||
        value.isEmpty ||
        value.length > maxLength ||
        uri == null ||
        uri.scheme != origin.scheme ||
        uri.host != origin.host ||
        _effectivePort(uri) != _effectivePort(origin) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != expectedPath) {
      throw ArgumentError.value(
        value,
        'value',
        'is not a trusted canonical Bullnym surface URL',
      );
    }
    return BullnymPublicUrl._(value);
  }

  static int _effectivePort(Uri uri) {
    if (uri.hasPort) return uri.port;
    return uri.scheme == 'https' ? 443 : 80;
  }

  static bool _isTrustedOrigin(Uri uri) {
    final localHttp =
        uri.scheme == 'http' &&
        (uri.host == 'localhost' ||
            uri.host == '127.0.0.1' ||
            uri.host == '::1');
    return (uri.scheme == 'https' || localHttp) &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment &&
        (uri.path.isEmpty || uri.path == '/');
  }

  @override
  bool operator ==(Object other) =>
      other is BullnymPublicUrl && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}
