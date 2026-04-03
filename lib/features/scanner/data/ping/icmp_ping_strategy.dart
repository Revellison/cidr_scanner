import 'dart:async';
import 'dart:io';

import 'package:dart_ping/dart_ping.dart';

import '../../domain/ping_method.dart';
import '../../domain/probe_result.dart';
import 'ping_strategy.dart';

class IcmpPingStrategy implements PingStrategy {
  @override
  PingMethod get method => PingMethod.icmp;

  @override
  Future<ProbeResult> probe({
    required String ip,
    required Duration timeout,
    int? targetPort,
    bool useHttps = false,
  }) async {
    if (Platform.isAndroid) {
      return _androidFallback(ip: ip, timeout: timeout, targetPort: targetPort);
    }

    try {
      final ping = Ping(ip, count: 1, timeout: timeout.inSeconds.clamp(1, 60));
      final completer = Completer<ProbeResult>();
      late final StreamSubscription<PingData> subscription;

      subscription = ping.stream.listen((event) {
        final response = event.response;
        if (response != null && !completer.isCompleted) {
          completer.complete(ProbeResult(isAlive: true, ip: ip));
        }
        if (event.summary != null && !completer.isCompleted) {
          completer.complete(ProbeResult(isAlive: false, ip: ip));
        }
      });

      final result = await completer.future.timeout(
        timeout,
        onTimeout: () =>
            ProbeResult(isAlive: false, ip: ip, details: 'timeout'),
      );

      await subscription.cancel();
      return result;
    } catch (e) {
      return ProbeResult(isAlive: false, ip: ip, details: e.toString());
    }
  }

  Future<ProbeResult> _androidFallback({
    required String ip,
    required Duration timeout,
    int? targetPort,
  }) async {
    final ports = <int>{if (targetPort != null) targetPort, 443, 80}.toList();

    for (final port in ports) {
      Socket? socket;
      try {
        socket = await Socket.connect(ip, port, timeout: timeout);
        return ProbeResult(
          isAlive: true,
          ip: ip,
          details: 'android-icmp-fallback:tcp:$port',
        );
      } catch (_) {
        // Continue to the next fallback port.
      } finally {
        await socket?.close();
      }
    }

    return ProbeResult(
      isAlive: false,
      ip: ip,
      details: 'android-icmp-fallback-failed',
    );
  }
}
