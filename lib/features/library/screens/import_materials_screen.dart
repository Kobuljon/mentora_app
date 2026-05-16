import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/material_processor_service.dart';

class ImportMaterialsScreen extends ConsumerStatefulWidget {
  const ImportMaterialsScreen({super.key});

  @override
  ConsumerState<ImportMaterialsScreen> createState() =>
      _ImportMaterialsScreenState();
}

class _ImportMaterialsScreenState extends ConsumerState<ImportMaterialsScreen> {
  bool _isImporting = false;
  String _importStatus = '';
  double _importProgress = 0.0;

  Future<void> _pickAndProcessFile() async {
    if (_isImporting) return;

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'mp3', 'm4a', 'wav', 'jpg', 'png'],
    );

    if (!mounted || result == null) return;
    final picked = result.files.single;
    final pickedPath = picked.path;
    if (pickedPath == null || pickedPath.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Could not read the selected file path. Try another file.',
          ),
        ),
      );
      return;
    }

    final displayName = await _askForMaterialName(picked.name);
    if (displayName == null || !mounted) return;

    // Let the dialog route and IME teardown finish before mutating this page.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    setState(() {
      _isImporting = true;
      _importStatus = 'Preparing $displayName...';
      _importProgress = 0.1;
    });

    var importSucceeded = false;
    try {
      await MaterialProcessorService.instance.processFile(
        pickedPath,
        displayName: displayName,
        onProgress: (status, progress) {
          if (!mounted) return;
          setState(() {
            _importStatus = status;
            _importProgress = progress;
          });
        },
      );
      importSucceeded = true;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import failed: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isImporting = false;
        });
      }
    }

    if (importSucceeded && mounted) {
      setState(() {
        _importStatus = 'Import complete';
        _importProgress = 1.0;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Materials imported successfully')),
      );
      Navigator.pop(context);
    }
  }

  Future<String?> _askForMaterialName(String filename) async {
    final defaultName = filename.replaceFirst(RegExp(r'\.[^.]+$'), '');
    final controller = TextEditingController(text: defaultName);
    final formKey = GlobalKey<FormState>();

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Name this material'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: controller,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: 'Material name',
                helperText: filename,
                border: const OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter a name';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                Navigator.pop(dialogContext, controller.text.trim());
              },
              child: const Text('Import'),
            ),
          ],
        );
      },
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      controller.dispose();
    });
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Material')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: _isImporting
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    Text(_importStatus, textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(value: _importProgress),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_upload_outlined, size: 80),
                    const SizedBox(height: 20),
                    const Text(
                      'Select files to import\n(PDF, DOCX, Audio, Image)',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18),
                    ),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 15,
                        ),
                      ),
                      onPressed: _pickAndProcessFile,
                      child: const Text(
                        'Browse Files',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
