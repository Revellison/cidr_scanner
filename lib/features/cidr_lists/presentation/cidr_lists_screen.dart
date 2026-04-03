import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../scanner/application/providers.dart';

class CidrListsScreen extends ConsumerStatefulWidget {
  const CidrListsScreen({super.key, this.embedded = false});

  final bool embedded;

  @override
  ConsumerState<CidrListsScreen> createState() => _CidrListsScreenState();
}

class _CidrListsScreenState extends ConsumerState<CidrListsScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _cidrController;
  String? _editingListId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _cidrController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cidrController.dispose();
    super.dispose();
  }

  Future<void> _importFromFile() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'CIDR files', extensions: ['txt', 'cidr']),
        ],
      );

      if (file == null) {
        return;
      }

      final fileContent = await file.readAsString();
      final lines = fileContent
          .split(RegExp(r'\r?\n'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();

      if (lines.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File contains no CIDR entries')),
        );
        return;
      }

      setState(() {
        final baseName = file.name.replaceAll(
          RegExp(r'\.(txt|cidr)$', caseSensitive: false),
          '',
        );
        _nameController.text = '$baseName (imported)';
        _cidrController.text = lines.join('\n');
        _editingListId = null;
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Imported ${lines.length} CIDR entries')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Import error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);

    final content = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      child: Column(
        children: [
          _CardBlock(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Create / Edit List',
                  style: TextStyle(color: Colors.white, fontSize: 14),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('List name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _cidrController,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                  minLines: 6,
                  maxLines: 10,
                  decoration: _inputDecoration('CIDR, one per line'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          final wasEditing = _editingListId != null;
                          if (_editingListId == null) {
                            await controller.createList(
                              name: _nameController.text,
                              rawCidrText: _cidrController.text,
                            );
                          } else {
                            await controller.updateList(
                              id: _editingListId!,
                              name: _nameController.text,
                              rawCidrText: _cidrController.text,
                            );
                          }
                          if (!mounted) return;
                          if (ref.read(scanControllerProvider).errorMessage ==
                              null) {
                            _nameController.clear();
                            _cidrController.clear();
                            setState(() {
                              _editingListId = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  wasEditing
                                      ? 'CIDR list updated'
                                      : 'CIDR list saved',
                                ),
                              ),
                            );
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _editingListId == null ? 'Save List' : 'Update List',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _importFromFile,
                        icon: const Icon(Icons.upload_file),
                        label: const Text('Import'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4A4A4A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_editingListId != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          _editingListId = null;
                          _nameController.clear();
                          _cidrController.clear();
                        });
                      },
                      child: const Text(
                        'Cancel edit',
                        style: TextStyle(color: Color(0xFFAAAAAA)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _CardBlock(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Saved Lists',
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: state.availableLists.isEmpty
                        ? const Center(
                            child: Text(
                              'No CIDR lists yet',
                              style: TextStyle(color: Color(0xFFAAAAAA)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: state.availableLists.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = state.availableLists[index];
                              final isActive = item.id == state.activeListId;
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF090909),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isActive
                                        ? Colors.white
                                        : const Color(0xFF1D1D1D),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '${item.cidrs.length} ranges',
                                            style: const TextStyle(
                                              color: Color(0xFFB0B0B0),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        controller.selectList(item.id);
                                      },
                                      child: const Text(
                                        'Use',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _editingListId = item.id;
                                          _nameController.text = item.name;
                                          _cidrController.text = item.cidrs
                                              .join('\n');
                                        });
                                      },
                                      child: const Text(
                                        'Edit',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: () async {
                                        await controller.deleteList(item.id);
                                        if (_editingListId == item.id) {
                                          setState(() {
                                            _editingListId = null;
                                            _nameController.clear();
                                            _cidrController.clear();
                                          });
                                        }
                                      },
                                      icon: const Icon(Icons.delete_outline),
                                      color: const Color(0xFF8B3A3A),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
          if (state.errorMessage != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                state.errorMessage!,
                style: const TextStyle(color: Color(0xFFCC6666)),
              ),
            ),
          ],
        ],
      ),
    );

    if (widget.embedded) {
      return ColoredBox(color: Colors.black, child: content);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('CIDR Lists', style: TextStyle(color: Colors.white)),
      ),
      body: content,
    );
  }

  static InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF333333)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white),
      ),
    );
  }
}

class _CardBlock extends StatelessWidget {
  const _CardBlock({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        border: Border.all(color: const Color(0xFF1D1D1D)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}
