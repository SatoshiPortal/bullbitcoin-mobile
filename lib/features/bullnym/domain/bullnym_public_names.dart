const bullnymPermanentNamesV1Policy = 'permanent_names_v1';

const bullnymReservedNyms = {
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

const bullnymReservedAliases = {
  ...bullnymReservedNyms,
  'bullbitcoin',
  'bull-bitcoin',
  'bullpay',
  'bullnym',
  'bull',
  'bitcoin',
};

final _publicNamePattern = RegExp(
  r'^(?:[a-z0-9]|[a-z0-9][a-z0-9-]{0,30}[a-z0-9])$',
);

final class BullnymPublicName {
  final String value;

  BullnymPublicName(String value) : value = value {
    if (!_publicNamePattern.hasMatch(value)) {
      throw ArgumentError.value(value, 'value', 'Invalid Bullnym public name');
    }
  }

  factory BullnymPublicName.nymClaim(String value) {
    final name = BullnymPublicName(value);
    if (name.isReservedNym) throw ArgumentError.value(value, 'value');
    return name;
  }

  factory BullnymPublicName.aliasClaim(String value) {
    final name = BullnymPublicName(value);
    if (name.isReservedAlias) throw ArgumentError.value(value, 'value');
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

final class BullnymQuota {
  final int used;
  final int cap;
  final int remaining;

  BullnymQuota({
    required this.used,
    required this.cap,
    required this.remaining,
  }) {
    if (used < 0 || cap < 0 || used > cap || remaining != cap - used) {
      throw ArgumentError.value([used, cap, remaining], 'quota');
    }
  }
}

final class BullnymVersionInfo {
  final String? publicNamePolicy;

  const BullnymVersionInfo({required this.publicNamePolicy});

  bool get supportsPermanentNamesV1 =>
      publicNamePolicy == bullnymPermanentNamesV1Policy;
}

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
}

sealed class BullnymAliasIntent {
  const BullnymAliasIntent();

  const factory BullnymAliasIntent.preserve() = BullnymAliasPreserve;

  factory BullnymAliasIntent.claim(BullnymPublicName alias) {
    if (alias.isReservedAlias) throw ArgumentError.value(alias, 'alias');
    return BullnymAliasClaim(alias);
  }
}

final class BullnymAliasPreserve extends BullnymAliasIntent {
  const BullnymAliasPreserve();
}

final class BullnymAliasClaim extends BullnymAliasIntent {
  final BullnymPublicName alias;

  const BullnymAliasClaim(this.alias);
}

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

final class BullnymPublicUrl {
  static const maxLength = 2048;

  final String value;

  BullnymPublicUrl({
    required this.value,
    required Uri trustedOrigin,
    required BullnymPublicName nym,
    required BullnymPublicName? alias,
    required String kind,
  }) {
    final uri = Uri.tryParse(value);
    final expectedPath = switch ((kind, alias)) {
      ('payment_page', BullnymPublicName(:final value)) => '/a/$value',
      ('pos', BullnymPublicName(:final value)) => '/a/$value/pos',
      ('payment_page', null) => '/${nym.value}',
      ('pos', null) => '/${nym.value}/pos',
      _ => throw ArgumentError.value(kind, 'kind'),
    };
    if (!_trustedOrigin(trustedOrigin) ||
        value.isEmpty ||
        value.length > maxLength ||
        uri == null ||
        uri.scheme != trustedOrigin.scheme ||
        uri.host != trustedOrigin.host ||
        _port(uri) != _port(trustedOrigin) ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.path != expectedPath) {
      throw ArgumentError.value(value, 'value');
    }
  }

  static int _port(Uri uri) =>
      uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);

  static bool _trustedOrigin(Uri uri) =>
      (uri.scheme == 'https' ||
          (uri.scheme == 'http' &&
              const {'localhost', '127.0.0.1', '::1'}.contains(uri.host))) &&
      uri.host.isNotEmpty &&
      uri.userInfo.isEmpty &&
      !uri.hasQuery &&
      !uri.hasFragment &&
      (uri.path.isEmpty || uri.path == '/');
}
