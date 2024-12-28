import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';

class DeviceFilesPage extends StatefulWidget {
  const DeviceFilesPage({super.key});

  @override
  State<DeviceFilesPage> createState() => _DeviceFilesPageState();
}

class _DeviceFilesPageState extends State<DeviceFilesPage> {
  List<FileSystemEntity> files = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadExcelFiles();
  }

  Future<void> loadExcelFiles() async {
    setState(() {
      isLoading = true;
    });

    try {
      Directory directory = Directory('/storage/emulated/0/Download');
      if (await directory.exists()) {
        List<FileSystemEntity> allFiles = directory.listSync();
        // Filter only Excel files
        files = allFiles
            .where((file) => file.path.toLowerCase().endsWith('.xlsx'))
            .toList();

        // Sort files by modification time, most recent first
        files.sort(
            (a, b) => b.statSync().modified.compareTo(a.statSync().modified));
      }
    } catch (e) {
      debugPrint('Error loading files: $e');
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> deleteFile(File file) async {
    try {
      await file.delete();
      loadExcelFiles(); // Reload the list
    } catch (e) {
      debugPrint('Error deleting file: $e');
    }
  }

  String getFileSize(File file) {
    int bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generated Excel Files'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: loadExcelFiles,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : files.isEmpty
              ? const Center(
                  child: Text(
                    'No Excel files found',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : ListView.builder(
                  itemCount: files.length,
                  itemBuilder: (context, index) {
                    File file = File(files[index].path);
                    String fileName = file.path.split('/').last;
                    String fileSize = getFileSize(file);
                    String modifiedDate = DateFormat('MMM dd, yyyy HH:mm')
                        .format(file.statSync().modified);

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: ListTile(
                        leading: const Icon(
                          Icons.table_chart,
                          color: Colors.green,
                          size: 40,
                        ),
                        title: Text(
                          fileName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Size: $fileSize'),
                            Text('Modified: $modifiedDate'),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'open',
                              child: Row(
                                children: [
                                  Icon(Icons.open_in_new),
                                  SizedBox(width: 8),
                                  Text('Open'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Delete'),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'open') {
                              await OpenFile.open(file.path);
                            } else if (value == 'delete') {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete File'),
                                  content: Text(
                                      'Are you sure you want to delete $fileName?'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        deleteFile(file);
                                      },
                                      child: const Text(
                                        'Delete',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }
                          },
                        ),
                        onTap: () => OpenFile.open(file.path),
                      ),
                    );
                  },
                ),
    );
  }
}
