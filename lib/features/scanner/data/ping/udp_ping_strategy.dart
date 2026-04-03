import 'dart:async';
import 'dart:io';

import '../../domain/ping_method.dart';
import '../../domain/probe_result.dart';
import 'ping_strategy.dart';

class UdpPingStrategy implements PingStrategy {
  @override
  PingMethod get method => PingMethod.udp;

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
        details: 'targetPort is required for UDP ping',
      );
    }

    RawDatagramSocket? socket;
    StreamSubscription<RawSocketEvent>? subscription;

    try {
      socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      final completer = Completer<ProbeResult>();

      subscription = socket.listen((event) {
        if (event == RawSocketEvent.read) {
          final data = socket?.receive();
          if (data != null &&
              data.address.address == ip &&
              !completer.isCompleted) {
            completer.complete(ProbeResult(isAlive: true, ip: ip));
          }
        }
      });

      socket.send(const [0], InternetAddress(ip), targetPort);

      final result = await completer.future.timeout(
        timeout,
        onTimeout: () =>
            ProbeResult(isAlive: false, ip: ip, details: 'timeout'),
      );
      return result;
    } catch (e) {
      return ProbeResult(isAlive: false, ip: ip, details: e.toString());
    } finally {
      await subscription?.cancel();
      socket?.close();
    }
  }
}
