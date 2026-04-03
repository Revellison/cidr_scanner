import 'ping_method.dart';

class ScanSettings {
  const ScanSettings({
    required this.ipsPerRange,
    required this.timeoutSec,
    required this.maxConcurrentWorkers,
    required this.method,
    this.targetPort,
    this.useHttps = false,
  });

  final int ipsPerRange;
  final int timeoutSec;
  final int maxConcurrentWorkers;
  final PingMethod method;
  final int? targetPort;
  final bool useHttps;

  static const ScanSettings defaults = ScanSettings(
    ipsPerRange: 3,
    timeoutSec: 2,
    maxConcurrentWorkers: 8,
    method: PingMethod.tcp,
    targetPort: 80,
    useHttps: false,
  );

  ScanSettings copyWith({
    int? ipsPerRange,
    int? timeoutSec,
    int? maxConcurrentWorkers,
    PingMethod? method,
    int? targetPort,
    bool? useHttps,
  }) {
    return ScanSettings(
      ipsPerRange: ipsPerRange ?? this.ipsPerRange,
      timeoutSec: timeoutSec ?? this.timeoutSec,
      maxConcurrentWorkers: maxConcurrentWorkers ?? this.maxConcurrentWorkers,
      method: method ?? this.method,
      targetPort: targetPort ?? this.targetPort,
      useHttps: useHttps ?? this.useHttps,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'ipsPerRange': ipsPerRange,
      'timeoutSec': timeoutSec,
      'maxConcurrentWorkers': maxConcurrentWorkers,
      'methodIndex': method.index,
      'targetPort': targetPort,
      'useHttps': useHttps,
    };
  }

  static ScanSettings fromMap(Map<dynamic, dynamic> map) {
    final methodIndex = (map['methodIndex'] as int?) ?? PingMethod.tcp.index;
    return ScanSettings(
      ipsPerRange: (map['ipsPerRange'] as int?) ?? defaults.ipsPerRange,
      timeoutSec: (map['timeoutSec'] as int?) ?? defaults.timeoutSec,
      maxConcurrentWorkers:
          (map['maxConcurrentWorkers'] as int?) ?? defaults.maxConcurrentWorkers,
      method: PingMethod.values[methodIndex.clamp(0, PingMethod.values.length - 1)],
      targetPort: map['targetPort'] as int?,
      useHttps: (map['useHttps'] as bool?) ?? defaults.useHttps,
    );
  }
}
