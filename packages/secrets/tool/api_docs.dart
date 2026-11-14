import 'dart:io';

import 'package:analyzer/dart/analysis/analysis_context_collection.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';

import 'key_material_gate.dart' show dartSdkPath;

const apiDocsStart = '<!-- secrets-api:start -->';
const apiDocsEnd = '<!-- secrets-api:end -->';

/// Regenerates the two call trees from the canonical public export namespace.
Future<void> main(List<String> arguments) async {
  if (arguments.any((argument) => argument != '--check')) {
    stderr.writeln(
      'Usage: fvm dart packages/secrets/tool/api_docs.dart [--check]',
    );
    exitCode = 64;
    return;
  }
  final package = File.fromUri(Platform.script).parent.parent;
  final check = arguments.contains('--check');
  final trees = await generateApiTrees(
    libraryPath: '${package.path}/lib/secrets.dart',
    sdkPath: dartSdkPath(package.path),
  );
  final current = updateApiReadme(
    File('${package.path}/README.md'),
    trees,
    check: check,
  );
  if (check && !current) {
    stderr.writeln('Public API trees are stale. Run make secrets-api-docs.');
    exitCode = 1;
    return;
  }
  stdout.writeln(
    current ? 'Public API trees are current.' : 'Updated public API trees.',
  );
}

/// Returns whether the file was already current; check mode never writes it.
bool updateApiReadme(
  File readme,
  String trees, {
  required bool check,
  String marker = 'secrets-api',
}) {
  final before = readme.readAsStringSync();
  final after = replaceApiTrees(before, trees, marker: marker);
  if (before == after) return true;
  if (!check) readme.writeAsStringSync(after);
  return false;
}

String replaceApiTrees(
  String markdown,
  String trees, {
  String marker = 'secrets-api',
}) {
  final open = '<!-- $marker:start -->';
  final close = '<!-- $marker:end -->';
  final start = markdown.indexOf(open);
  final end = markdown.indexOf(close);
  if (start < 0 ||
      end < start ||
      markdown.indexOf(open, start + open.length) >= 0 ||
      markdown.indexOf(close, end + close.length) >= 0) {
    throw StateError('README must contain one ordered pair of API markers.');
  }
  return markdown.replaceRange(start + open.length, end, '\n\n$trees\n\n');
}

/// [failure] is the failure type whose `Future<Result<T, failure>>` reads as
/// `T`; [statics] lists the roots whose static members are entry points.
Future<String> generateApiTrees({
  required String libraryPath,
  required String sdkPath,
  List<String> roots = const ['Secrets', 'Secret'],
  String failure = 'SecretFailure',
  String target = 'secrets-api-docs',
  Set<String> statics = const {},
}) async {
  final path = File(libraryPath).resolveSymbolicLinksSync();
  final collection = AnalysisContextCollection(
    includedPaths: [File(path).parent.path],
    sdkPath: sdkPath,
  );
  try {
    final session = collection.contextFor(path).currentSession;
    final result = await session.getResolvedLibrary(path);
    if (result is! ResolvedLibraryResult) {
      throw StateError('Cannot resolve the public API library.');
    }
    final exported = result.element.exportNamespace.definedNames2;
    // Resolve the export closure too: a broken source must never publish a
    // plausible diagram containing recovered dynamic/invalid types.
    final visited = <LibraryElement>{};
    Future<void> validate(LibraryElement library) async {
      if (!visited.add(library) || library.isInSdk) return;
      final resolved = await session.getResolvedLibrary(
        library.firstFragment.source.fullName,
      );
      if (resolved is! ResolvedLibraryResult) {
        throw StateError('Cannot resolve ${library.uri}.');
      }
      for (final unit in resolved.units) {
        final errors = unit.diagnostics.where(
          (diagnostic) => diagnostic.diagnosticCode.severity.name == 'ERROR',
        );
        if (errors.isNotEmpty) {
          throw StateError(
            '${library.uri}: ${errors.map((error) => error.diagnosticCode.lowerCaseName).join(', ')}',
          );
        }
      }
      for (final fragment in library.fragments) {
        for (final export in fragment.libraryExports) {
          final target = export.exportedLibrary;
          if (target != null) await validate(target);
        }
      }
    }

    await validate(result.element);
    final renderer = _ApiRenderer(exported, roots, failure, statics);
    final library = 'lib/${File(path).uri.pathSegments.last}';
    return [
      'Generated from `$library`; update with `make $target`.',
      '',
      'Each asynchronous `Future<Result<T, $failure>>` is shown as `T`. Other returns are unchanged. `name:` denotes a required named argument; brackets denote optional arguments and show explicit defaults. Constructors, ${statics.isEmpty ? 'static members, ' : 'static members other than the entry points marked `static`, '}Object methods and internal members are omitted. Synchronous capability groups are expanded; data and widget values remain leaves.',
      for (final root in roots) ...[
        '',
        '```text',
        renderer.render(root),
        '```',
      ],
    ].join('\n');
  } finally {
    await collection.dispose();
  }
}

class _ApiRenderer {
  final Map<String, Element> exported;
  final List<String> roots;
  final String failure;
  final Set<String> statics;

