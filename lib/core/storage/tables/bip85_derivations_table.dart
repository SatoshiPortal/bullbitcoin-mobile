import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
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

enum Bip85StatusColumn {
  active,
  inactive,
  revoked;

  static Bip85StatusColumn fromEntity(Bip85Status status) {
    switch (status) {
      case Bip85Status.active:
        return Bip85StatusColumn.active;
      case Bip85Status.inactive:
        return Bip85StatusColumn.inactive;
      case Bip85Status.revoked:
        return Bip85StatusColumn.revoked;
    }
  }

  Bip85Status toEntity() {
    switch (this) {
      case Bip85StatusColumn.active:
        return Bip85Status.active;
      case Bip85StatusColumn.inactive:
        return Bip85Status.inactive;
      case Bip85StatusColumn.revoked:
        return Bip85Status.revoked;
    }
  }
}

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

  static Bip85ApplicationColumn fromEntity(Bip85Application application) {
    switch (application) {
      case Bip85Application.bip39:
        return Bip85ApplicationColumn.bip39;
      case Bip85Application.wif:
        return Bip85ApplicationColumn.wif;
      case Bip85Application.xprv:
        return Bip85ApplicationColumn.xprv;
      case Bip85Application.hex:
        return Bip85ApplicationColumn.hex;
      case Bip85Application.pwdBase64:
        return Bip85ApplicationColumn.pwdBase64;
      case Bip85Application.pwdBase85:
        return Bip85ApplicationColumn.pwdBase85;
      case Bip85Application.rsa:
        return Bip85ApplicationColumn.rsa;
      case Bip85Application.dice:
        return Bip85ApplicationColumn.dice;
    }
  }

  Bip85Application toEntity() {
    switch (this) {
      case Bip85ApplicationColumn.bip39:
        return Bip85Application.bip39;
      case Bip85ApplicationColumn.wif:
        return Bip85Application.wif;
      case Bip85ApplicationColumn.xprv:
        return Bip85Application.xprv;
      case Bip85ApplicationColumn.hex:
        return Bip85Application.hex;
      case Bip85ApplicationColumn.pwdBase64:
        return Bip85Application.pwdBase64;
      case Bip85ApplicationColumn.pwdBase85:
        return Bip85Application.pwdBase85;
      case Bip85ApplicationColumn.rsa:
        return Bip85Application.rsa;
      case Bip85ApplicationColumn.dice:
        return Bip85Application.dice;
    }
  }
}
