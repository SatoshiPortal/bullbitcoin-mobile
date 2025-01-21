import 'package:bb_mobile/_ui/app_bar.dart';
import 'package:bb_mobile/_ui/components/button.dart';
import 'package:bb_mobile/_ui/components/text.dart';
import 'package:bb_mobile/_ui/toast.dart';
import 'package:bb_mobile/recover/bloc/cloud_cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class CloudPage extends StatefulWidget {
  const CloudPage({super.key});
  @override
  State<CloudPage> createState() => _CloudPageState();
}

class _CloudPageState extends State<CloudPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<CloudCubit>().readAllBackups();
      }
    });
  }

  Widget buildBackupsList(CloudState state) {
    if (state.loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (state.availableBackups.isEmpty) {
      return Center(
        child: BBButton.text(
          onPressed: () => context.read<CloudCubit>().refreshBackups(),
          label: 'Refresh',
        ),
      );
    }

    final backupEntries = state.availableBackups.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key));

    return Column(
      children: [
        if (state.lastFetchTime != null) ...[
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: BBText.bodySmall(
              'Last updated: ${DateFormat('MMM d, h:mm a').format(state.lastFetchTime!)}',
              isBold: true,
            ),
          ),
        ],
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => context.read<CloudCubit>().refreshBackups(),
            child: ListView.separated(
              itemCount: backupEntries.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final entry = backupEntries[index];
                return BackupTile(
                  fileName: entry.key,
                  onFileSelected: (fileName) {
                    context.read<CloudCubit>().loadEncrypted(fileName);
                    context.pop();
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CloudCubit, CloudState>(
      listener: (context, state) {
        if (state.toast.isNotEmpty && state.toast != '') {
          ScaffoldMessenger.of(context)
              .showSnackBar(context.showToast(state.toast));
          context.read<CloudCubit>().clearToast();
        }
        if (state.error.isNotEmpty && state.error != '') {
          ScaffoldMessenger.of(context)
              .showSnackBar(context.showToast(state.error));

          context.read<CloudCubit>().clearError();
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            elevation: 0,
            automaticallyImplyLeading: false,
            flexibleSpace: BBAppBar(
              text: 'Cloud Backup',
              onBack: () => context.pop(),
            ),
          ),
          body: Center(
            child: state.loading
                ? const CircularProgressIndicator()
                : Column(
                    children: [
                      Expanded(
                        child: buildBackupsList(state),
                      ),
                      const Gap(10),
                      BBButton.big(
                        onPressed: () {
                          context.read<CloudCubit>().disconnect();
                          context.pop();
                        },
                        label: "Logout",
                      ),
                      const Gap(20),
                    ],
                  ),
          ),
        );
      },
    );
  }
}

class BackupTile extends StatelessWidget {
  const BackupTile({
    super.key,
    required this.fileName,
    required this.onFileSelected,
  });

  final String fileName;
  final void Function(String) onFileSelected;

  @override
  Widget build(BuildContext context) {
    final cleanFileName = fileName.replaceAll(".json", "");
    final parts = cleanFileName.split('_');
    final backupId = parts.last;
    final dateTimeString = parts.first;
    final dateTime =
        DateTime.fromMillisecondsSinceEpoch(int.parse(dateTimeString));

    return ListTile(
      onTap: () => onFileSelected(fileName),
      title: BBText.body(
        backupId,
        isBold: true,
      ),
      subtitle: BBText.bodySmall(
        'Created at: ${DateFormat('MMM d, h:mm a').format(dateTime)}',
      ),
    );
  }
}
