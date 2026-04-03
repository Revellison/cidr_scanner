import 'dart:isolate';
import 'dart:math';

import '../../domain/cidr_sample.dart';

class CidrParser {
  Future<List<CidrSample>> parseAndSample({
    required List<String> cidrs,
    required int ipsPerRange,
  }) {
    return Isolate.run(() => _parseAndSampleSync(cidrs, ipsPerRange));
  }
}

List<CidrSample> _parseAndSampleSync(List<String> cidrs, int ipsPerRange) {
  final result = <CidrSample>[];
  final random = Random();

  for (final raw in cidrs) {
    final cidr = raw.trim();
    if (cidr.isEmpty) {
      continue;
    }

    final parsed = _tryParseIpv4Cidr(cidr);
    if (parsed == null) {
      continue;
    }

    final (networkInt, prefix) = parsed;
    final totalHosts = 1 << (32 - prefix);
    if (totalHosts <= 2) {
      continue;
    }

    final usableHosts = totalHosts - 2;
    final sampleCount = ipsPerRange.clamp(1, usableHosts);
    final sampledOffsets = <int>{};

    while (sampledOffsets.length < sampleCount) {
      sampledOffsets.add(1 + random.nextInt(usableHosts));
    }

    final sampledIps = sampledOffsets
        .map((offset) => _intToIpv4(networkInt + offset))
        .toList(growable: false);

    result.add(
      CidrSample(
        cidr: cidr,
        sampledIps: sampledIps,
        totalUsableHosts: usableHosts,
      ),
    );
  }

  return result;
}

(int, int)? _tryParseIpv4Cidr(String cidr) {
  final parts = cidr.split('/');
  if (parts.length != 2) {
    return null;
  }

  final ipInt = _tryIpv4ToInt(parts[0]);
  final prefix = int.tryParse(parts[1]);
  if (ipInt == null || prefix == null || prefix < 0 || prefix > 32) {
    return null;
  }

  final mask = prefix == 0 ? 0 : (0xFFFFFFFF << (32 - prefix)) & 0xFFFFFFFF;
  final networkInt = ipInt & mask;
  return (networkInt, prefix);
}

int? _tryIpv4ToInt(String ip) {
  final octets = ip.split('.');
  if (octets.length != 4) {
    return null;
  }

  var value = 0;
  for (final octet in octets) {
    final part = int.tryParse(octet);
    if (part == null || part < 0 || part > 255) {
      return null;
    }
    value = (value << 8) | part;
  }

  return value;
}

String _intToIpv4(int value) {
  final a = (value >> 24) & 0xFF;
  final b = (value >> 16) & 0xFF;
  final c = (value >> 8) & 0xFF;
  final d = value & 0xFF;
  return '$a.$b.$c.$d';
}
