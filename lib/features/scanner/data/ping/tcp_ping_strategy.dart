import 'dart:io';

import '../../domain/ping_method.dart';
import '../../domain/probe_result.dart';
import 'ping_strategy.dart';

class TcpPingStrategy implements PingStrategy {
  @override
  PingMethod get method => PingMethod.tcp;

  @override
  Future<ProbeResult> probe({
    required String ip,
    required Duration timeout,
    int? targetPort,
    bool useHttps = false,
  }) async {
    if (targetPort == null) {
      return ProbeResult(
        isAlive: false,
        ip: ip,
        details: 'targetPort is required for TCP ping',
      );
    }

    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      Socket? socket;
      try {
        socket = await Socket.connect(ip, targetPort, timeout: timeout);
        return ProbeResult(isAlive: true, ip: ip);
      } catch (e) {
        lastError = e;
      } finally {
        await socket?.close();
      }
    }

    return ProbeResult(isAlive: false, ip: ip, details: '$lastError');
  }
}
