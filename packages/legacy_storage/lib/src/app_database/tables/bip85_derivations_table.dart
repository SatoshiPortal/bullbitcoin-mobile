import 'package:drift/drift.dart';

@DataClassName('Bip85DerivationRow')
class Bip85Derivations extends Table {
  TextColumn get path => text()();
  TextColumn get xprvFingerprint => text()();
  TextColumn get application => textEnum<Bip85ApplicationColumn>()();
  TextColumn get status => textEnum<Bip85StatusColumn>()();
  TextColumn get alias => text().nullable()();

  @override
  Set<Column> get primaryKey => {path};
}

enum Bip85StatusColumn { active, inactive, revoked }

enum Bip85ApplicationColumn {
  bip39,
  wif,
  xprv,
  hex,
  pwdBase64,
  pwdBase85,
  rsa,
  dice,
}
