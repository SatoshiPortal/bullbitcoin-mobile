import 'package:bull_ui/bull_ui.dart'
    show BuildContext, BullReceiveSendButtons, StatelessWidget, Widget;
import 'package:primitives/primitives.dart' show ScriptType;
import 'package:sync/sync.dart' show WalletKey;

typedef OverviewReceiveTarget = ({
  WalletKey key,
  ScriptType scriptType,
  bool signsLocally,
});

/// Home starts the default flows. Detail starts only with its originally
/// rendered, still-admitted wallet; it never falls back to a Home flow.
class OverviewWalletButtons extends StatelessWidget {
  final String receiveLabel;
  final String sendLabel;
  final void Function(OverviewReceiveTarget?) onReceive;
  final void Function(WalletKey?) onSend;
  final ({
    OverviewReceiveTarget target,
    bool watchOnly,
    bool Function() isCurrent,
  })?
  _selection;

  const OverviewWalletButtons.home({
    super.key,
    required this.receiveLabel,
    required this.sendLabel,
    required this.onReceive,
    required this.onSend,
  }) : _selection = null;

  const OverviewWalletButtons.wallet({
    super.key,
    required this.receiveLabel,
    required this.sendLabel,
    required this.onReceive,
    required this.onSend,
    required OverviewReceiveTarget target,
    required bool watchOnly,
    required bool Function() isCurrent,
  }) : _selection = (
         target: target,
         watchOnly: watchOnly,
         isCurrent: isCurrent,
       );

  @override
  Widget build(BuildContext context) => BullReceiveSendButtons(
    receiveLabel: receiveLabel,
    sendLabel: sendLabel,
    onReceive: () {
      if (context.mounted && (_selection?.isCurrent() ?? true)) {
        onReceive(_selection?.target);
      }
    },
    onSend: _selection?.watchOnly == true
        ? null
        : () {
            if (context.mounted && (_selection?.isCurrent() ?? true)) {
              onSend(_selection?.target.key);
            }
          },
  );
}
