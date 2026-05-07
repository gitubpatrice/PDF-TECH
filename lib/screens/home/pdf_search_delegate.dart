import 'package:files_tech_core/files_tech_core.dart';
import 'package:flutter/material.dart';

/// Delegate de recherche utilisé via [showSearch] depuis le HomeScreen — filtre
/// la liste des PDFs récents par sous-chaîne (case-insensitive).
class PdfSearchDelegate extends SearchDelegate<void> {
  final List<RecentFile> files;
  final ValueChanged<String> onOpen;

  PdfSearchDelegate(this.files, this.onOpen);

  @override
  List<Widget> buildActions(BuildContext context) => [
    IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _buildList(context);

  @override
  Widget buildSuggestions(BuildContext context) => _buildList(context);

  Widget _buildList(BuildContext context) {
    final results = query.isEmpty
        ? files
        : files
              .where((f) => f.name.toLowerCase().contains(query.toLowerCase()))
              .toList();

    if (results.isEmpty) {
      return const Center(child: Text('Aucun résultat'));
    }
    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFC62828)),
        title: Text(results[i].name),
        onTap: () {
          close(context, null);
          onOpen(results[i].path);
        },
      ),
    );
  }
}
