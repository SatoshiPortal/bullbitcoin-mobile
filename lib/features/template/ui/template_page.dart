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
        title: const Text('IP Address Info'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: BlocConsumer<TemplateCubit, TemplateState>(
        listener: (context, state) {
          if (state.error != null && state.error!.isNotEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.error!),
                backgroundColor: Colors.red,
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
                  label: const Text('Collect and cache my IP info'),
                ),
                ElevatedButton.icon(
                  onPressed: state.isLoading ? null : cubit.getCachedIp,
                  icon: const Icon(Icons.remove_red_eye),
                  label: const Text('Get cached IP info'),
                ),
                const SizedBox(height: 24),
                if (state.isLoading)
                  const Center(child: CircularProgressIndicator()),
                if (!state.isLoading && state.ipAddress != null)
                  _buildIpAddressInfo(state.ipAddress!),
                if (!state.isLoading &&
                    state.error != null &&
                    state.error!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const Spacer(),
                ElevatedButton(
                  onPressed: cubit.reset,
                  child: const Text('Reset'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildIpAddressInfo(IpAddressEntity ip) {
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
                  color: ip.isSecureConnection ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                Text(
                  ip.displayInfo,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                Icon(
                  ip.isMobileUserAgent ? Icons.phone_android : Icons.computer,
                  color: Colors.blueGrey,
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow('User Agent', ip.userAgent),
            _infoRow('Compression', ip.isCompressionSupported ? 'Yes' : 'No'),
            _infoRow('Timestamp', ip.timestamp.toString()),
            const SizedBox(height: 8),
            const Text(
              'Supported Encodings:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Wrap(
              spacing: 4,
              children:
                  ip.supportedEncodings
                      .map((e) => Chip(label: Text(e.name)))
                      .toList(),
            ),
            const SizedBox(height: 8),
            const Text(
              'Accepted MIME Types:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            Wrap(
              spacing: 4,
              children:
                  ip.forwardedChain.map((e) => Chip(label: Text(e))).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
