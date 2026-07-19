import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/snackbar_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class PrivateInvoiceLinkActions extends StatelessWidget {
  final String link;
  final bool showLink;

  const PrivateInvoiceLinkActions({
    super.key,
    required this.link,
    this.showLink = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showLink) ...[
          CopyInput(text: link, maxLines: 2, overflow: TextOverflow.ellipsis),
          const Gap(12),
        ],
        BBButton.big(
          label: context.loc.invoiceCopyPrivateLink,
          iconData: Icons.copy,
          iconFirst: true,
          onPressed: () => _copy(context),
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        const Gap(8),
        BBButton.big(
          label: context.loc.invoiceSharePrivateLink,
          iconData: Icons.share,
          iconFirst: true,
          onPressed: _share,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
        const Gap(8),
        BBButton.big(
          label: context.loc.invoiceOpenLink,
          iconData: Icons.open_in_new,
          iconFirst: true,
          onPressed: _open,
          bgColor: context.appColors.secondary,
          textColor: context.appColors.onSecondary,
        ),
      ],
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) SnackBarUtils.showCopiedSnackBar(context);
  }

  Future<void> _share() => SharePlus.instance.share(ShareParams(text: link));

  Future<void> _open() async {
    final uri = Uri.tryParse(link);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
