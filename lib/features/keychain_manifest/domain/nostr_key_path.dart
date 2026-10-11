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
