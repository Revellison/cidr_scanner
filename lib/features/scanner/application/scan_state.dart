import '../../cidr_lists/domain/cidr_list.dart';
import '../domain/scan_history_entry.dart';
import '../domain/scan_session.dart';
import '../domain/scan_settings.dart';
import '../domain/scan_target_mode.dart';

const _keepValue = Object();

class ScanState {
  const ScanState({
    required this.settings,
    required this.availableLists,
    required this.currentTasks,
    required this.scanHistory,
    required this.targetMode,
    required this.singleTargetText,
    this.activeListId,
    this.isScanning = false,
    this.errorMessage,
  });

  final ScanSettings settings;
  final List<CidrList> availableLists;
  final List<ScanSession> currentTasks;
  final List<ScanHistoryEntry> scanHistory;
  final ScanTargetMode targetMode;
  final String singleTargetText;
  final String? activeListId;
  final bool isScanning;
  final String? errorMessage;

  ScanState copyWith({
    ScanSettings? settings,
    List<CidrList>? availableLists,
    List<ScanSession>? currentTasks,
    List<ScanHistoryEntry>? scanHistory,
    ScanTargetMode? targetMode,
    String? singleTargetText,
    Object? activeListId = _keepValue,
    bool? isScanning,
    Object? errorMessage = _keepValue,
  }) {
    return ScanState(
      settings: settings ?? this.settings,
      availableLists: availableLists ?? this.availableLists,
      currentTasks: currentTasks ?? this.currentTasks,
      scanHistory: scanHistory ?? this.scanHistory,
      targetMode: targetMode ?? this.targetMode,
      singleTargetText: singleTargetText ?? this.singleTargetText,
      activeListId: activeListId == _keepValue
          ? this.activeListId
          : activeListId as String?,
      isScanning: isScanning ?? this.isScanning,
      errorMessage: errorMessage == _keepValue
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  static const ScanState initial = ScanState(
    settings: ScanSettings.defaults,
    availableLists: <CidrList>[],
    currentTasks: <ScanSession>[],
    scanHistory: <ScanHistoryEntry>[],
    targetMode: ScanTargetMode.list,
    singleTargetText: '',
  );
}
