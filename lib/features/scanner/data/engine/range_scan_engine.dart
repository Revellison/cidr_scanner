import 'dart:async';
import 'dart:isolate';

import '../../domain/cidr_sample.dart';
import '../../domain/ping_method.dart';
import '../../domain/range_scan_outcome.dart';
import '../../domain/scan_result.dart';
import '../ping/ping_strategy_factory.dart';

class RangeScanEngine {
  const RangeScanEngine();

  Future<List<RangeScanOutcome>> scanRanges({
    required List<CidrSample> ranges,
    required PingMethod method,
    required Duration timeout,
    required int maxConcurrentWorkers,
    int? targetPort,
    bool useHttps = false,
    void Function(RangeScanOutcome outcome)? onOutcome,
  }) async {
    final workerLimit = maxConcurrentWorkers < 1 ? 1 : maxConcurrentWorkers;
    final outcomes = <RangeScanOutcome>[];
    final active = <Future<RangeScanOutcome>>[];

    for (final range in ranges) {
      active.add(
        _scanSingleRange(
          range: range,
          method: method,
          timeout: timeout,
          targetPort: targetPort,
          useHttps: useHttps,
        ),
      );

      if (active.length >= workerLimit) {
        final completed = await active.removeAt(0);
        outcomes.add(completed);
        onOutcome?.call(completed);
      }
    }

    for (final pending in active) {
      final completed = await pending;
      outcomes.add(completed);
      onOutcome?.call(completed);
    }

    return outcomes;
  }

  Future<RangeScanOutcome> _scanSingleRange({
    required CidrSample range,
    required PingMethod method,
    required Duration timeout,
    int? targetPort,
    required bool useHttps,
  }) async {
    final checkedIps = <String>[];
    final startedAt = DateTime.now();

    for (final ip in range.sampledIps) {
      checkedIps.add(ip);
      final alive = await _probeInIsolate(
        ip: ip,
        method: method,
        timeoutMillis: timeout.inMilliseconds,
        targetPort: targetPort,
        useHttps: useHttps,
      );

      if (alive) {
        final result = ScanResult(
          cidr: range.cidr,
          status: ScanStatus.alive,
          checkedIps: List.unmodifiable(checkedIps),
          aliveIp: ip,
          startedAt: startedAt,
          finishedAt: DateTime.now(),
        );

        return RangeScanOutcome(result: result, checkedIps: checkedIps);
      }
    }

    final deadResult = ScanResult(
      cidr: range.cidr,
      status: ScanStatus.dead,
      checkedIps: List.unmodifiable(checkedIps),
      aliveIp: null,
      startedAt: startedAt,
      finishedAt: DateTime.now(),
    );

    return RangeScanOutcome(result: deadResult, checkedIps: checkedIps);
  }

  Future<bool> _probeInIsolate({
    required String ip,
    required PingMethod method,
    required int timeoutMillis,
    int? targetPort,
    required bool useHttps,
  }) {
    return Isolate.run(() {
      return _probeInIsolateEntry(<String, Object?>{
        'ip': ip,
        'methodIndex': method.index,
        'timeoutMillis': timeoutMillis,
        'targetPort': targetPort,
        'useHttps': useHttps,
      });
    });
  }
}

Future<bool> _probeInIsolateEntry(Map<String, Object?> payload) async {
  final ip = payload['ip']! as String;
  final method = PingMethod.values[payload['methodIndex']! as int];
  final timeoutMillis = payload['timeoutMillis']! as int;
  final targetPort = payload['targetPort'] as int?;
  final useHttps = payload['useHttps']! as bool;

  final strategy = PingStrategyFactory().create(method);
  final probe = await strategy.probe(
    ip: ip,
    timeout: Duration(milliseconds: timeoutMillis),
    targetPort: targetPort,
    useHttps: useHttps,
  );
  return probe.isAlive;
}
