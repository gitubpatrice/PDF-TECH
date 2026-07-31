import 'package:flutter/material.dart';

import '../services/form_field_analyzer.dart';

/// Liste scrollable des champs de formulaire détectés.
class FormFieldList extends StatelessWidget {
  final List<FormFieldInfo> fields;

  const FormFieldList({super.key, required this.fields});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 100),
      itemCount: fields.length,
      itemBuilder: (_, i) {
        final f = fields[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 5),
          child: ListTile(
            dense: true,
            leading: Icon(
              f.icon,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
            title: Text(
              f.name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(f.type, style: const TextStyle(fontSize: 11)),
            trailing: Text(
              f.value,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        );
      },
    );
  }
}
