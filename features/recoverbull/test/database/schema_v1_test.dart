import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('schema v1 is the committed RecoverBull migration baseline', () async {
    final packageFile = File(
      'lib/src/database/schemas/recoverbull_database/drift_schema_v1.json',
    );
    final workspaceFile = File('features/recoverbull/${packageFile.path}');
    final file = packageFile.existsSync() ? packageFile : workspaceFile;
    expect(await file.exists(), isTrue);

    final schema =
        jsonDecode(await file.readAsString()) as Map<String, Object?>;
    final options = schema['options']! as Map<String, Object?>;
    expect(options['store_date_time_values_as_text'], isTrue);

    final entities = schema['entities']! as List<Object?>;
    final tables = <String, Map<String, Object?>>{
      for (final entity in entities.cast<Map<String, Object?>>())
        if (entity['type'] == 'table')
          (entity['data']! as Map<String, Object?>)['name']! as String:
              entity['data']! as Map<String, Object?>,
    };
    expect(tables.keys, {'recoverbull_state', 'recoverbull_monitored_backup'});

    final stateColumns = (tables['recoverbull_state']!['columns']! as List)
        .cast<Map<String, Object?>>();
    final monitoringEnabled = stateColumns.singleWhere(
      (column) => column['name'] == 'attempt_monitoring_enabled',
    );
    expect(monitoringEnabled['default_dart'], "const CustomExpression('1')");
  });
}
