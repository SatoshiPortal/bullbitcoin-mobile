import 'package:satoshifier/satoshifier.dart';

enum ScriptOperand {
  bare(''), // TODO: find the operand for this
  pkh('pkh'),
  wpkh('wpkh'),
  sh('sh'),
  wsh('wsh'),
  tr('tr'),
  shwpkh('sh(wpkh');

  final String value;

  const ScriptOperand(this.value);

  static ScriptOperand fromDescriptor(String descriptor) {
    final trimmed = descriptor.trim().toLowerCase();

    if (trimmed.startsWith('sh(wpkh')) return ScriptOperand.shwpkh;
    if (trimmed.startsWith('pkh')) return ScriptOperand.pkh;
    if (trimmed.startsWith('wpkh')) return ScriptOperand.wpkh;
    if (trimmed.startsWith('sh')) return ScriptOperand.sh;
    if (trimmed.startsWith('wsh')) return ScriptOperand.wsh;
    if (trimmed.startsWith('tr')) return ScriptOperand.tr;

    throw 'Unsupported descriptor type';
  }

  static ScriptOperand fromExtendedPubkey(ExtendedPubkey pubkey) {
    if (pubkey.derivation == Derivation.bip44) return ScriptOperand.pkh;
    if (pubkey.derivation == Derivation.bip49) return ScriptOperand.shwpkh;
    if (pubkey.derivation == Derivation.bip84) return ScriptOperand.wpkh;

    throw 'Unsupported extended pubkey derivation: ${pubkey.derivation}';
  }
}