  _ApiRenderer(this.exported, this.roots, this.failure, this.statics);

  String render(String name) {
    final root = exported[name];
    if (root is! InterfaceElement || !_visible(root)) {
      throw StateError('Public root $name is missing.');
    }
    final output = StringBuffer(name);
    _append(output, root.thisType, '', {root});
    return output.toString();
  }

  void _append(
    StringBuffer output,
    InterfaceType type,
    String prefix,
    Set<InterfaceElement> ancestors,
  ) {
    final members = _members(type);
    for (var i = 0; i < members.length; i++) {
      final member = members[i];
      final last = i == members.length - 1;
      final returnType = member.returnType;
      final branch =
          returnType is InterfaceType &&
          !ancestors.contains(returnType.element) &&
          _isCapability(returnType);
      final parameters = member is GetterElement
          ? ''
          : '(${member.formalParameters.map(_parameter).join(', ')})';
      final static = member.isStatic ? 'static ' : '';
      output.write(
        '\n$prefix${last ? '`--' : '|--'} $static${member.displayName}$parameters',
      );
      if (branch) {
        _append(output, returnType, '$prefix${last ? '    ' : '|   '}', {
          ...ancestors,
          returnType.element,
        });
      } else {
        output.write(' -> ${_returnType(returnType, exported, failure)}');
      }
    }
  }

  bool _isCapability(
    InterfaceType type, [
    Set<InterfaceElement> ancestors = const {},
  ]) {
    final element = type.element;
    if (!exported.containsValue(element) ||
        roots.contains(element.name) ||
        ancestors.contains(element)) {
      return false;
    }
    if (element is! ExtensionTypeElement) {
      // A value with a public constructor is a leaf. Framework objects also
      // stay leaves even when their package constructor is marked internal.
      if (element.constructors.any(_visible) ||
          element.allSupertypes.any(
            (parent) =>
                !parent.isDartCoreObject &&
                !exported.containsValue(parent.element),
          )) {
        return false;
      }
    }
    return _members(type).any((member) {
      if (member is MethodElement) return true;
      final child = member.returnType;
      return child is InterfaceType &&
          _isCapability(child, {...ancestors, element});
    });
  }

  List<ExecutableElement> _members(InterfaceType type) {
    final members = <String, ExecutableElement>{};
    void add(InstanceElement owner) {
      final candidates =
          <ExecutableElement>[
            ...owner.getters,
            ...owner.methods,
            ...owner.setters,
          ]..sort(
            (a, b) => (a.firstFragment.nameOffset ?? -1).compareTo(
              b.firstFragment.nameOffset ?? -1,
            ),
          );
      for (final member in candidates) {
        if ((member.isStatic &&
                !(statics.contains(type.element.name) &&
                    member is MethodElement)) ||
            !_visible(member) ||
            _objectMembers.contains(member.displayName)) {
          continue;
        }
        final actual = owner is ExtensionElement
            ? member
            : switch (member) {
                GetterElement() =>
                  type.lookUpGetter(member.name!, type.element.library) ??
                      member,
                SetterElement() =>
                  type.lookUpSetter(member.name!, type.element.library) ??
                      member,
                _ =>
                  type.lookUpMethod(member.name!, type.element.library) ??
                      member,
              };
        members.putIfAbsent(actual.displayName, () => actual);
      }
    }

    add(type.element);
    for (final parent in type.allSupertypes) {
      if (exported.containsValue(parent.element)) add(parent.element);
    }
    for (final extension in exported.values.whereType<ExtensionElement>()) {
      if (_visible(extension) &&
          extension.library.typeSystem.isSubtypeOf(
            type,
            extension.extendedType,
          )) {
        add(extension);
      }
    }
    return members.values.toList();
  }
}

const _objectMembers = {
  'toString',
  'hashCode',
  'runtimeType',
  'noSuchMethod',
  '==',
};

bool _visible(Element element) =>
    element.isPublic &&
    !element.metadata.hasInternal &&
    !element.nonSynthetic.metadata.hasInternal;

String _parameter(FormalParameterElement parameter) {
  var text = '${parameter.name}${parameter.isNamed ? ':' : ''}';
  if (parameter.hasDefaultValue) {
    text += '${parameter.isNamed ? ' ' : ' = '}${parameter.defaultValueCode}';
  }
  return parameter.isOptional ? '[$text]' : text;
}

String _returnType(
  DartType type,
  Map<String, Element> exported,
  String failure,
) {
  if (type is InterfaceType && type.isDartAsyncFuture) {
    final result = type.typeArguments.single;
    if (result is InterfaceType &&
        result.element.name == 'Result' &&
        result.typeArguments.length == 2 &&
        result.typeArguments.last.element?.name == failure) {
      type = result.typeArguments.first;
    }
  }
  final alias = type.alias;
  if (alias != null && exported.containsValue(alias.element)) {
    final arguments = alias.typeArguments.isEmpty
        ? ''
        : '<${alias.typeArguments.map((type) => type.getDisplayString()).join(', ')}>';
    final nullable = type.nullabilitySuffix == NullabilitySuffix.question
        ? '?'
        : '';
    return '${alias.element.displayName}$arguments$nullable';
  }
  return type.getDisplayString();
}
