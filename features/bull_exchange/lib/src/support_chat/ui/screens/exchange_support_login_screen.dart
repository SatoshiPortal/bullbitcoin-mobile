import 'package:exchange/exchange.dart';
import 'package:material_ui/material_ui.dart';
import 'package:primitives/primitives.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullText,
        BullInlineIconButton,
        BullButton,
        BullInputText,
        BullShapesX,
        Gap,
        BullSnackBar,
        BullTypographyX,
        BullThemeX;

import '../../../../generated/l10n/exchange_localizations.dart';

class ExchangeSupportLoginScreen extends StatefulWidget {
  final Future<Result<void, ExchangeFailure>> Function(BuildContext) enable;
  final void Function(BuildContext) onLogin;
  final String Function(BuildContext) loginLabel;
  final String Function(BuildContext, ExchangeFailure) failureMessage;

  const ExchangeSupportLoginScreen({
    super.key,
    required this.enable,
    required this.onLogin,
    required this.loginLabel,
    required this.failureMessage,
  });

  @override
  State<ExchangeSupportLoginScreen> createState() =>
      _ExchangeSupportLoginScreenState();
}

class _ExchangeSupportLoginScreenState
    extends State<ExchangeSupportLoginScreen> {
  bool _busy = false;

  Future<void> _login() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await widget.enable(context);
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok():
        widget.onLogin(context);
      case Err(:final failure):
        BullSnackBar.show(
          context,
          message: widget.failureMessage(context, failure),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ExchangeLocalizations.of(context);
    return Scaffold(
      backgroundColor: context.bull.background,
      appBar: AppBar(
        title: BullText(
          loc.exchangeSupportChatTitle,
          style: context.bullType.subtitle.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: context.bull.background,
      ),
      body: Column(
        children: [
          // Chat area with overlay
          Expanded(
            child: Stack(
              children: [
                // Background: fake message bubbles
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      _FakeMessageBubble(
                        isUser: false,
                        widthFraction: 0.65,
                        height: 48,
                        color:
                            Color.lerp(
                              context.bull.primary,
                              context.bull.secondaryFixed,
                              0.2,
                            ) ??
                            context.bull.primary,
                      ),
                      const Gap(12),
                      _FakeMessageBubble(
                        isUser: true,
                        widthFraction: 0.55,
                        height: 36,
                        color: context.bull.secondary,
                      ),
                      const Gap(12),
                      _FakeMessageBubble(
                        isUser: false,
                        widthFraction: 0.7,
                        height: 64,
                        color:
                            Color.lerp(
                              context.bull.primary,
                              context.bull.secondaryFixed,
                              0.2,
                            ) ??
                            context.bull.primary,
                      ),
                      const Gap(12),
                      _FakeMessageBubble(
                        isUser: true,
                        widthFraction: 0.45,
                        height: 36,
                        color: context.bull.secondary,
                      ),
                    ],
                  ),
                ),
                // Semi-transparent overlay with login card
                Container(
                  color: context.bull.onSurface.withValues(alpha: 0.55),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: context.bull.surfaceContainer,
                          borderRadius: BorderRadius.circular(
                            context.bullShapes.card,
                          ),
                          border: Border.all(
                            color: context.bull.outline.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: context.bull.primary,
                            ),
                            const Gap(16),
                            BullText(
                              loc.exchangeSupportLoginChatRequired,
                              style: context.bullType.body
                                  .copyWith(fontWeight: FontWeight.w500)
                                  .copyWith(color: context.bull.onSurface),
                              textAlign: TextAlign.center,
                            ),
                            const Gap(24),
                            SizedBox(
                              width: double.infinity,
                              child: BullButton.primary(
                                label: widget.loginLabel(context),
                                onPressed: (_busy) ? null : _login,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Input bar sits outside the overlay — always fully visible
          const _DisabledMessageInput(),
        ],
      ),
    );
  }
}

class _FakeMessageBubble extends StatelessWidget {
  const _FakeMessageBubble({
    required this.isUser,
    required this.widthFraction,
    required this.height,
    required this.color,
  });

  final bool isUser;
  final double widthFraction;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: [
        Container(
          width: MediaQuery.of(context).size.width * widthFraction,
          height: height,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(context.bullShapes.card),
          ),
        ),
      ],
    );
  }
}

class _DisabledMessageInput extends StatelessWidget {
  const _DisabledMessageInput();

  @override
  Widget build(BuildContext context) {
    final loc = ExchangeLocalizations.of(context);
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 24),
        decoration: BoxDecoration(
          color: context.bull.background,
          border: Border(
            top: BorderSide(color: context.bull.outline.withValues(alpha: 0.2)),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: BullInlineIconButton(
                icon: Icon(Icons.attach_file),
                tooltip: loc.exchangeSupportChatAttachFileTooltip,

                onPressed: null,
              ),
            ),
            const Gap(8),
            SizedBox(
              width: 52,
              height: 52,
              child: BullInlineIconButton(
                icon: Icon(Icons.description),
                tooltip: loc.exchangeSupportChatAttachLogsTooltip,

                onPressed: null,
              ),
            ),
            const Gap(8),
            Expanded(
              child: IgnorePointer(
                child: BullInputText(
                  value: '',
                  hint: loc.exchangeSupportChatInputHint,
                  maxLines: 1,
                  onChanged: (_) {},
                ),
              ),
            ),
            const Gap(8),
            SizedBox(
              width: 52,
              height: 52,
              child: BullInlineIconButton(
                icon: Icon(Icons.send),
                tooltip: loc.exchangeSupportChatSendTooltip,

                onPressed: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
