import 'dart:io';

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:analyzer/dart/analysis/utilities.dart';

/// One-time migration and ongoing syntax gate for typography role consumers.
/// The migration table is read from BullTypography.toTextTheme, never duplicated.
void main(List<String> args) {
  final write = args.contains('--write');
  final paths = args.where((a) => !a.startsWith('--')).toList();
  final projection = File('packages/bull_ui/lib/src/theme/bull_typography.dart')
      .readAsStringSync();
  final mapping = <String, String>{};
  final unit = parseString(content: projection).unit;
  for (final declaration in unit.declarations.whereType<ClassDeclaration>()) {
    for (final method
        in declaration.body.members.whereType<MethodDeclaration>()) {
      if (method.name.lexeme != 'toTextTheme') continue;
      final body = method.body as ExpressionFunctionBody;
      final arguments = switch (body.expression) {
        InstanceCreationExpression(:final argumentList) => argumentList,
        MethodInvocation(:final argumentList) => argumentList,
        _ => throw StateError('Expected the TextTheme projection'),
      };
      for (final argument in arguments.arguments.whereType<NamedArgument>()) {
        mapping[argument.name.lexeme] = argument.argumentExpression.toSource();
      }
    }
  }
  if (mapping.length != 15) {
    throw StateError('Expected all 15 projection slots');
  }
  final files = <File>[];
  for (final path in paths.isEmpty ? ['lib', 'features', 'packages'] : paths) {
    final entity = FileSystemEntity.typeSync(path);
    if (entity == FileSystemEntityType.file) {
      files.add(File(path));
    } else {
      files.addAll(Directory(path).listSync(recursive: true).whereType<File>());
    }
  }
  files.sort((a, b) => a.path.compareTo(b.path));
  var changed = 0;
  var violations = 0;
  for (final file in files) {
    final path = file.path;
    if (!path.endsWith('.dart') ||
        path.contains('/test/') ||
        path.contains('/generated/') ||
        path.contains('/.dart_tool/') ||
        path.contains('/build/') ||
        path.endsWith('.g.dart') ||
        path.endsWith('.freezed.dart')) {
      continue;
    }
    final source = file.readAsStringSync();
    final ast = parseString(content: source, throwIfDiagnostics: false).unit;
    final visitor = _Migration(source, mapping, write);
    ast.accept(visitor);
    visitor.finish();
    if (!write) {
      for (final offset in visitor.violations) {
        final line = '\n'.allMatches(source.substring(0, offset)).length + 1;
        stderr.writeln(
          '$path:$line: read typography through context.bullType.<role>',
        );
        violations++;
      }
      continue;
    }
    if (visitor.edits.isEmpty &&
        !visitor.accesses.any((access) => access.$3 == 'bullType')) {
      continue;
    }
    var result = source;
    final edits = visitor.edits..sort((a, b) => b.start.compareTo(a.start));
    var boundary = source.length;
    for (final edit in edits) {
      if (edit.end > boundary) throw StateError('Overlapping edits in $path');
      result = result.replaceRange(edit.start, edit.end, edit.text);
      boundary = edit.start;
    }
    result = _withTypographyImport(result, path);
    if (result == source) continue;
    file.writeAsStringSync(result);
    stdout.writeln(path);
    changed++;
  }
  stdout.writeln(
    write
        ? 'Migrated $changed files'
        : 'Typography gate: $violations violations',
  );
  if (violations != 0) exitCode = 1;
}

String _withTypographyImport(String source, String path) {
  final imports = parseString(content: source).unit.directives
      .whereType<ImportDirective>();
  for (final directive in imports) {
    if (![
      'package:bull_ui/bull_ui.dart',
      'package:bull_ui/src/theme/bull_typography.dart',
    ].contains(directive.uri.stringValue)) {
      continue;
    }
    if (directive.combinators.isEmpty) return source;
    final shows = directive.combinators.whereType<ShowCombinator>().toList();
    if (shows.isNotEmpty) {
      var result = source;
      for (final show in shows.reversed) {
        if (!show.shownNames.any((name) => name.name == 'BullTypographyX')) {
          final end = show.shownNames.last.end;
          result = result.replaceRange(end, end, ', BullTypographyX');
        }
      }
      return result;
    }
  }
  final uri = path.startsWith('packages/bull_ui/lib/')
      ? 'package:bull_ui/src/theme/bull_typography.dart'
      : 'package:bull_ui/bull_ui.dart';
  return "import '$uri';\n$source";
}

