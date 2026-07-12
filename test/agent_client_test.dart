import 'dart:async';
import 'dart:convert';

import 'package:evs_remote/models/alert_config.dart';
import 'package:evs_remote/services/agent_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

class _CapturingClient extends http.BaseClient {
  Uri? lastUri;
  String? lastBody;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    lastUri = request.url;
    if (request is http.Request) lastBody = request.body;
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

  group('AgentClient per-device', () {
    test('alerts прокидывает deviceId в query', () async {
      final client = _CapturingClient();
      final agent = AgentClient(client: client);
      await agent.alerts('host', 8765, 'token', deviceId: 'dev-1');
      expect(client.lastUri?.path, '/alerts');
      expect(client.lastUri?.query, 'device=dev-1');
    });

    test('setAlertConfig шлёт deviceId/topic/scope и пороги', () async {
      final client = _CapturingClient();
      final agent = AgentClient(client: client);
      final err = await agent.setAlertConfig(
        'host', 8765, 'token',
        deviceId: 'dev-1',
        topic: 'nexus-dev-1',
        scope: 'device',
        thresholds: const AlertConfig(cpu: 95),
      );
      expect(err, isNull);
      expect(client.lastUri?.path, '/alert-config');
      final body = jsonDecode(client.lastBody!) as Map<String, dynamic>;
      expect(body['deviceId'], 'dev-1');
      expect(body['topic'], 'nexus-dev-1');
      expect(body['scope'], 'device');
      expect(body['cpu'], 95);
    });
  });
}
