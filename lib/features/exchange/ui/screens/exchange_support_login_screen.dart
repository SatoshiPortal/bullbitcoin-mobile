import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/exchange_support_chat/public/exchange_support_chat_facade.dart';
import 'package:flutter/material.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:go_router/go_router.dart';

class ExchangeSupportLoginScreen extends StatelessWidget {
  final ExchangeSupportChatDraft? draft;

  const ExchangeSupportLoginScreen({super.key, this.draft});

  @override
  Widget build(BuildContext context) {
    return BullPage(
      padding: EdgeInsets.zero,
      topBar: BullTopBar(
        title: context.loc.exchangeSupportChatTitle,
        onBack: context.pop,
      ),
      child: Column(
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
                          borderRadius: BorderRadius.circular(16),
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
                              context.loc.exchangeSupportLoginChatRequired,
                              style: context.bullText.bodyLarge?.copyWith(
                                color: context.bull.onSurface,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const Gap(24),
                            SizedBox(
                              width: double.infinity,
                              child: BullButton.big(
                                label: context.loc.exchangeLoginButton,
                                onPressed: () {
                                  context.goNamed(
                                    ExchangeRoute.exchangeAuth.name,
                                    queryParameters: {'from': 'support'},
                                    extra: draft,
                                  );
                                },
                                bgColor: context.bull.primary,
                                textColor: context.bull.onPrimary,
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
            borderRadius: BorderRadius.circular(12),
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
              child: BullButton.big(
                label: '',
                iconData: Icons.attach_file,
                disabled: true,
                onPressed: () {},
                bgColor: context.bull.surfaceContainer,
                textColor: context.bull.onSurface,
                width: 52,
                height: 52,
              ),
            ),
            const Gap(8),
            SizedBox(
              width: 52,
              height: 52,
              child: BullButton.big(
                label: '',
                iconData: Icons.description,
                disabled: true,
                onPressed: () {},
                bgColor: context.bull.surfaceContainer,
                textColor: context.bull.onSurface,
                width: 52,
                height: 52,
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
              child: BullButton.big(
                label: '',
                iconData: Icons.send,
                disabled: true,
                onPressed: () {},
                bgColor:
                    Color.lerp(
                      context.bull.primary,
                      context.bull.secondaryFixed,
                      0.2,
                    ) ??
                    context.bull.primary,
                textColor: context.bull.onPrimary,
                width: 52,
                height: 52,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
