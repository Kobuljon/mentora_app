import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'import_materials_screen.dart';
import 'material_options_screen.dart';
import '../../../core/database/database_helper.dart';

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  List<Map<String, dynamic>> _materials = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMaterials();
  }

  Future<void> _loadMaterials() async {
    setState(() => _isLoading = true);
    final materials = await DatabaseHelper.instance.getAllMaterials();
    setState(() {
      _materials = materials;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Library')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _materials.isEmpty
          ? const Center(child: Text('Your Materials are empty. Add some!'))
          : ListView.builder(
              itemCount: _materials.length,
              itemBuilder: (context, index) {
                final material = _materials[index];
                final status =
                    material[DatabaseHelper.columnStatus] as String? ??
                    'processing';
                final isProcessing = status == 'processing';
                final type =
                    material[DatabaseHelper.columnType] as String? ?? 'unknown';

                IconData iconData = Icons.insert_drive_file;
                if (type == 'pdf')
                  iconData = Icons.picture_as_pdf;
                else if (type == 'docx')
                  iconData = Icons.description;
                else if (type == 'jpg' || type == 'png')
                  iconData = Icons.image;
                else if (['mp3', 'm4a', 'wav'].contains(type))
                  iconData = Icons.audio_file;

                return ListTile(
                  leading: Icon(iconData),
                  title: Text(
                    material[DatabaseHelper.columnFilename] ?? 'Unknown',
                  ),
                  subtitle: Text('Status: ${status.toUpperCase()}'),
                  trailing: isProcessing
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : status == 'failed'
                      ? const Icon(Icons.error, color: Colors.red)
                      : const Icon(Icons.check_circle, color: Colors.green),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            MaterialOptionsScreen(material: material),
                      ),
                    );
                    _loadMaterials();
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const ImportMaterialsScreen(),
            ),
          );
          _loadMaterials(); // Refresh when coming back
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
