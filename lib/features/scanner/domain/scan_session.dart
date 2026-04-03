import 'scan_result.dart';
import 'scan_settings.dart';
import 'scan_target_mode.dart';

enum ScanSessionStatus { running, completed, failed }

class ScanSession {
  const ScanSession({
    required this.id,
    required this.status,
    required this.targetMode,
    required this.label,
    required this.targetSummary,
    required this.inputText,
    required this.settings,
    required this.startedAt,
    required this.results,
    required this.progress,
    required this.totalRanges,
    this.errorMessage,
    this.finishedAt,
  });

  final String id;
  final ScanSessionStatus status;
  final ScanTargetMode targetMode;
  final String label;
  final String targetSummary;
  final String inputText;
  final ScanSettings settings;
  final DateTime startedAt;
  final List<ScanResult> results;
  final int progress;
  final int totalRanges;
  final String? errorMessage;
  final DateTime? finishedAt;

  ScanSession copyWith({
    String? id,
    ScanSessionStatus? status,
    ScanTargetMode? targetMode,
    String? label,
    String? targetSummary,
    String? inputText,
    ScanSettings? settings,
    DateTime? startedAt,
    List<ScanResult>? results,
    int? progress,
    int? totalRanges,
    Object? errorMessage = _keepValue,
    Object? finishedAt = _keepValue,
  }) {
    return ScanSession(
      id: id ?? this.id,
      status: status ?? this.status,
      targetMode: targetMode ?? this.targetMode,
      label: label ?? this.label,
      targetSummary: targetSummary ?? this.targetSummary,
      inputText: inputText ?? this.inputText,
      settings: settings ?? this.settings,
      startedAt: startedAt ?? this.startedAt,
      results: results ?? this.results,
      progress: progress ?? this.progress,
      totalRanges: totalRanges ?? this.totalRanges,
      errorMessage: errorMessage == _keepValue
          ? this.errorMessage
          : errorMessage as String?,
      finishedAt: finishedAt == _keepValue
          ? this.finishedAt
          : finishedAt as DateTime?,
    );
  }
}

const _keepValue = Object();
