# Label Editor

`package:label_editor/label_editor.dart` provides typed navigation for private labels, counterparty-visible notes and BIP-329 label management.

```dart
final note = await LabelEditor.note(context, title: title, initialValue: draft);
final label = await LabelEditor.label(context, title: title);
final validationMessage = LabelEditor.validateNote(context, draft);
await LabelEditor.open(context);
```

The editor sheets return the saved, trimmed value or `null` on dismissal. An inline note field can render the localized message from `validateNote`, which returns `null` for valid input.

App composition mounts `LabelEditorFeature` from `package:label_editor/setup.dart` and adds its routes to the router.
