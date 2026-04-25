import 'package:flutter/material.dart';
import '../../../../core/database/database_helper.dart';

class TrainingDataScreen extends StatefulWidget {
  final Map<String, dynamic> material;

  const TrainingDataScreen({super.key, required this.material});

  @override
  State<TrainingDataScreen> createState() => _TrainingDataScreenState();
}

class _TrainingDataScreenState extends State<TrainingDataScreen> {
  List<Map<String, dynamic>> _chunks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadChunks();
  }

  Future<void> _loadChunks() async {
    setState(() => _isLoading = true);
    final materialId = widget.material[DatabaseHelper.columnId];
    final chunks = await DatabaseHelper.instance.getChunksForMaterial(materialId);
    setState(() {
      _chunks = chunks;
      _isLoading = false;
    });
  }

  Future<void> _deleteChunk(String chunkId) async {
    await DatabaseHelper.instance.deleteChunk(chunkId);
    _loadChunks();
  }

  Future<void> _deleteMaterial() async {
    final materialId = widget.material[DatabaseHelper.columnId];
    await DatabaseHelper.instance.deleteMaterial(materialId);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Training Data: ${widget.material[DatabaseHelper.columnFilename] ?? 'Unknown'}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_forever, color: Colors.red),
            tooltip: 'Delete Book',
            onPressed: () => _showDeleteMaterialConfirmation(),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _chunks.isEmpty
              ? const Center(child: Text('No training data available for this material.'))
              : ListView.separated(
                  itemCount: _chunks.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final chunk = _chunks[index];
                    return ListTile(
                      title: Text(
                        chunk[DatabaseHelper.columnContent] ?? '',
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text('Index: ${chunk[DatabaseHelper.columnChunkIndex]} • Type: ${chunk[DatabaseHelper.columnSourceType]}'),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _showDeleteConfirmation(chunk[DatabaseHelper.columnChunkId]),
                      ),
                      onTap: () {
                         showDialog(
                           context: context, 
                           builder: (context) => AlertDialog(
                              title: Text('Chunk ${chunk[DatabaseHelper.columnChunkIndex]}'),
                              content: SingleChildScrollView(
                                child: Text(chunk[DatabaseHelper.columnContent] ?? ''),
                              ),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))
                              ],
                           )
                         );
                      },
                    );
                  },
                ),
    );
  }

  void _showDeleteConfirmation(String chunkId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Chunk'),
        content: const Text('Are you sure you want to delete this training data chunk?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteChunk(chunkId);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showDeleteMaterialConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Book'),
        content: const Text('Are you sure you want to completely delete this book and all of its training data? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteMaterial();
            },
            child: const Text('Delete All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
