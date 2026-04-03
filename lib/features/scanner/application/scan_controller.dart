import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../../core/storage/hive_boxes.dart';
import '../../cidr_lists/domain/cidr_list.dart';
import '../data/cidr/cidr_parser.dart';
import '../data/engine/range_scan_engine.dart';
import '../data/repositories/cidr_list_repository.dart';
import '../data/repositories/scan_history_repository.dart';
import '../domain/cidr_sample.dart';
import '../domain/ping_method.dart';
import '../domain/range_scan_outcome.dart';
import '../domain/scan_history_entry.dart';
import '../domain/scan_result.dart';
import '../domain/scan_settings.dart';
import '../domain/scan_session.dart';
import '../domain/scan_target_mode.dart';
import 'scan_state.dart';

class ScanController extends StateNotifier<ScanState> {
  ScanController({
    required CidrParser cidrParser,
    required RangeScanEngine scanEngine,
    required CidrListRepository cidrListRepository,
    required ScanHistoryRepository scanHistoryRepository,
  }) : _cidrParser = cidrParser,
       _scanEngine = scanEngine,
       _cidrListRepository = cidrListRepository,
       _scanHistoryRepository = scanHistoryRepository,
       _settingsBox = Hive.box<dynamic>(HiveBoxes.scanSettings),
       super(ScanState.initial);

  final CidrParser _cidrParser;
  final RangeScanEngine _scanEngine;
  final CidrListRepository _cidrListRepository;
  final ScanHistoryRepository _scanHistoryRepository;
  final Box<dynamic> _settingsBox;

  Future<void> loadInitial() async {
    final savedSettingsRaw = _settingsBox.get('scanner_settings');
    final savedSettings = savedSettingsRaw is Map
        ? ScanSettings.fromMap(savedSettingsRaw)
        : ScanSettings.defaults;

    final lists = _cidrListRepository.getAll();
    final history = _scanHistoryRepository.getAll();

    state = state.copyWith(
      settings: savedSettings,
      availableLists: lists,
      activeListId: lists.isEmpty ? null : lists.first.id,
      scanHistory: history,
      errorMessage: null,
    );
  }

  Future<void> refreshLists() async {
    final lists = _cidrListRepository.getAll();
    state = state.copyWith(
      availableLists: lists,
      activeListId: _ensureValidActiveListId(lists),
      errorMessage: null,
    );
  }

  Future<void> updateSettings(ScanSettings settings) async {
    await _settingsBox.put('scanner_settings', settings.toMap());
    state = state.copyWith(settings: settings, errorMessage: null);
  }

  void selectList(String listId) {
    state = state.copyWith(
      activeListId: listId,
      targetMode: ScanTargetMode.list,
      errorMessage: null,
    );
  }

  void setTargetMode(ScanTargetMode mode) {
    state = state.copyWith(targetMode: mode, errorMessage: null);
  }

  void updateSingleTargetText(String value) {
    state = state.copyWith(singleTargetText: value, errorMessage: null);
  }

