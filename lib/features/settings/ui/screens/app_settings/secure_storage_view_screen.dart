import 'package:bb_mobile/core/mixins/privacy_screen.dart';
import 'package:bb_mobile/core/storage/domain/usecase/get_all_secure_storage_values_usecase.dart';
import 'package:bb_mobile/locator.dart';
import 'package:flutter/material.dart';

class SecureStorageViewScreen extends StatefulWidget {
  const SecureStorageViewScreen({super.key});

  @override
  State<SecureStorageViewScreen> createState() =>
      _SecureStorageViewScreenState();
}

class _SecureStorageViewScreenState extends State<SecureStorageViewScreen>
    with PrivacyScreen {
  Map<String, String> _keyValues = {};
  bool _isLoading = true;
  final Set<String> _expandedKeys = {};

  @override
  void initState() {
    super.initState();
    _loadSecureStorageData();
    enableScreenPrivacy();
  }

  @override
  void dispose() {
    disableScreenPrivacy();
    super.dispose();
  }

  Future<void> _loadSecureStorageData() async {
    try {
      final usecase = locator<GetAllSecureStorageValuesUsecase>();
      final data = await usecase();

      final sortedEntries =
          data.entries.toList()..sort((a, b) {
            final aIsSwap = a.key.startsWith('swap_');
            final bIsSwap = b.key.startsWith('swap_');

            if (aIsSwap && !bIsSwap) return 1;
            if (!aIsSwap && bIsSwap) return -1;
            return a.key.compareTo(b.key);
          });

      setState(() {
        _keyValues = Map.fromEntries(sortedEntries);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _toggleExpansion(String key) {
    setState(() {
      if (_expandedKeys.contains(key)) {
        _expandedKeys.remove(key);
      } else {
        _expandedKeys.add(key);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Secure Storage View')),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.errorContainer.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).colorScheme.error.withValues(alpha: 0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Theme.of(context).colorScheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'This page lists all the most sensitive keys in your application. Do not copy them or share them with anyone.',
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_keyValues.isEmpty)
                          const Text('No data found in secure storage.')
                        else
                          ..._keyValues.entries.map(
                            (entry) => _buildExpandableKeyValueCard(entry),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
    );
  }

  Widget _buildExpandableKeyValueCard(MapEntry<String, String> entry) {
    final isExpanded = _expandedKeys.contains(entry.key);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => _toggleExpansion(entry.key),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
              if (isExpanded) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  'Value:',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.value,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
