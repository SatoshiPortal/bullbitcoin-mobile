import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/text_input.dart';
import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/exchange/ui/exchange_router.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class ExchangeSupportLoginScreen extends StatelessWidget {
  const ExchangeSupportLoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.goNamed(WalletRoute.walletHome.name);
      },
      child: Scaffold(
        backgroundColor: context.appColors.background,
        appBar: AppBar(
          leading: BackButton(
            color: context.appColors.onSurface,
            onPressed: () => context.goNamed(WalletRoute.walletHome.name),
          ),
          title: BBText(
            context.loc.exchangeSupportChatTitle,
            style: context.font.headlineMedium,
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
                          color: Color.lerp(
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
                          color: Color.lerp(
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
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: context.appColors.outline
                                  .withValues(alpha: 0.3),
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
                              BBText(
                                context.loc.exchangeSupportLoginChatRequired,
                                style: context.font.bodyLarge?.copyWith(
                                  color: context.appColors.onSurface,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const Gap(24),
                              SizedBox(
                                width: double.infinity,
                                child: BBButton.big(
                                  label: context.loc.exchangeLoginButton,
                                  onPressed: () {
                                    context.goNamed(
                                      ExchangeRoute.exchangeAuth.name,
                                    );
                                  },
                                  bgColor: context.appColors.primary,
                                  textColor: context.appColors.onPrimary,
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
      mainAxisAlignment:
          isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
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
        padding: const EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: 24,
        ),
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
              child: BBButton.big(
                label: '',
                iconData: Icons.attach_file,
                disabled: true,
                onPressed: () {},
                bgColor: context.appColors.surfaceContainer,
                textColor: context.appColors.onSurface,
                width: 52,
                height: 52,
              ),
            ),
            const Gap(8),
            SizedBox(
              width: 52,
              height: 52,
              child: BBButton.big(
                label: '',
                iconData: Icons.description,
                disabled: true,
                onPressed: () {},
                bgColor: context.appColors.surfaceContainer,
                textColor: context.appColors.onSurface,
                width: 52,
                height: 52,
              ),
            ),
            const Gap(8),
            Expanded(
              child: IgnorePointer(
                child: BBInputText(
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
              child: BBButton.big(
                label: '',
                iconData: Icons.send,
                disabled: true,
                onPressed: () {},
                bgColor:
                    Color.lerp(
                      context.appColors.primary,
                      context.appColors.secondaryFixed,
                      0.2,
                    ) ??
                    context.appColors.primary,
                textColor: context.appColors.onPrimary,
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
