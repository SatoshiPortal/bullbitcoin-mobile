import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/import_mnemonic/router.dart';
import 'package:bb_mobile/features/import_watch_only_wallet/import_watch_only_router.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

class ImportMethodWidget extends StatelessWidget {
  const ImportMethodWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 100, right: 100),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // BBButton.big(
              //   label: 'Upload file',
              //   onPressed: () {},
              //   bgColor: context.colour.onPrimary,
              //   textColor: context.colour.secondary,
              //   iconData: Icons.upload_file,
              //   disabled: true,
              // ),
              // const Gap(12),
              // BBButton.big(
              //   label: 'Activate NFC',
              //   onPressed: () {},
              //   bgColor: context.colour.onPrimary,
              //   textColor: context.colour.secondary,
              //   iconData: Icons.nfc,
              //   disabled: true,
              // ),
              // const Gap(12),
              BBButton.big(
                label: 'Mnemonic',
                onPressed:
                    () => context.pushNamed(
                      ImportMnemonicRoute.importMnemonicHome.name,
                    ),
                bgColor: context.colour.onPrimary,
                textColor: context.colour.secondary,
                iconData: Icons.abc,
              ),
              const Gap(12),
              BBButton.big(
                label: 'Scan QR',
                onPressed:
                    () => context.replaceNamed(ImportWalletRoutes.scan.name),
                bgColor: context.colour.onPrimary,
                textColor: context.colour.secondary,
                iconData: Icons.qr_code_scanner,
              ),
              const Gap(12),
            ],
          ),

          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                BBButton.big(
                  label: 'Buy a device',
                  onPressed:
                      () => launchUrl(
                        Uri.parse(
                          'https://store.coinkite.com/promo/BULLBITCOIN',
                        ),
                      ),
                  bgColor: context.colour.onPrimary,
                  textColor: context.colour.secondary,
                  iconData: Icons.shopping_cart,
                ),
                const Gap(12),
                BBButton.big(
                  label: 'Wallet guides',
                  onPressed:
                      () => launchUrl(
                        Uri.parse('https://docs.bull.ethicnology.com'),
                      ),
                  bgColor: context.colour.onPrimary,
                  textColor: context.colour.secondary,
                  iconData: Icons.lightbulb_outline,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
