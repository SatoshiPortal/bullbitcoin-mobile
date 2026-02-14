import 'dart:convert';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/build_context_x.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SeedRecoveryScreen extends StatefulWidget {
  const SeedRecoveryScreen({super.key});

  @override
  State<SeedRecoveryScreen> createState() => _SeedRecoveryScreenState();
}

class _SeedRecoveryScreenState extends State<SeedRecoveryScreen> {
  Map<String, String>? _recoveredSeeds;
  List<String> _seedKeys = [];
  int _currentSeedIndex = 0;
  bool _isLoading = true;
  String? _error;
  String _debugLog = '';

  @override
  void initState() {
    super.initState();
    _recoverSeeds();
  }

  Future<void> _recoverSeeds() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      print('DEBUG: Starting seed recovery');

      // Initialize FlutterSecureStorage with recovery mode enabled
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          recoveryMode: true,
          resetOnError: false,
        ),
      );

      print('DEBUG: FlutterSecureStorage initialized');

      // FORCE recovery mode - skip normal readAll to see comprehensive Java debug logging
      print('DEBUG: FORCING recovery mode (skipping normal readAll)');
      Map<String, String> seeds = {};

      print('DEBUG: Calling getAllSeeds with recovery mode');
      seeds = await secureStorage.getAllSeeds();
      print('DEBUG: getAllSeeds returned ${seeds.length} items');

      // Store debug log if available
      if (seeds.containsKey('__DEBUG_LOG__')) {
        _debugLog = seeds['__DEBUG_LOG__'] ?? '';
        print('=== RECOVERY DEBUG LOG ===');
        print(_debugLog);
        print('=== END DEBUG LOG ===');
      } else {
        _debugLog = 'No debug log available';
      }

      if (seeds.isEmpty || (seeds.length == 1 && seeds.containsKey('__DEBUG_LOG__'))) {
        setState(() {
          _error = 'No seeds found in storage.\n\nPress "View Debug Log" to see detailed recovery information.';
          _isLoading = false;
        });
        return;
      }

      // Parse seed JSON to extract mnemonic words
      final parsedSeeds = <String, String>{};
      final failedSeeds = <String>[];
      int totalSeedCount = 0;

      for (final entry in seeds.entries) {
        if (entry.key == '__DEBUG_LOG__') continue;
        if (!entry.key.startsWith('seed_')) continue;

        totalSeedCount++;
        print('DEBUG: ==========================================');
        print('DEBUG: Processing seed: ${entry.key}');
        print('DEBUG: Raw value type: ${entry.value.runtimeType}');
        print('DEBUG: Raw value length: ${entry.value.length}');
        print('DEBUG: First 100 chars: ${entry.value.substring(0, entry.value.length < 100 ? entry.value.length : 100)}');

        bool isValidMnemonic = false;

        try {
          // Try to parse as JSON (SeedModel format)
          print('DEBUG: Attempting JSON parse...');
          final jsonData = jsonDecode(entry.value);
          print('DEBUG: JSON parsed successfully, type: ${jsonData.runtimeType}');

          if (jsonData is Map) {
            print('DEBUG: JSON keys: ${jsonData.keys.toList()}');

            if (jsonData.containsKey('mnemonicWords')) {
              // Extract mnemonic words and join them
              final words = (jsonData['mnemonicWords'] as List).cast<String>();
              print('DEBUG: Found mnemonicWords array with ${words.length} words');
              print('DEBUG: First few words: ${words.take(3).join(" ")}...');

              if (words.length >= 12 && words.length <= 24) {
                parsedSeeds[entry.key] = words.join(' ');
                isValidMnemonic = true;
                print('DEBUG: ✓ Successfully extracted valid mnemonic (${words.length} words)');
              } else {
                print('DEBUG: ✗ Invalid word count: ${words.length} (expected 12-24)');
              }
            } else {
              print('DEBUG: ✗ JSON does not contain mnemonicWords key');
            }
          } else {
            print('DEBUG: ✗ Parsed JSON is not a Map, it is: ${jsonData.runtimeType}');
          }
        } catch (e) {
          print('DEBUG: ✗ JSON parsing failed: $e');

          // Check if it might be a raw mnemonic (space-separated words)
          final words = entry.value.trim().split(RegExp(r'\s+'));
          if (words.length >= 12 && words.length <= 24 && !entry.value.contains(RegExp(r'[^a-z\s]'))) {
            print('DEBUG: Looks like raw mnemonic with ${words.length} words');
            parsedSeeds[entry.key] = entry.value;
            isValidMnemonic = true;
            print('DEBUG: ✓ Treating as valid raw mnemonic');
          } else {
            print('DEBUG: ✗ Does not look like valid mnemonic format');
            print('DEBUG:   - Word count: ${words.length}');
            print('DEBUG:   - Contains non-letter chars: ${entry.value.contains(RegExp(r'[^a-z\s]'))}');
          }
        }

        if (!isValidMnemonic) {
          failedSeeds.add(entry.key);
          print('DEBUG: ✗ FAILED to extract valid mnemonic for ${entry.key}');
        }

        print('DEBUG: ==========================================');
      }

      print('DEBUG: FINAL SUMMARY:');
      print('DEBUG: Total seeds found: $totalSeedCount');
      print('DEBUG: Successfully parsed: ${parsedSeeds.length}');
      print('DEBUG: Failed to parse: ${failedSeeds.length}');
      if (failedSeeds.isNotEmpty) {
        print('DEBUG: Failed seed keys: ${failedSeeds.join(", ")}');
      }

      if (parsedSeeds.isEmpty) {
        final message = totalSeedCount > 0
            ? 'Found $totalSeedCount seed${totalSeedCount > 1 ? 's' : ''} but recovery failed.\n\nThe seed data could not be decrypted or parsed correctly.\n\nPress "View Debug Log" for detailed diagnostic information.'
            : 'No seed keys found (keys starting with "seed_").\n\nPress "View Debug Log" to see what was searched.';

        setState(() {
          _error = message;
          _isLoading = false;
        });
        return;
      }

      if (failedSeeds.isNotEmpty) {
        print('WARNING: Some seeds could not be recovered: ${failedSeeds.join(", ")}');
      }

      setState(() {
        _recoveredSeeds = parsedSeeds;
        _seedKeys = parsedSeeds.keys.toList();
        _currentSeedIndex = 0;
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      print('DEBUG: Error during recovery: $e');
      print('DEBUG: Stack trace: $stackTrace');
      setState(() {
        _error = 'Failed to recover seeds: $e';
        _isLoading = false;
      });
    }
  }

  void _nextSeed() {
    if (_currentSeedIndex < _seedKeys.length - 1) {
      setState(() {
        _currentSeedIndex++;
      });
    }
  }

  void _previousSeed() {
    if (_currentSeedIndex > 0) {
      setState(() {
        _currentSeedIndex--;
      });
    }
  }

  void _copySeed() {
    if (_recoveredSeeds != null && _currentSeedIndex < _seedKeys.length) {
      final currentKey = _seedKeys[_currentSeedIndex];
      final seedValue = _recoveredSeeds![currentKey];
      if (seedValue != null) {
        Clipboard.setData(ClipboardData(text: seedValue));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Seed copied to clipboard')),
        );
      }
    }
  }

  Future<void> _exportRawBackup() async {
    // Show warning dialog first
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Export Encrypted Backup',
          style: context.font.titleMedium,
        ),
        content: Text(
          'WARNING: This backup is STILL ENCRYPTED!\n\n'
          'The exported data cannot be used without the original encryption keys. '
          'This is a last-resort option to preserve your encrypted data for:\n\n'
          '• Future recovery if keys are ever recovered\n'
          '• Forensic analysis by security researchers\n\n'
          'Export anyway?',
          style: context.font.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Export'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      // Initialize FlutterSecureStorage with recovery mode
      const secureStorage = FlutterSecureStorage(
        aOptions: AndroidOptions(
          recoveryMode: true,
          resetOnError: false,
        ),
      );

      // Export raw encrypted backup
      final backup = await secureStorage.exportRawBackup();

      // Convert to JSON string
      final backupJson = const JsonEncoder.withIndent('  ').convert(backup);

      // Copy to clipboard
      await Clipboard.setData(ClipboardData(text: backupJson));

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Encrypted backup copied to clipboard'),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Export failed: $e'),
          backgroundColor: context.appColors.error,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showDebugLog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Recovery Debug Log',
          style: context.font.titleMedium,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              _debugLog,
              style: context.font.bodySmall?.copyWith(
                fontFamily: 'monospace',
                fontSize: 10,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _debugLog));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Debug log copied to clipboard')),
              );
            },
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSeedWordsDisplay(String seedPhrase) {
    final words = seedPhrase.trim().split(RegExp(r'\s+'));

    if (words.isEmpty) {
      return Text(
        'No words found',
        style: context.font.bodyMedium?.copyWith(
          color: context.appColors.error,
        ),
      );
    }

    // Split into 2 columns
    final splitIndex = (words.length / 2).ceil();
    final leftWords = words.sublist(0, splitIndex);
    final rightWords = words.sublist(splitIndex);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: List.generate(
              leftWords.length,
              (i) => _buildWordItem(i + 1, leftWords[i]),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: List.generate(
              rightWords.length,
              (i) => _buildWordItem(i + splitIndex + 1, rightWords[i]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWordItem(int index, String word) {
    final displayIndex = index < 10 ? '0$index' : '$index';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: context.appColors.border),
        color: context.appColors.surface,
      ),
      height: 41,
      child: Row(
        children: [
          Container(
            height: 34,
            width: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.appColors.success,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              displayIndex,
              style: context.font.headlineMedium?.copyWith(
                color: context.appColors.surface,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              word,
              style: context.font.bodyMedium?.copyWith(
                color: context.appColors.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recovery Mode'),
        backgroundColor: context.appColors.error,
        foregroundColor: context.appColors.onError,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(
                      color: context.appColors.primary,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Attempting to recover seeds...',
                      style: context.font.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Trying all algorithm combinations',
                      style: context.font.bodySmall?.copyWith(
                        color: context.appColors.onSurface.withOpacity(0.6),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              : _error != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: context.appColors.error,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Recovery Failed',
                          style: context.font.headlineSmall?.copyWith(
                            color: context.appColors.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _error!,
                          style: context.font.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        BBButton.big(
                          onPressed: _exportRawBackup,
                          label: 'Export Encrypted Backup',
                          bgColor: context.appColors.error.withOpacity(0.2),
                          textColor: context.appColors.error,
                        ),
                        const SizedBox(height: 16),
                        BBButton.big(
                          onPressed: _showDebugLog,
                          label: 'View Debug Log',
                          bgColor: context.appColors.surface,
                          textColor: context.appColors.onSurface,
                        ),
                        const SizedBox(height: 16),
                        BBButton.big(
                          onPressed: () => Navigator.of(context).pop(),
                          label: 'Back',
                          bgColor: context.appColors.primary,
                          textColor: context.appColors.onPrimary,
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: context.appColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'Seed ${_currentSeedIndex + 1} of ${_seedKeys.length}',
                                style: context.font.titleMedium?.copyWith(
                                  color: context.appColors.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                _seedKeys[_currentSeedIndex],
                                style: context.font.bodySmall?.copyWith(
                                  color: context.appColors.onSurface
                                      .withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSeedWordsDisplay(
                          _recoveredSeeds![_seedKeys[_currentSeedIndex]] ??
                              '[Error: Seed value not found]',
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            if (_currentSeedIndex > 0)
                              Expanded(
                                child: BBButton.big(
                                  onPressed: _previousSeed,
                                  label: 'Previous',
                                  bgColor: context.appColors.surface,
                                  textColor: context.appColors.onSurface,
                                ),
                              ),
                            if (_currentSeedIndex > 0 &&
                                _currentSeedIndex < _seedKeys.length - 1)
                              const SizedBox(width: 16),
                            if (_currentSeedIndex < _seedKeys.length - 1)
                              Expanded(
                                child: BBButton.big(
                                  onPressed: _nextSeed,
                                  label: 'Next',
                                  bgColor: context.appColors.primary,
                                  textColor: context.appColors.onPrimary,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 32),
                        BBButton.big(
                          onPressed: _showDebugLog,
                          label: 'View Debug Log',
                          bgColor: context.appColors.surface,
                          textColor: context.appColors.onSurface,
                        ),
                        const SizedBox(height: 16),
                        BBButton.big(
                          onPressed: () => Navigator.of(context).pop(),
                          label: 'DONE',
                          bgColor: context.appColors.secondary,
                          textColor: context.appColors.onSecondary,
                        ),
                      ],
                    ),
        ),
      ),
    );
  }
}
