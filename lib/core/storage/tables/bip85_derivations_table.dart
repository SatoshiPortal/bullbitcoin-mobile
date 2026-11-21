import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
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
  dice;

  int get number {
    switch (this) {
      case Bip85ApplicationColumn.bip39:
        return const bip85.MnemonicApplication().number;
      case Bip85ApplicationColumn.wif:
        return const bip85.WifApplication().number;
      case Bip85ApplicationColumn.xprv:
        return const bip85.XprvApplication().number;
      case Bip85ApplicationColumn.hex:
        return const bip85.HexApplication().number;
      case Bip85ApplicationColumn.pwdBase64:
        return const bip85.PasswordBase64Application().number;
      case Bip85ApplicationColumn.pwdBase85:
        return const bip85.PasswordBase85Application().number;
      case Bip85ApplicationColumn.rsa:
        return const bip85.RsaApplication().number;
      case Bip85ApplicationColumn.dice:
        return const bip85.DiceApplication().number;
      // case Bip85ApplicationColumn.customBackup:
      //   return const 999;
    }
  }
}
