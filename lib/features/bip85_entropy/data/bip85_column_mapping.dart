import 'package:bb_mobile/core/storage/tables/bip85_derivations_table.dart';

import '../domain/bip85_derivation_entity.dart';

extension Bip85StatusMapping on Bip85StatusColumn {
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

extension Bip85ApplicationMapping on Bip85ApplicationColumn {
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
