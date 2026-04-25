import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/material_processor_service.dart';
import '../../chat/services/ai_chat_service.dart';

class ImportMaterialsScreen extends StatefulWidget {
  const ImportMaterialsScreen({super.key});

  @override
  State<ImportMaterialsScreen> createState() => _ImportMaterialsScreenState();
}

class _ImportMaterialsScreenState extends State<ImportMaterialsScreen> {
  bool _isImporting = false;
  String _importStatus = '';
  double _importProgress = 0.0;

  Future<void> _pickAndProcessFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'mp3', 'm4a', 'wav', 'jpg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      final file = result.files.single;
      setState(() {
        _isImporting = true;
        _importStatus = 'Preparing ${file.name}...';
        _importProgress = 0.1;
      });

      // Initialize AI just for this processing step to avoid state pollution
      final aiService = AiChatService();
      try {
        await aiService.initialize();
        setState(() {
          _importStatus = 'Extracting and cleaning text...';
        });
        await MaterialProcessorService.instance.processFile(
          file.path!,
          aiService,
          onProgress: (status, progress) {
            if (mounted) {
              setState(() {
                _importStatus = status;
                _importProgress = progress;
              });
            }
          },
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      } finally {
        await aiService.dispose();
      }

      if (mounted) {
        setState(() {
          _isImporting = false;
          _importStatus = 'Import complete';
          _importProgress = 1.0;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Materials imported successfully')),
        );
        Navigator.pop(context);
      }
    }
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
