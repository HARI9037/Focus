import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

/// Explicit, temporary LAN pairing. The random 256-bit key stays in the code;
/// it is never transmitted. AES-GCM authenticates direction and each request ID.
class LocalSync {
  static const maxBytes = 28 * 1024 * 1024;
  static final cipher = AesGcm.with256bits();
  ServerSocket? _server;
  Timer? _expiry;
  final Set<Socket> _connections = {};
  final Set<String> _seen = {};
  bool get hosting => _server != null;
  Future<List<String>> host(Future<String> Function(String) exchange) async {
    await close();
    final key = await cipher.newSecretKey();
    final token = base64UrlEncode(await key.extractBytes());
    final server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      0,
      shared: false,
    );
    _server = server;
    server.listen((socket) async {
      if (_connections.length >= 2) {
        socket.destroy();
        return;
      }
      _connections.add(socket);
      try {
        final packet = await _read(socket);
        final envelope = jsonDecode(packet) as Map;
        final id = envelope['id'] as String;
        if (id.length != 36 || _seen.contains(id) || _seen.length >= 100) {
          throw const FormatException('Invalid request');
        }
        final data = await open(packet, key, 'request');
        _seen.add(id);
        final response = await exchange(
          data,
        ).timeout(const Duration(seconds: 30));
        _write(socket, await seal(response, key, id, 'response'));
        await socket.flush();
      } catch (_) {
        /* Never log payloads or pairing material. */
      } finally {
        _connections.remove(socket);
        socket.destroy();
      }
    });
    _expiry = Timer(const Duration(minutes: 10), () => close());
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
    );
    return [
      for (final i in interfaces)
        for (final a in i.addresses)
          'focus://${a.address}:${server.port}/$token',
    ];
  }

  static Future<String> exchange(String code, String payload) async {
    final uri = Uri.parse(code.trim());
    final address = InternetAddress.tryParse(uri.host);
    if (uri.scheme != 'focus' ||
        address == null ||
        !_local(address) ||
        uri.port < 1 ||
        uri.port > 65535 ||
        uri.pathSegments.length != 1) {
      throw const FormatException('Invalid local pairing code');
    }
    final bytes = base64Url.decode(uri.pathSegments.single);
    if (bytes.length != 32) throw const FormatException('Invalid key');
    final key = SecretKey(bytes);
    final id = const Uuid().v4();
    final socket = await Socket.connect(
      address,
      uri.port,
      timeout: const Duration(seconds: 10),
    );
    try {
      final response = _read(socket);
      _write(socket, await seal(payload, key, id, 'request'));
      await socket.flush();
      final packet = await response;
      if ((jsonDecode(packet) as Map)['id'] != id) {
        throw const FormatException('Wrong response');
      }
      return await open(packet, key, 'response');
    } finally {
      socket.destroy();
    }
  }

  static bool _local(InternetAddress a) {
    final b = a.rawAddress;
    return a.isLoopback ||
        b.length == 4 &&
            (b[0] == 10 ||
                b[0] == 192 && b[1] == 168 ||
                b[0] == 172 && b[1] >= 16 && b[1] <= 31);
  }

  static Future<String> seal(
    String text,
    SecretKey key,
    String id,
    String direction,
  ) async {
    if (utf8.encode(text).length > 20 * 1024 * 1024) {
      throw const FormatException('Sync data exceeds 20 MB');
    }
    final box = await cipher.encrypt(
      utf8.encode(text),
      secretKey: key,
      aad: utf8.encode('focus-v1:$direction:$id'),
    );
    return jsonEncode({
      'id': id,
      'nonce': base64Encode(box.nonce),
      'cipher': base64Encode(box.cipherText),
      'mac': base64Encode(box.mac.bytes),
    });
  }

  static Future<String> open(
    String packet,
    SecretKey key,
    String direction,
  ) async {
    final e = jsonDecode(packet) as Map;
    final box = SecretBox(
      base64Decode(e['cipher'] as String),
      nonce: base64Decode(e['nonce'] as String),
      mac: Mac(base64Decode(e['mac'] as String)),
    );
    final bytes = await cipher.decrypt(
      box,
      secretKey: key,
      aad: utf8.encode('focus-v1:$direction:${e['id']}'),
    );
    if (bytes.length > 20 * 1024 * 1024) {
      throw const FormatException('Sync data too large');
    }
    return utf8.decode(bytes);
  }

  static void _write(Socket socket, String text) {
    final data = utf8.encode(text);
    if (data.length > maxBytes) throw const FormatException('Packet too large');
    final header = ByteData(4)..setUint32(0, data.length);
    socket.add(header.buffer.asUint8List());
    socket.add(data);
  }

  static Future<String> _read(Socket socket) {
    final result = Completer<String>();
    final buffer = BytesBuilder(copy: false);
    var length = -1;
    var received = 0;
    final timeout = Timer(const Duration(seconds: 40), () {
      if (!result.isCompleted) {
        result.completeError(TimeoutException('Sync timed out'));
        socket.destroy();
      }
    });
    socket.listen(
      (chunk) {
        if (result.isCompleted) return;
        buffer.add(chunk);
        received += chunk.length;
        if (received > maxBytes + 4) {
          result.completeError(const FormatException('Packet too large'));
          socket.destroy();
          return;
        }
        if (length < 0 && received >= 4) {
          final data = buffer.toBytes();
          length = ByteData.sublistView(data, 0, 4).getUint32(0);
          if (length > maxBytes || length < 1) {
            result.completeError(const FormatException('Invalid packet'));
            socket.destroy();
            return;
          }
        }
        if (length >= 0 && received >= length + 4) {
          timeout.cancel();
          if (received != length + 4) {
            result.completeError(const FormatException('Trailing packet'));
            return;
          }
          try {
            result.complete(utf8.decode(buffer.takeBytes().sublist(4)));
          } catch (error) {
            result.completeError(error);
          }
        }
      },
      onError: (Object error) {
        timeout.cancel();
        if (!result.isCompleted) result.completeError(error);
      },
      onDone: () {
        timeout.cancel();
        if (!result.isCompleted) {
          result.completeError(const SocketException('Connection closed'));
        }
      },
    );
    return result.future;
  }

  Future<void> close() async {
    _expiry?.cancel();
    for (final s in _connections.toList()) {
      s.destroy();
    }
    _connections.clear();
    await _server?.close();
    _server = null;
    _seen.clear();
  }
}
