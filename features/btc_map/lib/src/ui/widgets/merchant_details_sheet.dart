import 'package:btc_map/src/map_types.dart';
import 'package:bull_ui/bull_ui.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:url_launcher/url_launcher.dart';

import 'package:btc_map/src/presentation/map_localizations_x.dart';
import 'package:btc_map/src/ui/merchant_display_x.dart';

Future<void> showMerchantDetailsSheet(
  BuildContext context,
  Merchant merchant,
) => BullBottomSheet.show(
  context: context,
  child: MerchantDetailsSheet(merchant: merchant),
);

class MerchantDetailsSheet extends StatelessWidget {
  const MerchantDetailsSheet({super.key, required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.bullType;
    final colors = context.bull;
    final address = merchant.address;
    final openingHours = merchant.openingHoursRules;
    final description = merchant.description;
    final phone = merchant.phone;
    final email = merchant.email;
    final website = merchant.website;
    final requiredAppUrl = merchant.requiredAppUrl;
    final btcMapUrl = merchant.btcMapUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BullText(
            merchant.name ?? context.btcMapLoc.merchantMapUnnamed,
            style: textTheme.title,
            color: colors.onSurface,
          ),
          const Gap(8),
          _VerificationRow(merchant: merchant),
          if (description != null) ...[
            const Gap(12),
            BullText(
              description,
              style: textTheme.body,
              color: colors.onSurface,
            ),
          ],
          if (merchant.paymentMethods.isNotEmpty)
            _Field(
              label: context.btcMapLoc.merchantMapAccepts,
              value: [
                for (final method in MerchantPaymentMethod.values)
                  if (merchant.paymentMethods.contains(method))
                    method.label(context),
              ].join(' · '),
            ),
          if (address != null)
            _Field(label: context.btcMapLoc.merchantMapAddress, value: address),
          if (openingHours.isNotEmpty)
            _Field(
              label: context.btcMapLoc.merchantMapOpeningHours,
              value: openingHours.join('\n'),
            ),
          const Gap(8),
          if (requiredAppUrl != null)
            BullSettingsEntryItem(
              icon: BullIcons.qrCode,
              title: context.btcMapLoc.merchantMapRequiredApp,
              subtitle: _displayHost(requiredAppUrl),
              onTap: () => _open(context, requiredAppUrl),
            ),
          if (phone != null)
            BullSettingsEntryItem(
              icon: BullIcons.phoneOutlined,
              title: context.btcMapLoc.merchantMapPhone,
              subtitle: phone,
              onTap: () => _open(context, Uri(scheme: 'tel', path: phone)),
            ),
          if (email != null)
            BullSettingsEntryItem(
              icon: BullIcons.emailOutlined,
              title: context.btcMapLoc.merchantMapEmail,
              subtitle: email,
              onTap: () => _open(context, Uri(scheme: 'mailto', path: email)),
            ),
          if (website != null)
            BullSettingsEntryItem(
              icon: BullIcons.language,
              title: context.btcMapLoc.merchantMapWebsite,
              subtitle: _displayHost(website),
              onTap: () => _open(context, website),
            ),
          for (final link in merchant.socialLinks)
            BullSettingsEntryItem(
              icon: BullIcons.link,
              title: _displayHost(link),
              subtitle: link.path.length > 1 ? link.path : null,
              onTap: () => _open(context, link),
            ),
          if (btcMapUrl != null)
            BullSettingsEntryItem(
              icon: BullIcons.currencyBitcoin,
              title: context.btcMapLoc.merchantMapViewOnBtcMap,
              subtitle: context.btcMapLoc.merchantMapViewOnBtcMapSubtitle,
              onTap: () => _open(context, btcMapUrl),
            ),
        ],
      ),
    );
  }

  /// `instagram.com` rather than `https://www.instagram.com/`.
  static String _displayHost(Uri uri) =>
      uri.host.startsWith('www.') ? uri.host.substring(4) : uri.host;

  /// Outside the app, in the browser, dialer or mail app. Says so when no app
  /// on the device can open it (no dialer, no mail app).
  static Future<void> _open(BuildContext context, Uri uri) async {
    bool opened;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      opened = false;
    }
    if (opened || !context.mounted) return;
    BullSnackBar.show(
      context,
      message: context.btcMapLoc.merchantMapLinkFailed,
    );
  }
}

/// The verified badge, or the attention one when the listing is stale or was
/// never confirmed, with the day of the last confirmation.
class _VerificationRow extends StatelessWidget {
  const _VerificationRow({required this.merchant});

  final Merchant merchant;

  @override
  Widget build(BuildContext context) {
    final verification = merchant.verificationAt(DateTime.now());
    final verifiedAt = merchant.verifiedAt;
    final day = verifiedAt == null
        ? null
        : DateFormat.yMMMd(
            Localizations.localeOf(context).toString(),
          ).format(DateTime(verifiedAt.year, verifiedAt.month, verifiedAt.day));
    final text = switch ((verification, day)) {
      (MerchantVerification.recent, final String day) =>
        context.btcMapLoc.merchantMapVerifiedOn(day),
      (MerchantVerification.outdated, final String day) =>
        context.btcMapLoc.merchantMapVerificationOutdated(day),
      _ => context.btcMapLoc.merchantMapNeverVerified,
    };
    final color = verification.color(context);
    return Row(
      key: ValueKey('merchant-verification-${verification.name}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BullIcon(verification.icon, color: color, size: 20),
        const Gap(8),
        Expanded(
          child: BullText(text, style: context.bullType.body, color: color),
        ),
      ],
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = context.bullType;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BullText(
            label,
            style: textTheme.caption,
            color: context.bull.textMuted,
          ),
          const Gap(2),
          BullText(value, style: textTheme.body, color: context.bull.onSurface),
        ],
      ),
    );
  }
}
