import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:rive/rive.dart';

class RiveCryptoException implements Exception {
  RiveCryptoException(this.message);

  final String message;

  @override
  String toString() => message;
}

class RiveCryptoService {
  RiveCryptoService({FlutterSecureStorage? secureStorage, AesGcm? cipher})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage(),
      _cipher = cipher ?? AesGcm.with256bits();

  static const String _masterKeyStorageKey = 'rive_cache_master_key_v1';
  static const String _aadPrefix = 'antroph-rive-cache';
  static const int _masterKeyLength = 32;
  static const int _nonceLength = 12;
  static const int _macLength = 16;
  static const int _formatVersion = 1;

  final FlutterSecureStorage _secureStorage;
  final AesGcm _cipher;
  final Random _random = Random.secure();

  Future<Uint8List> encrypt(Uint8List plainBytes, String elementId) async {
    final secretKey = await _getOrCreateMasterKey();
    final nonce = _randomBytes(_nonceLength);
    final secretBox = await _cipher.encrypt(
      plainBytes,
      secretKey: secretKey,
      nonce: nonce,
      aad: utf8.encode(_aadFor(elementId)),
    );

    final payloadLength =
        1 +
        secretBox.nonce.length +
        secretBox.mac.bytes.length +
        secretBox.cipherText.length;
    final payload = Uint8List(payloadLength);
    var offset = 0;

    payload[offset] = _formatVersion;
    offset += 1;

    payload.setRange(offset, offset + secretBox.nonce.length, secretBox.nonce);
    offset += secretBox.nonce.length;

    payload.setRange(
      offset,
      offset + secretBox.mac.bytes.length,
      secretBox.mac.bytes,
    );
    offset += secretBox.mac.bytes.length;

    payload.setRange(
      offset,
      offset + secretBox.cipherText.length,
      secretBox.cipherText,
    );

    return payload;
  }

  Future<Uint8List> decrypt(Uint8List encryptedBytes, String elementId) async {
    final secretKey = await _getOrCreateMasterKey();
    final secretBox = _deserialize(encryptedBytes);
    final clearBytes = await _cipher.decrypt(
      secretBox,
      secretKey: secretKey,
      aad: utf8.encode(_aadFor(elementId)),
    );
    return Uint8List.fromList(clearBytes);
  }

  Future<Uint8List> decryptFile(String filePath, String elementId) async {
    final bytes = await File(filePath).readAsBytes();
    return decrypt(bytes, elementId);
  }

  Future<RiveFile> loadRiveFile(String filePath, String elementId) async {
    final bytes = await decryptFile(filePath, elementId);
    final byteData = ByteData.view(
      bytes.buffer,
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
    return RiveFile.import(byteData);
  }

  bool isEncryptedCachePath(String path) => path.trim().endsWith('.riv.enc');

  Future<SecretKey> _getOrCreateMasterKey() async {
    final existing = await _secureStorage.read(key: _masterKeyStorageKey);
    if (existing != null && existing.isNotEmpty) {
      try {
        return SecretKey(base64Url.decode(existing));
      } catch (_) {
        // Fall through and rotate the stored value.
      }
    }

    final keyBytes = _randomBytes(_masterKeyLength);
    await _secureStorage.write(
      key: _masterKeyStorageKey,
      value: base64UrlEncode(keyBytes),
    );
    return SecretKey(keyBytes);
  }

  SecretBox _deserialize(Uint8List payload) {
    if (payload.lengthInBytes < 1 + _nonceLength + _macLength) {
      throw RiveCryptoException('Encrypted rive payload is truncated.');
    }

    if (payload[0] != _formatVersion) {
      throw RiveCryptoException('Unsupported rive cache payload version.');
    }

    final nonceStart = 1;
    final macStart = nonceStart + _nonceLength;
    final cipherStart = macStart + _macLength;

    final nonce = payload.sublist(nonceStart, macStart);
    final mac = Mac(payload.sublist(macStart, cipherStart));
    final cipherText = payload.sublist(cipherStart);

    return SecretBox(cipherText, nonce: nonce, mac: mac);
  }

  Uint8List _randomBytes(int length) {
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = _random.nextInt(256);
    }
    return bytes;
  }

  String _aadFor(String elementId) => '$_aadPrefix:${elementId.trim()}';
}
