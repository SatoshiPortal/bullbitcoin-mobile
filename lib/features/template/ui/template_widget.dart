import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/features/template/domain/ip_address_entity.dart';
import 'package:flutter/material.dart';

class TemplateWidget extends StatelessWidget {
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 8.0;
  static const int minInputLength = 3;
  static const int maxInputLength = 100;

  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool isLoading;
  final IpAddressEntity? ipAddressData;

  const TemplateWidget({
    super.key,
    required this.title,
    this.subtitle,
    this.onTap,
    this.isLoading = false,
    this.ipAddressData,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(defaultPadding / 2),
      child: InkWell(
        onTap: isLoading ? null : onTap,
        borderRadius: BorderRadius.circular(defaultBorderRadius),
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: context.appColors.textMuted,
                        ),
                      ),
                    ],
                    if (ipAddressData != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: context.appColors.info.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: context.appColors.info.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Connection: ${ipAddressData!.displayInfo}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  ipAddressData!.isSecureConnection
                                      ? Icons.security
                                      : Icons.warning,
                                  size: 12,
                                  color:
                                      ipAddressData!.isSecureConnection
                                          ? context.appColors.success
                                          : context.appColors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ipAddressData!.isSecureConnection
                                      ? 'Secure'
                                      : 'Insecure',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color:
                                        ipAddressData!.isSecureConnection
                                            ? context.appColors.success
                                            : context.appColors.warning,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  ipAddressData!.isMobileUserAgent
                                      ? Icons.phone_android
                                      : Icons.computer,
                                  size: 12,
                                  color: context.appColors.textMuted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  ipAddressData!.isMobileUserAgent
                                      ? 'Mobile'
                                      : 'Desktop',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: context.appColors.textMuted,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: context.appColors.textMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
