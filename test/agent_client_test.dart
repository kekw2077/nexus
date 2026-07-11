import 'dart:async';

import 'package:evs_remote/services/agent_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _CapturingClient extends http.BaseClient {
  Uri? lastUri;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    const body = '{"sent": true}';
    return http.StreamedResponse(Stream.value(body.codeUnits), 200);
  }
}

void main() {
  group('AgentClient.wake scheme', () {
    test('secure: false использует http', () async {
      final client = _CapturingClient();
      final agent = AgentClient(client: client);
      await agent.wake('host', 8765, 'token', mac: '00:1A:2B:3C:4D:5E', broadcast: '255.255.255.255');
      expect(client.lastUri?.scheme, 'http');
    });

    test('secure: true использует https', () async {
      final client = _CapturingClient();
      final agent = AgentClient(client: client);
      await agent.wake(
        'host',
        8765,
        'token',
        mac: '00:1A:2B:3C:4D:5E',
        broadcast: '255.255.255.255',
        secure: true,
      );
      expect(client.lastUri?.scheme, 'https');
    });
  });
}
