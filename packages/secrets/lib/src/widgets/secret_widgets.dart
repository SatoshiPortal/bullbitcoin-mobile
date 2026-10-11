import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:secrets/src/domain/domain.dart';
import 'package:secrets/src/public/secret.dart';
import 'package:secrets/src/public/ephemeral_mnemonic.dart';
import 'package:secrets/src/widgets/mnemonic_source.dart';
import 'package:secrets/src/widgets/mnemonic_challenge.dart';
import 'package:secrets/src/widgets/mnemonic_view.dart';
import 'package:secrets/src/widgets/nostr_key_view.dart';

/// The sealed widgets of one secret, reached as `secret.widgets`.
///
/// This is the only way to build them: the widget constructors are
/// `@internal`, so a host that wants the words on screen starts from the
/// [Secret] it holds — the same door as every other operation. Each member
/// is a single forwarding expression to a constructor; there is no
/// behaviour here.
extension type const SecretWidgets._(MnemonicSource _source) {
  @internal
  SecretWidgets(Secret secret) : this._(StoredMnemonicSource(secret));

  @internal
  SecretWidgets.ephemeral(EphemeralMnemonic mnemonic)
    : this._(EphemeralMnemonicSource(mnemonic));

  /// Shows an nsec after the host's warning and screen-capture protection.
  /// User identities derive from this secret; 100/101 are backup identities.
  /// The host receives rendered text, a QR and a copy action, never the nsec.
  NostrKeyView nostrKey({
    Key? key,
    required int identity,
    required String publicKey,
    required Color qrForeground,
    required Color qrBackground,
    required Widget Function(
      BuildContext,
      Widget text,
      Widget qr,
      Future<void> Function() copy,
    )
    builder,
    required Widget Function(BuildContext, SecretFailure, VoidCallback retry)
    failureBuilder,
    TextStyle? style,
    Widget placeholder = const SizedBox.shrink(),
  }) => NostrKeyView(
    key: key,
    secret: requireStoredSecret(_source),
    identity: identity,
    publicKey: publicKey,
    qrForeground: qrForeground,
    qrBackground: qrBackground,
    builder: builder,
    failureBuilder: failureBuilder,
    style: style,
    placeholder: placeholder,
  );

  /// Shows deterministic Data Recovery Words without exposing their text.
  MnemonicView dataRecoveryWords({
    Key? key,
    required Widget Function(BuildContext, SecretFailure, VoidCallback retry)
    failureBuilder,
    TextStyle? style,
    Widget placeholder = const SizedBox.shrink(),
    Widget Function(BuildContext context, int number, Widget word)? wordBuilder,
    Widget Function(BuildContext context, List<Widget> words)? layoutBuilder,
  }) => MnemonicView(
    key: ValueKey(('data-recovery', key, _source.id)),
    source: DataRecoveryMnemonicSource.fromSource(_source),
    failureBuilder: failureBuilder,
    style: style,
    placeholder: placeholder,
    wordBuilder: wordBuilder,
    layoutBuilder: layoutBuilder,
  );

  /// Shows the words, and the passphrase when there is one. See [MnemonicView].
  MnemonicView mnemonicView({
    Key? key,
    required Widget Function(BuildContext, SecretFailure, VoidCallback retry)
    failureBuilder,
    TextStyle? style,
    String? passphraseLabel,
    TextStyle? passphraseLabelStyle,
    Widget placeholder = const SizedBox.shrink(),
    Widget Function(BuildContext context, int number, Widget word)? wordBuilder,
    Widget Function(BuildContext context, List<Widget> words)? layoutBuilder,
  }) => MnemonicView(
    key: key,
    source: _source,
    failureBuilder: failureBuilder,
    style: style,
    passphraseLabel: passphraseLabel,
    passphraseLabelStyle: passphraseLabelStyle,
    placeholder: placeholder,
    wordBuilder: wordBuilder,
    layoutBuilder: layoutBuilder,
  );

  /// The "tap your words in order" backup check. See [MnemonicChallenge].
  MnemonicChallenge mnemonicChallenge({
    Key? key,
    required Widget Function(BuildContext context, MnemonicTile tile)
    tileBuilder,
    required Widget Function(BuildContext context, List<Widget> tiles)
    layoutBuilder,
    required VoidCallback onSolved,
    required VoidCallback onMistake,
    required Widget Function(BuildContext, SecretFailure, VoidCallback retry)
    failureBuilder,
    void Function(int placed, int total)? onProgress,
    TextStyle? style,
    Widget placeholder = const SizedBox.shrink(),
  }) => MnemonicChallenge(
    key: key,
    source: _source,
    tileBuilder: tileBuilder,
    layoutBuilder: layoutBuilder,
    onSolved: onSolved,
    onMistake: onMistake,
    failureBuilder: failureBuilder,
    onProgress: onProgress,
    style: style,
    placeholder: placeholder,
  );
}
