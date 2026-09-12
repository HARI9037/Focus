import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:focus/core/sync/local_sync.dart';

void main() {
  test(
    'authenticated encryption rejects tampering and wrong direction',
    () async {
      final key = await LocalSync.cipher.newSecretKey();
      final packet = await LocalSync.seal(
        'private note',
        key,
        'request-1',
        'request',
      );
      expect(packet, isNot(contains('private note')));
      expect(await LocalSync.open(packet, key, 'request'), 'private note');
      await expectLater(
        LocalSync.open(packet, key, 'response'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
      final envelope = jsonDecode(packet) as Map<String, dynamic>;
      envelope['id'] = 'different';
      await expectLater(
        LocalSync.open(jsonEncode(envelope), key, 'request'),
        throwsA(isA<SecretBoxAuthenticationError>()),
      );
    },
  );
  test(
    'local socket exchange transfers and returns authenticated records',
    () async {
      final host = LocalSync();
      addTearDown(host.close);
      final codes = await host.host((payload) async => 'merged:$payload');
      expect(codes, isNotEmpty);
      final uri = Uri.parse(codes.first).replace(host: '127.0.0.1');
      expect(
        await LocalSync.exchange(uri.toString(), 'records'),
        'merged:records',
      );
    },
  );
  test('pairing refuses public internet endpoints', () async {
    await expectLater(
      LocalSync.exchange('focus://8.8.8.8:4000/key', 'x'),
      throwsFormatException,
    );
  });
}
