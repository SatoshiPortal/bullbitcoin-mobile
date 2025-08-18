import 'package:bb_mobile/core/bip85_derivations/domain/bip85_derivation_entity.dart';
import 'package:drift/drift.dart';

@DataClassName('Bip85DerivationRow')
class Bip85Derivations extends Table {
  TextColumn get derivation => text()();
  TextColumn get xprvFingerprint => text()();
  TextColumn get application => textEnum<Bip85ApplicationColumn>()();
  TextColumn get status => textEnum<Bip85StatusColumn>()();
  TextColumn get alias => text().nullable()();

  @override
  Set<Column> get primaryKey => {derivation};
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
  bip39(39),
  wif(2),
  xprv(32),
  hex(128169),
  pwdBase64(707764),
  pwdBase85(707785),
  rsa(828365),
  dice(89101);

  final int number;

  const Bip85ApplicationColumn(this.number);

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
