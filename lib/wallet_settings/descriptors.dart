import 'package:bb_mobile/_pkg/clipboard.dart';
import 'package:bb_mobile/_pkg/wallet/utils.dart';
import 'package:bb_mobile/_ui/bottom_sheet.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/headers.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bb_mobile/styles.dart';
import 'package:bb_mobile/wallet/bloc/wallet_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:gap/gap.dart';
import 'package:qr_flutter/qr_flutter.dart';

class PublicDescriptorButton extends StatelessWidget {
  const PublicDescriptorButton({super.key});

  @override
  Widget build(BuildContext context) {
    final desc = context.select(
      (WalletBloc cubit) => cubit.state.wallet!.externalPublicDescriptor,
    );
    if (desc.isEmpty) return const SizedBox();

    return BBButton.textWithStatusAndRightArrow(
      label: 'Public Keys',
      onPressed: () async {
        // no more loading and clearing sensitive data
        await PublicDataPopUp.openPopup(
          context,
          combinedDescriptorString(desc),
          'Public Descriptor',
        );
      },
    );
  }
}

class ExtendedPublicKeyButton extends StatelessWidget {
  const ExtendedPublicKeyButton({super.key});

  @override
  Widget build(BuildContext context) {
    final desc = context.select(
      (WalletBloc cubit) => cubit.state.wallet!.externalPublicDescriptor,
    );
    if (desc.isEmpty) return const SizedBox();

    return BBButton.textWithStatusAndRightArrow(
      label: 'Extended Public Key',
      onPressed: () async {
        await PublicDataPopUp.openPopup(
          context,
          fullKeyFromDescriptor(desc),
          'Extended Public Key',
        );
      },
    );
  }
}

class PublicDataPopUp extends StatelessWidget {
  const PublicDataPopUp({
    super.key,
    required this.publicKeyData,
    required this.title,
  });

  static Future openPopup(
    BuildContext context,
    String publicKeyData,
    String title,
  ) {
    return showBBBottomSheet(
      context: context,
      child: PublicDataPopUp(
        publicKeyData: publicKeyData,
        title: title,
      ),
    );
  }

  final String publicKeyData;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          BBHeader.popUpCenteredText(text: title, isLeft: true),
          const Gap(16),
          Center(
            child: QrImageView(
              data: publicKeyData,
            ),
          ),
          const Gap(16),
          _TextSection(publicKeyData: publicKeyData),
          const Gap(80),
        ],
      ),
    );
  }
}

class _TextSection extends StatefulWidget {
  const _TextSection({required this.publicKeyData});

  final String publicKeyData;

  @override
  State<_TextSection> createState() => _TextSectionState();
}

class _TextSectionState extends State<_TextSection> {
  bool showToast = false;

  void _copyClicked() async {
    if (mounted) {
      setState(() {
        showToast = true;
      });
    }
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() {
        showToast = false;
      });
    }
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
                        widget.publicKeyData,
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                IconButton(
                  onPressed: () async {
                    if (locator.isRegistered<Clippboard>()) {
                      await locator<Clippboard>().copy(widget.publicKeyData);
                    }

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
              child: BBText.body('Public Key Data Copied to clipboard'),
            ),
    );
  }
}
