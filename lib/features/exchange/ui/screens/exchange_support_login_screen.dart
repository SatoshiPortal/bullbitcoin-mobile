import 'package:bb_mobile/features/exchange/public/exchange_facade.dart';
import 'package:bb_mobile/features/exchange/presentation/exchange_cubit.dart';
import 'package:bull_ui/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bull_exchange/bull_exchange.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:bull_ui/bull_ui.dart'
    show
        BullText,
        BullInlineIconButton,
        BullButton,
        BullInputText,
        BullShapesX,
        Gap,
        BullSnackBar,
        BullTypographyX;
import 'package:go_router/go_router.dart';

class ExchangeSupportLoginScreen extends StatefulWidget {
  final ExchangeSupportChatDraft? draft;

  const ExchangeSupportLoginScreen({super.key, this.draft});

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
    final result = await context.read<ExchangeCubit>().enableForSupport();
    if (!mounted) return;
    setState(() => _busy = false);
    switch (result) {
      case Ok():
        context.goNamed(
          ExchangeRoute.exchangeAuth.name,
          queryParameters: {'from': 'support'},
          extra: widget.draft,
        );
      case Err(:final failure):
        BullSnackBar.show(context, message: failure.toTranslated(context));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appColors.background,
      appBar: AppBar(
        title: BullText(
          context.loc.exchangeSupportChatTitle,
          style: context.bullType.subtitle.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        backgroundColor: context.appColors.background,
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
                              context.appColors.primary,
                              context.appColors.secondaryFixed,
                              0.2,
                            ) ??
                            context.appColors.primary,
                      ),
                      const Gap(12),
                      _FakeMessageBubble(
                        isUser: true,
                        widthFraction: 0.55,
                        height: 36,
                        color: context.appColors.secondary,
                      ),
                      const Gap(12),
                      _FakeMessageBubble(
                        isUser: false,
                        widthFraction: 0.7,
                        height: 64,
                        color:
                            Color.lerp(
                              context.appColors.primary,
                              context.appColors.secondaryFixed,
                              0.2,
                            ) ??
                            context.appColors.primary,
                      ),
                      const Gap(12),
                      _FakeMessageBubble(
                        isUser: true,
                        widthFraction: 0.45,
                        height: 36,
                        color: context.appColors.secondary,
                      ),
                    ],
                  ),
                ),
                // Semi-transparent overlay with login card
                Container(
                  color: context.appColors.onSurface.withValues(alpha: 0.55),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: context.appColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(
                            context.bullShapes.card,
                          ),
                          border: Border.all(
                            color: context.appColors.outline.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 48,
                              color: context.appColors.primary,
                            ),
                            const Gap(16),
                            BullText(
                              context.loc.exchangeSupportLoginChatRequired,
                              style: context.bullType.body
                                  .copyWith(fontWeight: FontWeight.w500)
                                  .copyWith(color: context.appColors.onSurface),
                              textAlign: TextAlign.center,
                            ),
                            const Gap(24),
                            SizedBox(
                              width: double.infinity,
                              child: BullButton.primary(
                                label: context.loc.exchangeLoginButton,
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
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 24),
        decoration: BoxDecoration(
          color: context.appColors.background,
          border: Border(
            top: BorderSide(
              color: context.appColors.outline.withValues(alpha: 0.2),
            ),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 52,
              height: 52,
              child: BullInlineIconButton(
                icon: Icon(Icons.attach_file),
                tooltip: context.loc.exchangeSupportChatAttachFileTooltip,

                onPressed: null,
              ),
            ),
            const Gap(8),
            SizedBox(
              width: 52,
              height: 52,
              child: BullInlineIconButton(
                icon: Icon(Icons.description),
                tooltip: context.loc.exchangeSupportChatAttachLogsTooltip,

                onPressed: null,
              ),
            ),
            const Gap(8),
            Expanded(
              child: IgnorePointer(
                child: BullInputText(
                  value: '',
                  hint: context.loc.exchangeSupportChatInputHint,
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
                tooltip: context.loc.exchangeSupportChatSendTooltip,

                onPressed: null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
