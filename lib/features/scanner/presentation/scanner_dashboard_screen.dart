import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../cidr_lists/domain/cidr_list.dart';
import '../../cidr_lists/presentation/cidr_lists_screen.dart';
import '../application/providers.dart';
import '../application/scan_controller.dart';
import '../domain/ping_method.dart';
import '../domain/scan_history_entry.dart';
import '../domain/scan_result.dart';
import '../domain/scan_session.dart';
import '../domain/scan_target_mode.dart';

class ScannerDashboardScreen extends ConsumerStatefulWidget {
  const ScannerDashboardScreen({super.key});

  @override
  ConsumerState<ScannerDashboardScreen> createState() =>
      _ScannerDashboardScreenState();
}

class _ScannerDashboardScreenState
    extends ConsumerState<ScannerDashboardScreen> {
  late final TextEditingController _portController;
  late final TextEditingController _singleTargetController;

  @override
  void initState() {
    super.initState();
    _portController = TextEditingController();
    _singleTargetController = TextEditingController();
  }

  @override
  void dispose() {
    _portController.dispose();
    _singleTargetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanControllerProvider);
    final controller = ref.read(scanControllerProvider.notifier);
    final settings = state.settings;
    final hasRunningTask = state.currentTasks.any(
      (task) => task.status == ScanSessionStatus.running,
    );

    final effectivePortText = settings.targetPort?.toString() ?? '';
    if (_portController.text != effectivePortText) {
      _portController.value = TextEditingValue(
        text: effectivePortText,
        selection: TextSelection.collapsed(offset: effectivePortText.length),
      );
    }

    if (_singleTargetController.text != state.singleTargetText) {
      _singleTargetController.value = TextEditingValue(
        text: state.singleTargetText,
        selection: TextSelection.collapsed(
          offset: state.singleTargetText.length,
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          title: const Text(
            'CIDR Scanner',
            style: TextStyle(color: Colors.white),
          ),
          actions: [
            IconButton(
              onPressed: () async {
                await _openCurrentTasksSheet(
                  context,
                  controller,
                  state.currentTasks,
                );
              },
              icon: const Icon(Icons.task_alt_outlined),
              color: Colors.white,
              tooltip: 'Current tasks',
            ),
            IconButton(
              onPressed: () async {
                await Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const CidrListsScreen(),
                  ),
                );
                if (!mounted) {
                  return;
                }
                await controller.refreshLists();
              },
              icon: const Icon(Icons.playlist_add_check_circle_outlined),
              color: Colors.white,
              tooltip: 'Manage CIDR lists',
            ),
            IconButton(
              onPressed: hasRunningTask ? null : controller.refreshLists,
              icon: const Icon(Icons.refresh),
              color: Colors.white,
              tooltip: 'Refresh lists',
            ),
          ],
        ),
        body: Container(
          color: Colors.black,
          padding: const EdgeInsets.all(16),
          child: TabBarView(
            children: [
              _ScanTab(
                state: state,
                controller: controller,
                portController: _portController,
                singleTargetController: _singleTargetController,
                onStartScan: () async {
                  final sessionId = await controller.startScan();
                  if (!context.mounted || sessionId == null) {
                    return;
                  }
                  await _openSessionDialog(context, sessionId);
                },
              ),
              _CurrentTasksTab(
                tasks: state.currentTasks,
                onOpen: (session) => _openSessionDialog(context, session.id),
                onDismiss: controller.dismissTask,
              ),
              _HistoryTab(
                entries: state.scanHistory,
                onOpen: (entry) => _openHistoryDialog(context, entry),
                onDelete: controller.removeHistoryEntry,
              ),
            ],
          ),
        ),
        bottomNavigationBar: const TabBar(
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Color(0xFF999999),
          tabs: [
            Tab(text: 'Scan'),
            Tab(text: 'Current Tasks'),
            Tab(text: 'History'),
          ],
        ),
      ),
    );
  }

  Future<void> _openSessionDialog(BuildContext context, String sessionId) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Scan session',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _SessionDialog(sessionId: sessionId),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scale = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: scale,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }

  Future<void> _openCurrentTasksSheet(
    BuildContext context,
    ScanController controller,
    List<ScanSession> tasks,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.black,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Current Tasks',
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
                const SizedBox(height: 12),
                if (tasks.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        'No current tasks',
                        style: TextStyle(color: Color(0xFFAAAAAA)),
                      ),
                    ),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 420),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: tasks.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final task = tasks[index];
                        return _TaskCard(
                          task: task,
                          onOpen: () {
                            Navigator.of(sheetContext).pop();
                            _openSessionDialog(context, task.id);
                          },
                          onDismiss: () => controller.dismissTask(task.id),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openHistoryDialog(
    BuildContext context,
    ScanHistoryEntry entry,
  ) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'History details',
      barrierColor: Colors.black.withValues(alpha: 0.85),
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, __, ___) => _HistoryDetailsDialog(entry: entry),
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final scale = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        );
        return ScaleTransition(
          scale: scale,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
    );
  }
}

