import 'dart:io';

import 'package:caldav_free/data/remote/sync_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Transport tests live in their own file: `TestWidgetsFlutterBinding`
/// replaces `HttpClient` with a fake that answers 400, so they must run
/// without a widget binding installed.

void main() {
  test('connection failures become readable SyncApiExceptions', () async {
    // Reserve a port, then close it so the next connect is refused.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final port = server.port;
    await server.close(force: true);

    final api = HttpSyncApi(
      baseUrl: 'http://127.0.0.1:$port',
      username: 'demo',
      password: 'secret',
    );
    addTearDown(api.close);

    await expectLater(
      api.pull(since: '0', limit: 1),
      throwsA(
        isA<SyncApiException>()
            .having((error) => error.network, 'network', isTrue)
            .having((error) => error.message, 'message', startsWith('无法连接服务器')),
      ),
    );
  });

  test('a stalled server fails with the timeout message', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final subscription = server.listen((request) {
      // Accept the connection but never answer.
    });
    addTearDown(() async {
      await subscription.cancel();
      await server.close(force: true);
    });

    final api = HttpSyncApi(
      baseUrl: 'http://127.0.0.1:${server.port}',
      username: 'demo',
      password: 'secret',
      pullTimeout: const Duration(milliseconds: 150),
    );
    addTearDown(api.close);

    await expectLater(
      api.pull(since: '0', limit: 1),
      throwsA(
        isA<SyncApiException>()
            .having((error) => error.network, 'network', isTrue)
            .having((error) => error.message, 'message', contains('超时')),
      ),
    );
  });
}
