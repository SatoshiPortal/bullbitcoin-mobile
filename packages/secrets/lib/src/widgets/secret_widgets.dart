import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/public/secret.dart';
import 'package:secrets/src/widgets/mnemonic_challenge.dart';
import 'package:secrets/src/widgets/mnemonic_view.dart';

/// The sealed widgets of one secret, reached as `secret.widgets`.
///
/// This is the only way to build them: the widget constructors are
/// `@internal`, so a host that wants the words on screen starts from the
/// [Secret] it holds — the same door as every other operation. Each member
/// is a single forwarding expression to a constructor; there is no
/// behaviour here.
extension type const SecretWidgets._(Secret _secret) {
  @internal
  const SecretWidgets(Secret secret) : this._(secret);

  /// Shows the words, and the passphrase when there is one. See [MnemonicView].
  MnemonicView mnemonicView({
    Key? key,
    required Widget Function(BuildContext, SecretFailure) onFailure,
    TextStyle? style,
    String? passphraseLabel,
    TextStyle? passphraseLabelStyle,
    Widget placeholder = const SizedBox.shrink(),
    Widget Function(BuildContext context, int number, Widget word)? wordBuilder,
    Widget Function(BuildContext context, List<Widget> words)? layout,
  }) => MnemonicView(
    key: key,
    secret: _secret,
    onFailure: onFailure,
    style: style,
    passphraseLabel: passphraseLabel,
    passphraseLabelStyle: passphraseLabelStyle,
    placeholder: placeholder,
    wordBuilder: wordBuilder,
    layout: layout,
  );

  /// The "tap your words in order" backup check. See [MnemonicChallenge].
  MnemonicChallenge mnemonicChallenge({
    Key? key,
    required Widget Function(BuildContext context, MnemonicTile tile)
    tileBuilder,
    required Widget Function(BuildContext context, List<Widget> tiles) layout,
    required VoidCallback onSolved,
    required VoidCallback onMistake,
    required Widget Function(BuildContext, SecretFailure) onFailure,
    void Function(int placed, int total)? onProgress,
    TextStyle? style,
    Widget placeholder = const SizedBox.shrink(),
  }) => MnemonicChallenge(
    key: key,
    secret: _secret,
    tileBuilder: tileBuilder,
    layout: layout,
    onSolved: onSolved,
    onMistake: onMistake,
    onFailure: onFailure,
    onProgress: onProgress,
    style: style,
    placeholder: placeholder,
  );
}
