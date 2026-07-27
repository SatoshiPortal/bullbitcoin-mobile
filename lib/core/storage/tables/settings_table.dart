import 'package:drift/drift.dart';

@DataClassName('SettingsRow')
class Settings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get environment => text()();
  TextColumn get bitcoinUnit => text()();
  TextColumn get language => text()();
  TextColumn get currency => text()();
  BoolColumn get hideAmounts => boolean()();
  BoolColumn get isSuperuser => boolean()();
  BoolColumn get isDevModeEnabled =>
      boolean().withDefault(const Constant(false))();
  BoolColumn get useTorProxy => boolean().withDefault(const Constant(false))();
  IntColumn get torProxyPort => integer().withDefault(const Constant(9050))();
  TextColumn get themeMode => text().withDefault(const Constant('system'))();
  BoolColumn get isErrorReportingEnabled =>
      boolean().withDefault(const Constant(false))();
  TextColumn get exchangeTestnetBasicAuthUsername => text().nullable()();
  TextColumn get exchangeTestnetBasicAuthPassword => text().nullable()();

  // Whether payjoin is enabled globally. Disabled by default ON PURPOSE:
  // payjoin trades exposure of one of the receiver's own UTXOs for on-chain
  // privacy, a trade-off the user must explicitly opt into from the payjoin
  // settings screen (which carries the disclosure). A dedicated boolean —
  // deliberately NOT a sentinel value on payjoinMinAmountSat — so toggling
  // payjoin off and back on can never reset a custom minimum amount.
  BoolColumn get payjoinEnabled =>
      boolean().withDefault(const Constant(false))();

  // Minimum receive amount (sats) below which an incoming payjoin is
  // declined and the payment broadcasts normally (anti-probing, BIP78 — see
  // PayjoinConstants.defaultMinAmountSat for the full rationale). Kept as a
  // literal: drift codegen cannot reference PayjoinConstants here — keep
  // both in sync by hand.
  IntColumn get payjoinMinAmountSat =>
      integer().withDefault(const Constant(10000))();

  // Payjoin session lifetime in seconds, shared by the receive and send
  // sides. Same codegen constraint as above: keep in sync with
  // PayjoinConstants.defaultExpireAfterSec (24 hours — see its doc comment
  // for why the default was deliberately NOT shortened).
  IntColumn get payjoinExpireAfterSec =>
      integer().withDefault(const Constant(86400))();
}