class _Edit {
  final int start;
  final int end;
  final String text;
  _Edit(this.start, this.end, this.text);
}

class _Migration extends RecursiveAstVisitor<void> {
  final String source;
  final Map<String, String> mapping;
  final bool write;
  final edits = <_Edit>[];
  final violations = <int>{};
  final variables = <VariableDeclaration>[];
  final accesses = <(AstNode, Expression, String)>[];
  final themeContexts = <String, String>{};
  final roleAliases = <String, String>{};
  _Migration(this.source, this.mapping, this.write);

  @override
  void visitCommentReference(CommentReference node) {}

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if (!write &&
        node.methodName.name == 'of' &&
        (node.target?.toSource() == 'TextTheme' ||
            node.target?.toSource().endsWith('.TextTheme') == true)) {
      violations.add(node.offset);
    }
    super.visitMethodInvocation(node);
  }

  @override
  void visitVariableDeclaration(VariableDeclaration node) {
    variables.add(node);
    super.visitVariableDeclaration(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    final target = node.realTarget;
    accesses.add((node, target, node.propertyName.name));
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    accesses.add((node, node.prefix, node.identifier.name));
    super.visitPrefixedIdentifier(node);
  }

  String? contextOfTheme(String expression) {
    final direct = RegExp(r'^(?:\w+\.)?Theme\.of\((\w+)\)$')
        .firstMatch(expression);
    if (direct != null) return direct.group(1);
    final extension = RegExp(r'^(\w+)\.theme$').firstMatch(expression);
    return extension?.group(1) ?? themeContexts[expression];
  }

  String? rolesOf(String expression) {
    final extension = RegExp(r'^(\w+)\.(?:font|bullText)$')
        .firstMatch(expression);
    if (extension != null) return '${extension.group(1)}.bullType';
    if (expression.endsWith('.textTheme')) {
      final context = contextOfTheme(
        expression.substring(0, expression.length - 10),
      );
      if (context != null) return '$context.bullType';
    }
    return roleAliases[expression];
  }

  void finish() {
    for (final variable in variables) {
      final initializer = variable.initializer;
      if (initializer == null) continue;
      final context = contextOfTheme(initializer.toSource());
      if (context != null) themeContexts[variable.name.lexeme] = context;
    }
    for (final variable in variables) {
      final initializer = variable.initializer;
      if (initializer == null) continue;
      final roles = rolesOf(initializer.toSource());
      if (roles != null) {
        roleAliases[variable.name.lexeme] = variable.name.lexeme;
        if (write) edits.add(_Edit(initializer.offset, initializer.end, roles));
      }
    }
    for (final (node, target, name) in accesses) {
      if (mapping.containsKey(name)) {
        if (!write) {
          violations.add(node.offset);
          continue;
        }
        final roles = rolesOf(target.toSource());
        if (roles == null) {
          throw StateError('Unrecognized slot receiver: ${node.toSource()}');
        }
        var expression = '$roles.${mapping[name]}';
        if (source.contains("as m;")) {
          expression = expression.replaceAll('FontWeight.', 'm.FontWeight.');
        }
        var end = node.end;
        if (source.substring(end).startsWith('!')) end++;
        edits.add(_Edit(node.offset, end, expression));
        final nullable = RegExp(r'^\s*(\?)\.')
            .firstMatch(source.substring(end));
        if (nullable != null) {
          final offset = end + nullable.end - 2;
          edits.add(_Edit(offset, offset + 1, ''));
        }
      } else if (!write && ['textTheme', 'font', 'bullText'].contains(name)) {
        violations.add(node.offset);
      }
    }
  }
}