int _defaultPort(PingMethod method) {
  switch (method) {
    case PingMethod.icmp:
      return 0;
    case PingMethod.tcp:
    case PingMethod.http:
      return 80;
    case PingMethod.udp:
      return 53;
  }
}

InputDecoration fieldDecoration({required String label}) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Color(0xFFB0B0B0)),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF3A3A3A)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Color(0xFF222222)),
    ),
  );
}

class _ScanTab extends StatelessWidget {
  const _ScanTab({
    required this.state,
    required this.controller,
    required this.portController,
    required this.singleTargetController,
    required this.onStartScan,
  });

  final dynamic state;
  final dynamic controller;
  final TextEditingController portController;
  final TextEditingController singleTargetController;
  final Future<void> Function() onStartScan;

  @override
  Widget build(BuildContext context) {
    final settings = state.settings;

    return SingleChildScrollView(
      child: Column(
        children: [
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scan Target',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(height: 12),
                ToggleButtons(
                  isSelected: [
                    state.targetMode == ScanTargetMode.list,
                    state.targetMode == ScanTargetMode.single,
                  ],
                  onPressed: (index) {
                    controller.setTargetMode(
                      index == 0 ? ScanTargetMode.list : ScanTargetMode.single,
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  fillColor: Colors.white,
                  color: Colors.white,
                  selectedColor: Colors.black,
                  borderColor: const Color(0xFF333333),
                  selectedBorderColor: Colors.white,
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('List'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: Text('Single'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (state.targetMode == ScanTargetMode.list) ...[
                  _ListSelector(
                    lists: state.availableLists,
                    activeListId: state.activeListId,
                    onChanged: (value) {
                      if (value != null) {
                        controller.selectList(value);
                      }
                    },
                  ),
                ] else ...[
                  TextField(
                    controller: singleTargetController,
                    onChanged: controller.updateSingleTargetText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontFamily: 'monospace',
                    ),
                    decoration: fieldDecoration(label: 'CIDR or IP'),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onStartScan,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('Start Scan'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Scan Settings',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _NumberSetting(
                      label: 'IPs per range',
                      value: settings.ipsPerRange,
                      min: 1,
                      max: 64,
                      onChanged: (v) => controller.updateSettings(
                        settings.copyWith(ipsPerRange: v),
                      ),
                    ),
                    _NumberSetting(
                      label: 'Timeout (sec)',
                      value: settings.timeoutSec,
                      min: 1,
                      max: 30,
                      onChanged: (v) => controller.updateSettings(
                        settings.copyWith(timeoutSec: v),
                      ),
                    ),
                    _NumberSetting(
                      label: 'Max workers',
                      value: settings.maxConcurrentWorkers,
                      min: 1,
                      max: 128,
                      onChanged: (v) => controller.updateSettings(
                        settings.copyWith(maxConcurrentWorkers: v),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<PingMethod>(
                  value: settings.method,
                  dropdownColor: Colors.black,
                  style: const TextStyle(color: Colors.white),
                  decoration: fieldDecoration(label: 'Ping Method'),
                  items: PingMethod.values
                      .map(
                        (m) => DropdownMenuItem<PingMethod>(
                          value: m,
                          child: Text(m.name.toUpperCase()),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (method) {
                    if (method == null) return;
                    final resetPort = method == PingMethod.icmp
                        ? null
                        : (settings.targetPort ?? _defaultPort(method));
                    controller.updateSettings(
                      settings.copyWith(method: method, targetPort: resetPort),
                    );
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: portController,
                  enabled:
                      settings.method == PingMethod.tcp ||
                      settings.method == PingMethod.udp ||
                      settings.method == PingMethod.http,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: fieldDecoration(label: 'Target Port'),
                  onChanged: (raw) {
                    final parsed = int.tryParse(raw);
                    controller.updateSettings(
                      settings.copyWith(targetPort: parsed),
                    );
                  },
                ),
                if (settings.method == PingMethod.http) ...[
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    activeColor: Colors.white,
                    value: settings.useHttps,
                    title: const Text(
                      'Use HTTPS',
                      style: TextStyle(color: Colors.white),
                    ),
                    onChanged: (enabled) {
                      controller.updateSettings(
                        settings.copyWith(useHttps: enabled),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            child: Builder(
              builder: (context) {
                final runningTasks = state.currentTasks.where(
                  (task) => task.status == ScanSessionStatus.running,
                );
                final activeTask = runningTasks.isNotEmpty
                    ? runningTasks.first
                    : (state.currentTasks.isNotEmpty
                          ? state.currentTasks.first
                          : null);
                final progressText = activeTask == null
                    ? 'No active tasks'
                    : '${activeTask.progress}/${activeTask.totalRanges}';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Current tasks: ${state.currentTasks.length}',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progressText,
                      style: const TextStyle(color: Color(0xFFB0B0B0)),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          final tabController = DefaultTabController.of(
                            context,
                          );
                          tabController.animateTo(1);
                        },
                        child: const Text(
                          'Open Current Tasks',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        state.errorMessage!,
                        style: const TextStyle(color: Color(0xFFCC6666)),
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SessionDialog extends ConsumerWidget {
  const _SessionDialog({required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(scanControllerProvider);
    final session = state.currentTasks
        .where((task) => task.id == sessionId)
        .cast<ScanSession?>()
        .firstOrNull;

    if (session == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    final statusColor = switch (session.status) {
      ScanSessionStatus.running => const Color(0xFFB0B0B0),
      ScanSessionStatus.completed => const Color(0xFF3A7D44),
      ScanSessionStatus.failed => const Color(0xFF8B3A3A),
    };

    return Material(
      color: Colors.transparent,
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.95,
          heightFactor: 0.92,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: const Color(0xFF1D1D1D)),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            session.label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            session.inputText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB0B0B0),
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      session.status.name.toUpperCase(),
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Progress: ${session.progress}/${session.totalRanges}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: session.totalRanges == 0
                      ? null
                      : session.progress / session.totalRanges,
                  backgroundColor: const Color(0xFF1A1A1A),
                  color: Colors.white,
                ),
                if (session.errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    session.errorMessage!,
                    style: const TextStyle(color: Color(0xFFCC6666)),
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF050505),
                      border: Border.all(color: const Color(0xFF1D1D1D)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: session.results.isEmpty
                        ? const Center(
                            child: Text(
                              'Scanning in progress...',
                              style: TextStyle(color: Color(0xFFAAAAAA)),
                            ),
                          )
                        : ListView.separated(
                            itemCount: session.results.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final item = session.results[index];
                              return _RangeResultCard(result: item);
                            },
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryDetailsDialog extends StatelessWidget {
  const _HistoryDetailsDialog({required this.entry});

  final ScanHistoryEntry entry;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: FractionallySizedBox(
          widthFactor: 0.95,
          heightFactor: 0.92,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              border: Border.all(color: const Color(0xFF1D1D1D)),
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.listName,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            entry.targetText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Color(0xFFB0B0B0),
                              fontFamily: 'monospace',
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        await Clipboard.setData(
                          ClipboardData(text: entry.rawText),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Raw text copied')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                      color: Colors.white,
                      tooltip: 'Copy raw text',
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      color: Colors.white,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  entry.settingsSummary,
                  style: const TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Alive ranges: ${entry.aliveRanges.length}',
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF050505),
                            border: Border.all(color: const Color(0xFF1D1D1D)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: entry.aliveRanges.isEmpty
                              ? const Center(
                                  child: Text(
                                    'No alive ranges in this scan',
                                    style: TextStyle(color: Color(0xFFAAAAAA)),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: entry.aliveRanges.length,
                                  separatorBuilder: (_, __) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final range = entry.aliveRanges[index];
                                    return _HistoryRangeCard(range: range);
                                  },
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF050505),
                            border: Border.all(color: const Color(0xFF1D1D1D)),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: SingleChildScrollView(
                            child: SelectableText(
                              entry.rawText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: 'monospace',
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CurrentTasksTab extends StatelessWidget {
  const _CurrentTasksTab({
    required this.tasks,
    required this.onOpen,
    required this.onDismiss,
  });

  final List<ScanSession> tasks;
  final ValueChanged<ScanSession> onOpen;
  final Future<void> Function(String sessionId) onDismiss;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const Center(
        child: Text(
          'No current tasks',
          style: TextStyle(color: Color(0xFFAAAAAA)),
        ),
      );
    }

    return ListView.separated(
      itemCount: tasks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final task = tasks[index];
        return _TaskCard(
          task: task,
          onOpen: () => onOpen(task),
          onDismiss: () => onDismiss(task.id),
        );
      },
    );
  }
}

class _HistoryTab extends StatelessWidget {
  const _HistoryTab({
    required this.entries,
    required this.onOpen,
    required this.onDelete,
  });

  final List<ScanHistoryEntry> entries;
  final ValueChanged<ScanHistoryEntry> onOpen;
  final Future<void> Function(String id) onDelete;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const Center(
        child: Text(
          'No history yet',
          style: TextStyle(color: Color(0xFFAAAAAA)),
        ),
      );
    }

    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return InkWell(
          onTap: () => onOpen(entry),
          child: _SectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.listName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${entry.aliveRanges.length} alive',
                      style: const TextStyle(color: Color(0xFF3A7D44)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => onDelete(entry.id),
                      icon: const Icon(Icons.delete_outline),
                      color: const Color(0xFF8B3A3A),
                      tooltip: 'Delete history item',
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  entry.targetText,
                  style: const TextStyle(
                    color: Color(0xFFB0B0B0),
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  entry.settingsSummary,
                  style: const TextStyle(
                    color: Color(0xFF7A7A7A),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TaskCard extends StatelessWidget {
  const _TaskCard({
    required this.task,
    required this.onOpen,
    required this.onDismiss,
  });

  final ScanSession task;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (task.status) {
      ScanSessionStatus.running => const Color(0xFFB0B0B0),
      ScanSessionStatus.completed => const Color(0xFF3A7D44),
      ScanSessionStatus.failed => const Color(0xFF8B3A3A),
    };

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  task.label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                task.status.name.toUpperCase(),
                style: TextStyle(color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            task.targetSummary,
            style: const TextStyle(
              color: Color(0xFFB0B0B0),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Progress ${task.progress}/${task.totalRanges}',
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            minHeight: 3,
            value: task.totalRanges == 0
                ? null
                : task.progress / task.totalRanges,
            backgroundColor: const Color(0xFF1A1A1A),
            color: Colors.white,
          ),
          if (task.errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              task.errorMessage!,
              style: const TextStyle(color: Color(0xFFCC6666)),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: onOpen,
                child: const Text(
                  'Open',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: onDismiss,
                child: const Text(
                  'Remove',
                  style: TextStyle(color: Color(0xFFAAAAAA)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RangeResultCard extends StatelessWidget {
  const _RangeResultCard({required this.result});

  final ScanResult result;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (result.status) {
      ScanStatus.alive => const Color(0xFF3A7D44),
      ScanStatus.dead => const Color(0xFF8B3A3A),
      ScanStatus.scanning => const Color(0xFFB0B0B0),
      ScanStatus.unknown => const Color(0xFF666666),
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF090909),
        border: Border.all(color: const Color(0xFF1D1D1D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  result.cidr,
                  style: const TextStyle(
                    color: Colors.white,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              Text(
                result.status.name.toUpperCase(),
                style: TextStyle(color: statusColor),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Checked: ${result.checkedIps.join(', ')}',
            style: const TextStyle(
              color: Color(0xFFB0B0B0),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          if (result.aliveIp != null)
            Text(
              'Alive IP: ${result.aliveIp}',
              style: const TextStyle(
                color: Color(0xFF3A7D44),
                fontFamily: 'monospace',
              ),
            ),
        ],
      ),
    );
  }
}

class _HistoryRangeCard extends StatelessWidget {
  const _HistoryRangeCard({required this.range});

  final ScanHistoryRangeRecord range;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF090909),
        border: Border.all(color: const Color(0xFF1D1D1D)),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            range.cidr,
            style: const TextStyle(
              color: Colors.white,
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Alive IP: ${range.aliveIp}',
            style: const TextStyle(
              color: Color(0xFF3A7D44),
              fontFamily: 'monospace',
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Checked: ${range.checkedIps.join(', ')}',
            style: const TextStyle(
              color: Color(0xFFB0B0B0),
              fontFamily: 'monospace',
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Method: ${range.method.toUpperCase()}',
            style: const TextStyle(color: Color(0xFFB0B0B0), fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ListSelector extends StatelessWidget {
  const _ListSelector({
    required this.lists,
    required this.activeListId,
    required this.onChanged,
  });

  final List<CidrList> lists;
  final String? activeListId;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (lists.isEmpty) {
      return const Text(
        'No lists available. Add CIDR lists from the manager.',
        style: TextStyle(color: Color(0xFFAAAAAA)),
      );
    }

    return DropdownButtonFormField<String>(
      value: activeListId ?? lists.first.id,
      dropdownColor: Colors.black,
      style: const TextStyle(color: Colors.white),
      decoration: fieldDecoration(label: 'CIDR List'),
      items: lists
          .map(
            (list) => DropdownMenuItem<String>(
              value: list.id,
              child: Text(
                list.name,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }
}

class _NumberSetting extends StatelessWidget {
  const _NumberSetting({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 320),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label: $value', style: const TextStyle(color: Colors.white)),
          Slider(
            value: value.toDouble(),
            min: min.toDouble(),
            max: max.toDouble(),
            divisions: max - min,
            activeColor: Colors.white,
            inactiveColor: const Color(0xFF2A2A2A),
            label: '$value',
            onChanged: (v) => onChanged(v.round()),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        border: Border.all(color: const Color(0xFF1D1D1D)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
