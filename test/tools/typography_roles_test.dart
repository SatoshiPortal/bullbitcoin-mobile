import 'dart:io';

import 'package:test/test.dart';

void main() {
  test(
    'typography gate parses accesses and migration derives the projection',
    () async {
      final temp = Directory.systemTemp.createTempSync('typography-roles-');
      addTearDown(() => temp.deleteSync(recursive: true));
      final fixture = File('${temp.path}/fixture.dart');
      fixture.writeAsStringSync('''
import 'package:bull_ui/bull_ui.dart' show BullText;
import 'package:material_ui/material_ui.dart';
// context.font.bodyMedium is a comment.
const example = 'Theme.of(context).textTheme.bodyMedium';
/// [context.font] and [TextTheme.bodyLarge] are documentation.
void build(BuildContext context) {
  final theme = Theme.of(context);
  final text = theme.textTheme;
  print(text.bodyLarge);
  print(context
    .font
    .headlineSmall
    ?.copyWith(color: Colors.red));
  print(Theme.of(context).textTheme.bodyMedium!);
}
''');
      var root = Directory.current;
      while (!File('${root.path}/tools/typography_roles.dart').existsSync()) {
        if (root.parent.path == root.path) {
          throw StateError('Repository root not found');
        }
        root = root.parent;
      }
      Future<ProcessResult> run(List<String> args) => Process.run('fvm', [
        'dart',
        'tools/typography_roles.dart',
        ...args,
        fixture.path,
      ], workingDirectory: root.path);
      final rejected = await run([]);
      expect(rejected.exitCode, 1);
      expect(
        rejected.stderr,
        contains('read typography through context.bullType'),
      );
      final migrated = await run(['--write']);
      expect(migrated.exitCode, 0, reason: '${migrated.stderr}');
      final source = fixture.readAsStringSync();
      expect(source, contains('final text = context.bullType;'));
      expect(source, contains('show BullText, BullTypographyX;'));
      expect(
        source,
        contains('text.body.copyWith(fontWeight: FontWeight.w500)'),
      );
      expect(
        source,
        contains(
          'context.bullType.subtitle.copyWith(fontWeight: FontWeight.w400)',
        ),
      );
      expect(source, isNot(contains('?.copyWith')));
      expect(source, contains('print(context.bullType.body);'));
      expect(
        source,
        contains("const example = 'Theme.of(context).textTheme.bodyMedium';"),
      );
      final accepted = await run([]);
      expect(accepted.exitCode, 0, reason: '${accepted.stderr}');
      final again = await run(['--write']);
      expect(again.exitCode, 0, reason: '${again.stderr}');
      expect(fixture.readAsStringSync(), source);
      fixture.writeAsStringSync(
        'void f(dynamic alias) { print(alias.titleMedium); }',
      );
      expect((await run([])).exitCode, 1);
      expect((await run(['--write'])).exitCode, isNot(0));
      fixture.writeAsStringSync(
        'void f(dynamic context) { print(TextTheme.of(context)); }',
      );
      expect((await run([])).exitCode, 1);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
