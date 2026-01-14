import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:encrypt/encrypt.dart' as enc;
import 'package:web3dart/crypto.dart';
import 'package:web3dart/web3dart.dart';
import 'package:pointycastle/export.dart' as pc;
import 'package:crypto/crypto.dart' as crypto;

class EntropyService {
  static final EntropyService _instance = EntropyService._internal();
  factory EntropyService() => _instance;
  EntropyService._internal();

  final List<int> _entropyPool = [];
  final int _maxPoolSize = 1024;

  void addEntropy(double x, double y, int timestamp) {
    // Simple mixing of coordinates and time
    // We only keep the lower bytes to simulate noise
    int b1 = (x * 1000).toInt() & 0xFF;
    int b2 = (y * 1000).toInt() & 0xFF;
    int b3 = timestamp & 0xFF;
    
    _entropyPool.add(b1);
    if (_entropyPool.length >= _maxPoolSize) _entropyPool.removeAt(0);
    
    _entropyPool.add(b2);
    if (_entropyPool.length >= _maxPoolSize) _entropyPool.removeAt(0);
    
    _entropyPool.add(b3);
    if (_entropyPool.length >= _maxPoolSize) _entropyPool.removeAt(0);
  }

  Uint8List getMixedEntropy(int length) {
    // 1. Get System Secure Random
    final secureRandom = Random.secure();
    final systemBytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      systemBytes[i] = secureRandom.nextInt(256);
    }

    // 2. Hash our pool to get a digest
    if (_entropyPool.isEmpty) return systemBytes;
    
    final digest = crypto.sha256.convert(_entropyPool).bytes;
    
    // 3. XOR Mix
    final mixed = Uint8List(length);
    for (var i = 0; i < length; i++) {
      mixed[i] = systemBytes[i] ^ digest[i % digest.length];
    }
    
    return mixed;
  }
}

class CryptoUtils {
  /// Extract the public key (uncompressed, hex) from a private key
  static String getPublicKeyFromPrivateKey(EthPrivateKey privateKey) {
    final privateKeyInt = privateKey.privateKeyInt;
    final domainParams = pc.ECDomainParameters('secp256k1');
    final publicKeyPoint = domainParams.G * privateKeyInt;
    final encoded = publicKeyPoint!.getEncoded(false);
    return bytesToHex(encoded, include0x: true);
  }

  /// Derive a shared secret using ECDH
  static Uint8List deriveSharedSecret(EthPrivateKey myPrivateKey, String peerPublicKeyHex) {
    final domainParams = pc.ECDomainParameters('secp256k1');
    final peerKeyBytes = hexToBytes(peerPublicKeyHex);
    final curve = domainParams.curve;
    final peerPoint = curve.decodePoint(peerKeyBytes);

    if (peerPoint == null) throw Exception("Invalid peer public key");

    final sharedPoint = peerPoint * myPrivateKey.privateKeyInt;
    if (sharedPoint == null) throw Exception("Failed to derive shared point");

    final xBigInt = sharedPoint.x!.toBigInteger()!;
    final xBytes = _bigIntToBytes(xBigInt);
    
    final padded = Uint8List(32);
    final srcOffset = xBytes.length > 32 ? xBytes.length - 32 : 0;
    final destOffset = 32 - (xBytes.length > 32 ? 32 : xBytes.length);
    final length = xBytes.length > 32 ? 32 : xBytes.length;
    
    for (int i = 0; i < length; i++) {
        padded[destOffset + i] = xBytes[srcOffset + i];
    }

    return padded;
  }

  static Uint8List _bigIntToBytes(BigInt number) {
    if (number == BigInt.zero) return Uint8List.fromList([0]);
    String hex = number.toRadixString(16);
    if (hex.length % 2 != 0) hex = '0$hex';
    return hexToBytes(hex);
  }

  /// Encrypt a message using AES-GCM with the derived shared secret and Mixed Entropy
  static String encryptMessage(String plainText, Uint8List sharedSecret) {
    final key = enc.Key(sharedSecret);
    
    // Generate IV using our Custom Entropy Service (Touch Jitter + System RNG)
    final ivBytes = EntropyService().getMixedEntropy(12);
    final iv = enc.IV(ivBytes);
    
    final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    
    return "AES:${iv.base64}:${encrypted.base64}";
  }

  /// Decrypt a message
  static String decryptMessage(String cipherTextFormatted, Uint8List sharedSecret) {
    if (!cipherTextFormatted.startsWith("AES:")) return cipherTextFormatted;

    try {
      final parts = cipherTextFormatted.split(':');
      if (parts.length != 3) return cipherTextFormatted;

      final iv = enc.IV.fromBase64(parts[1]);
      final encrypted = enc.Encrypted.fromBase64(parts[2]);
      
      final key = enc.Key(sharedSecret);
      final encrypter = enc.Encrypter(enc.AES(key, mode: enc.AESMode.gcm));

      return encrypter.decrypt(encrypted, iv: iv);
    } catch (e) {
      return "[Decryption Failed]";
    }
  }
}
