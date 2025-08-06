import 'package:bb_mobile/core/widgets/text/text.dart';
import 'package:bb_mobile/features/template/domain/ip_address_entity.dart';
import 'package:bb_mobile/features/template/presentation/template_cubit.dart';
import 'package:bb_mobile/features/template/presentation/template_state.dart';
import 'package:bb_mobile/features/template/template_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

class TemplatePage extends StatelessWidget {
  const TemplatePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BBText(
          'IP Address Info',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: BlocConsumer<TemplateCubit, TemplateState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: BBText(
                  state.error!.toString(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  color: Theme.of(context).colorScheme.onError,
                ),
              ),
            );
            if (state.redirection == Redirection.toSomewhereElse) {
              context.push(
                TemplateRoute.emptyPage.path,
                extra: state.ipAddress!.ipAddress,
              );
            }
          }
        },
        builder: (context, state) {
          final cubit = context.read<TemplateCubit>();
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ElevatedButton.icon(
                  onPressed: state.isLoading ? null : cubit.collectIp,
                  icon: const Icon(Icons.download),
                  label: BBText(
                    'Collect and cache my IP info',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: state.isLoading ? null : cubit.getCachedIp,
                  icon: const Icon(Icons.remove_red_eye),
                  label: BBText(
                    'Get cached IP info',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                const SizedBox(height: 24),
                if (state.isLoading)
                  const Center(child: CircularProgressIndicator()),
                if (!state.isLoading && state.ipAddress != null)
                  _buildIpAddressInfo(context, state.ipAddress!),
                if (!state.isLoading && state.error != null)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: BBText(
                      state.error!.toString(),
                      style: Theme.of(context).textTheme.bodyMedium,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: cubit.reset,
                  child: BBText(
                    'Reset',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIpAddressInfo(BuildContext context, IpAddressEntity ip) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  ip.isSecureConnection ? Icons.lock : Icons.lock_open,
                  color:
                      ip.isSecureConnection
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(width: 8),
                BBText(
                  ip.displayInfo,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                Icon(
                  ip.isMobileUserAgent ? Icons.phone_android : Icons.computer,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(context, 'User Agent', ip.userAgent),
            _infoRow(
              context,
              'Compression',
              ip.isCompressionSupported ? 'Yes' : 'No',
            ),
            _infoRow(context, 'Timestamp', ip.timestamp.toString()),
            const SizedBox(height: 8),
            BBText(
              'Supported Encodings:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Wrap(
              spacing: 4,
              children:
                  ip.supportedEncodings
                      .map(
                        (e) => Chip(
                          label: BBText(
                            e.name,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                      .toList(),
            ),
            const SizedBox(height: 8),
            BBText(
              'Accepted MIME Types:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Wrap(
              spacing: 4,
              children:
                  ip.forwardedChain
                      .map(
                        (e) => Chip(
                          label: BBText(
                            e,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                      .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: BBText(
              '$label:',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: BBText(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
