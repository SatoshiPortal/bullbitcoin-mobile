import 'package:bb_mobile/core/bip85/domain/bip85_reservations.dart';

bool isNostrAppReservedIdentity(int identity) =>
    identity >= 100 && identity <= 199;

String nostrUserKeyPath(int identity) {
  if (identity < 1 ||
      identity > Bip85Reservations.maxIndex ||
      isNostrAppReservedIdentity(identity)) {
    throw const FormatException('Invalid Nostr key index');
  }
  return "128002'/$identity'/1'";
}

int? nostrUserKeyIdentity(String path) {
  final match = RegExp(
    r"^(?:m/)?(?:83696968['hH]/)?0*128002['hH]/(\d+)['hH]/0*1['hH]$",
  ).firstMatch(path.trim());
  final identity = match == null ? null : int.tryParse(match.group(1)!);
  return identity != null &&
          identity >= 1 &&
          identity <= Bip85Reservations.maxIndex &&
          !isNostrAppReservedIdentity(identity)
      ? identity
      : null;
}
