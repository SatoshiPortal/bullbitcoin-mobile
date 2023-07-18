import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/popup_border.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:bb_mobile/wallet_settings/bloc/wallet_settings_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';
import 'package:qr_flutter/qr_flutter.dart';

class XPubButton extends StatelessWidget {
  const XPubButton({super.key});

  @override
  Widget build(BuildContext context) {
    final desc = context.select((WalletBloc cubit) => cubit.state.wallet!.externalDescriptor);
    if (desc.isEmpty) return const SizedBox();

    final xpub = keyFromDescr(desc);

    return BBButton.textWithLeftArrow(
      label: 'Public Descriptor',
      onPressed: () async {
        await context.read<WalletSettingsCubit>().loadSensitiveInfo();
        await XpubPopUp.openPopup(context, xpub, 'Public Descriptor');
        context.read<WalletSettingsCubit>().clearSensitiveInfo();
      },
    );
  }
}

class XPrivButton extends StatelessWidget {
  const XPrivButton({super.key});

  @override
  Widget build(BuildContext context) {
    final desc = context.select((WalletBloc cubit) => cubit.state.wallet!.internalDescriptor);
    if (desc.isEmpty) return const SizedBox();

    final xpub = keyFromPrivDescr(desc);

    return BBButton.textWithLeftArrow(
      label: 'Private Descriptor',
      onPressed: () async {
        await context.read<WalletSettingsCubit>().loadSensitiveInfo();
        await XpubPopUp.openPopup(context, xpub, 'Private Descriptor');
        context.read<WalletSettingsCubit>().clearSensitiveInfo();
      },
    );
  }
}

class XpubPopUp extends StatelessWidget {
  const XpubPopUp({
    super.key,
    required this.xpub,
    required this.title,
  });

  static Future openPopup(
    BuildContext context,
    String xpub,
    String title,
  ) {
    return showMaterialModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => PopUpBorder(
        child: XpubPopUp(
          xpub: xpub,
          title: title,
        ),
      ),
    );
  }

  final String xpub;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Gap(32),
          Row(
            children: [
              const Gap(16),
              BBText.body(
                title,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(FontAwesomeIcons.xmark),
                onPressed: () => context.pop(),
              ),
              const Gap(16),
            ],
          ),
          const Gap(24),
          Center(
            child: QrImageView(
              data: xpub,
            ),
          ),
          const Gap(16),
          _TextSection(xpub: xpub),
          const Gap(80),
        ],
      ),
    );
  }
}

class _TextSection extends StatefulWidget {
  const _TextSection({required this.xpub});

  final String xpub;

  @override
  State<_TextSection> createState() => _TextSectionState();
}

class _TextSectionState extends State<_TextSection> {
  bool showToast = false;

  void _copyClicked() async {
    setState(() {
      showToast = true;
    });
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      showToast = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      child: !showToast
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Gap(16),
                Expanded(
                  child: Wrap(
                    children: [
                      BBText.body(
                        widget.xpub,
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                IconButton(
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: widget.xpub));
                    SystemSound.play(SystemSoundType.click);
                    HapticFeedback.selectionClick();
                    _copyClicked();
                  },
                  iconSize: 16,
                  color: context.colour.secondary,
                  icon: const FaIcon(FontAwesomeIcons.copy),
                ),
              ],
            )
          : const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: BBText.body('xPub Copied to clipboard'),
            ),
    );
  }
}