  Future<void> createList({
    required String name,
    required String rawCidrText,
  }) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      state = state.copyWith(errorMessage: 'List name is required');
      return;
    }

    final cidrs = rawCidrText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (cidrs.isEmpty) {
      state = state.copyWith(errorMessage: 'At least one CIDR is required');
      return;
    }

    final now = DateTime.now();
    final newList = CidrList(
      id: now.microsecondsSinceEpoch.toString(),
      name: trimmedName,
      cidrs: cidrs,
      createdAt: now,
      updatedAt: now,
    );

    await _cidrListRepository.save(newList);
    final lists = _cidrListRepository.getAll();
    state = state.copyWith(
      availableLists: lists,
      activeListId: newList.id,
      targetMode: ScanTargetMode.list,
      errorMessage: null,
    );
  }

  Future<void> deleteList(String listId) async {
    await _cidrListRepository.delete(listId);
    final lists = _cidrListRepository.getAll();
    state = state.copyWith(
      availableLists: lists,
      activeListId: _ensureValidActiveListId(lists),
      errorMessage: null,
    );
  }

  Future<void> clearHistory() async {
    await _scanHistoryRepository.clear();
    state = state.copyWith(scanHistory: const <ScanHistoryEntry>[]);
  }

  Future<void> removeHistoryEntry(String id) async {
    await _scanHistoryRepository.deleteById(id);
    state = state.copyWith(
      scanHistory: _scanHistoryRepository.getAll(),
      errorMessage: null,
    );
  }

  Future<void> dismissTask(String sessionId) async {
    final updated = List<ScanSession>.from(state.currentTasks)
      ..removeWhere((session) => session.id == sessionId);
    state = state.copyWith(currentTasks: updated, errorMessage: null);
  }

  Future<String?> startScan() async {
    final startedAt = DateTime.now();
    final activeListId = state.targetMode == ScanTargetMode.list
        ? state.activeListId
        : null;
    final sessionId = startedAt.microsecondsSinceEpoch.toString();

    final session = ScanSession(
      id: sessionId,
      status: ScanSessionStatus.running,
      targetMode: state.targetMode,
      label: _sessionLabel(),
      targetSummary: _sessionTargetSummary(),
      inputText: _sessionInputText(),
      settings: state.settings,
      startedAt: startedAt,
      results: const <ScanResult>[],
      progress: 0,
      totalRanges: 0,
    );

    state = state.copyWith(
      currentTasks: [...state.currentTasks, session],
      errorMessage: null,
    );

    unawaited(_runSession(sessionId: sessionId, activeListId: activeListId));

    return sessionId;
  }

  Future<void> updateList({
    required String id,
    required String name,
    required String rawCidrText,
  }) async {
    final existing = _cidrListRepository.getById(id);
    if (existing == null) {
      state = state.copyWith(errorMessage: 'List not found');
      return;
    }

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      state = state.copyWith(errorMessage: 'List name is required');
      return;
    }

    final cidrs = rawCidrText
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toSet()
        .toList(growable: false);

    if (cidrs.isEmpty) {
      state = state.copyWith(errorMessage: 'At least one CIDR is required');
      return;
    }

    final updated = existing.copyWith(
      name: trimmedName,
      cidrs: cidrs,
      updatedAt: DateTime.now(),
    );

    await _cidrListRepository.save(updated);
    final lists = _cidrListRepository.getAll();
    state = state.copyWith(
      availableLists: lists,
      activeListId: id,
      errorMessage: null,
    );
  }

  Future<void> _runSession({
    required String sessionId,
    required String? activeListId,
  }) async {
    final session = _sessionById(sessionId);
    if (session == null) {
      return;
    }

    try {
      final inputs = await _buildTargetRanges(session, activeListId);
      _updateSession(sessionId, session.copyWith(totalRanges: inputs.length));

      final outcomes = <RangeScanOutcome>[];
      final scanOutcomes = await _scanEngine.scanRanges(
        ranges: inputs,
        method: session.settings.method,
        timeout: Duration(seconds: session.settings.timeoutSec),
        maxConcurrentWorkers: session.settings.maxConcurrentWorkers,
        targetPort: _effectivePort(
          session.settings.method,
          session.settings.targetPort,
        ),
        useHttps: session.settings.useHttps,
        onOutcome: (outcome) {
          outcomes.add(outcome);
          _appendReactiveResult(sessionId, outcome.result);
        },
      );

      if (outcomes.isEmpty) {
        outcomes.addAll(scanOutcomes);
      }

      final aliveRanges = outcomes
          .where(
            (outcome) =>
                outcome.result.status == ScanStatus.alive &&
                outcome.result.aliveIp != null,
          )
          .map(
            (outcome) => ScanHistoryRangeRecord(
              cidr: outcome.result.cidr,
              aliveIp: outcome.result.aliveIp!,
              checkedIps: outcome.result.checkedIps,
              method: session.settings.method.name,
            ),
          )
          .toList(growable: false);

      final finishedAt = DateTime.now();
      final targetDescription = session.targetMode == ScanTargetMode.list
          ? (activeListId == null
                ? session.inputText
                : _cidrListRepository.getById(activeListId)?.name ??
                      session.inputText)
          : session.inputText;
      final rawText = _buildRawText(aliveRanges);
      final historyEntry = ScanHistoryEntry(
        id: sessionId,
        listId: activeListId,
        listName: session.targetMode == ScanTargetMode.list
            ? (_cidrListRepository.getById(activeListId ?? '')?.name ??
                  targetDescription)
            : 'Single Test',
        targetMode: session.targetMode,
        targetText: targetDescription,
        startedAt: session.startedAt,
        finishedAt: finishedAt,
        settingsSummary: _buildSettingsSummary(session.settings),
        aliveRanges: aliveRanges,
        rawText: rawText,
      );

      _updateSession(
        sessionId,
        session.copyWith(
          status: ScanSessionStatus.completed,
          progress: session.totalRanges,
          finishedAt: finishedAt,
          results: _sessionById(sessionId)?.results ?? session.results,
        ),
      );

      await dismissTask(sessionId);

      unawaited(_persistHistoryEntry(historyEntry));
    } catch (e) {
      _updateSession(
        sessionId,
        session.copyWith(
          status: ScanSessionStatus.failed,
          errorMessage: e.toString(),
          finishedAt: DateTime.now(),
        ),
      );
      state = state.copyWith(errorMessage: e.toString());
    }
  }

  Future<void> _persistHistoryEntry(ScanHistoryEntry entry) async {
    await _scanHistoryRepository.addEntry(entry);
    state = state.copyWith(
      scanHistory: _scanHistoryRepository.getAll(),
      errorMessage: null,
    );
  }

  void _appendReactiveResult(String sessionId, ScanResult result) {
    final session = _sessionById(sessionId);
    if (session == null) {
      return;
    }

    final nextResults = List<ScanResult>.from(session.results)..add(result);
    _updateSession(
      sessionId,
      session.copyWith(results: nextResults, progress: nextResults.length),
    );
  }

  void _updateSession(String sessionId, ScanSession session) {
    final updated = <ScanSession>[];
    for (final current in state.currentTasks) {
      updated.add(current.id == sessionId ? session : current);
    }
    state = state.copyWith(currentTasks: updated, errorMessage: null);
  }

  ScanSession? _sessionById(String sessionId) {
    for (final session in state.currentTasks) {
      if (session.id == sessionId) {
        return session;
      }
    }
    return null;
  }

  Future<List<CidrSample>> _buildTargetRanges(
    ScanSession session,
    String? activeListId,
  ) async {
    if (session.targetMode == ScanTargetMode.list) {
      if (activeListId == null) {
        throw StateError('No CIDR list selected');
      }

      final list = _cidrListRepository.getById(activeListId);
      if (list == null) {
        throw StateError('Selected list not found');
      }

      return _cidrParser.parseAndSample(
        cidrs: list.cidrs,
        ipsPerRange: session.settings.ipsPerRange,
      );
    }

    final trimmed = session.inputText.trim();
    if (trimmed.isEmpty) {
      throw StateError('Single target is required');
    }

    if (trimmed.contains('/')) {
      return _cidrParser.parseAndSample(
        cidrs: <String>[trimmed],
        ipsPerRange: session.settings.ipsPerRange,
      );
    }

    if (!_isIpv4(trimmed)) {
      throw StateError('Enter a valid IPv4 address or CIDR');
    }

    return <CidrSample>[
      CidrSample(
        cidr: trimmed,
        sampledIps: <String>[trimmed],
        totalUsableHosts: 1,
      ),
    ];
  }

  String _sessionLabel() {
    if (state.targetMode == ScanTargetMode.list) {
      final list = _cidrListRepository.getById(state.activeListId ?? '');
      return list == null ? 'CIDR TEST' : 'CIDR TEST';
    }
    return 'IP TEST';
  }

  String _sessionTargetSummary() {
    if (state.targetMode == ScanTargetMode.list) {
      final list = _cidrListRepository.getById(state.activeListId ?? '');
      return list == null ? 'list: unknown' : 'list:${list.name}';
    }
    final input = state.singleTargetText.trim();
    return input.startsWith('/') || input.contains('/')
        ? 'cidr:$input'
        : 'ip:$input';
  }

  String _sessionInputText() {
    if (state.targetMode == ScanTargetMode.list) {
      final list = _cidrListRepository.getById(state.activeListId ?? '');
      return list == null ? '' : list.cidrs.join('\n');
    }
    return state.singleTargetText.trim();
  }

  String _buildRawText(List<ScanHistoryRangeRecord> aliveRanges) {
    if (aliveRanges.isEmpty) {
      return 'No alive ranges found';
    }

    final uniqueCidrs = <String>[];
    for (final record in aliveRanges) {
      if (!uniqueCidrs.contains(record.cidr)) {
        uniqueCidrs.add(record.cidr);
      }
    }
    return uniqueCidrs.join('\n');
  }

  String _buildSettingsSummary(ScanSettings settings) {
    final portText = settings.targetPort == null
        ? 'n/a'
        : settings.targetPort.toString();
    return 'method=${settings.method.name}; ipsPerRange=${settings.ipsPerRange}; timeoutSec=${settings.timeoutSec}; maxWorkers=${settings.maxConcurrentWorkers}; port=$portText; https=${settings.useHttps}';
  }

  bool _isIpv4(String value) {
    final parts = value.split('.');
    if (parts.length != 4) {
      return false;
    }
    for (final part in parts) {
      final octet = int.tryParse(part);
      if (octet == null || octet < 0 || octet > 255) {
        return false;
      }
    }
    return true;
  }

  String? _ensureValidActiveListId(List<CidrList> lists) {
    final currentId = state.activeListId;
    if (currentId == null) {
      return lists.isEmpty ? null : lists.first.id;
    }

    final exists = lists.any((list) => list.id == currentId);
    return exists ? currentId : (lists.isEmpty ? null : lists.first.id);
  }

  int? _effectivePort(PingMethod method, int? targetPort) {
    switch (method) {
      case PingMethod.tcp:
      case PingMethod.udp:
      case PingMethod.http:
        return targetPort;
      case PingMethod.icmp:
        return null;
    }
  }
}
