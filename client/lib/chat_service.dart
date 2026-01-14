import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web3dart/web3dart.dart';
import 'package:web3dart/crypto.dart';
import 'crypto_utils.dart';
import 'notification_service.dart';

class ChatMessage {
  final String sender;
  final String receiver;
  final String content;
  final DateTime timestamp;
  final bool isMe;

  ChatMessage({
    required this.sender,
    required this.receiver,
    required this.content,
    required this.timestamp,
    required this.isMe,
  });

  Map<String, dynamic> toJson() => {
    'sender': sender,
    'receiver': receiver,
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'isMe': isMe,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    sender: json['sender'],
    receiver: json['receiver'],
    content: json['content'],
    timestamp: DateTime.parse(json['timestamp']),
    isMe: json['isMe'],
  );
}

class ChatService extends ChangeNotifier {
  static const String rpcUrl = "https://rpc-amoy.polygon.technology/";
  static const String faucetUrl = "http://localhost:3000/claim";
  static const String contractAddressHex = "0x6dFB6977179f35295859a8A406710cDf2F80DdB0";

  late Web3Client _client;
  late DeployedContract _contract;
  late EthPrivateKey _credentials;
  
  String? _myAddress;
  String? _username;
  bool _isRegistered = false;
  EtherAmount _balance = EtherAmount.zero();

  List<ChatMessage> _messages = [];
  Map<String, String> _addressToUsername = {};
  Map<String, String> _addressToPubKey = {};
  int _lastBlock = 0;
  bool _isSyncing = false;

  ChatService() {
    _client = Web3Client(rpcUrl, Client());
    _init();
  }

  String? get myAddress => _myAddress;
  String? get username => _username;
  bool get isRegistered => _isRegistered;
  String get balance => _balance.getValueInUnit(EtherUnit.ether).toStringAsFixed(4);
  List<ChatMessage> get messages => _messages;

  Future<void> _init() async {
    await NotificationService().init();
    final prefs = await SharedPreferences.getInstance();
    String? pKey = prefs.getString('private_key');
    
    if (pKey == null) {
      _credentials = EthPrivateKey.createRandom(Random.secure());
      await prefs.setString('private_key', bytesToHex(_credentials.privateKey));
    } else {
      _credentials = EthPrivateKey.fromHex(pKey);
    }

    _myAddress = _credentials.address.hex;
    await _loadContract();
    await _updateBalance();
    await _checkRegistration();
    await _loadMessages();
    
    _lastBlock = await _client.getBlockNumber();

    // Start polling
    Timer.periodic(const Duration(seconds: 5), (timer) {
      _updateBalance();
      syncMessages();
    });
    notifyListeners();
  }

  Future<void> _updateBalance() async {
    if (_myAddress == null) return;
    _balance = await _client.getBalance(_credentials.address);
    notifyListeners();
  }

  Future<void> _loadContract() async {
    const abi = '[{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"sender","type":"address"},{"indexed":true,"internalType":"address","name":"receiver","type":"address"},{"indexed":false,"internalType":"string","name":"message","type":"string"},{"indexed":false,"internalType":"uint256","name":"timestamp","type":"uint256"}],"name":"NewMessage","type":"event"},{"anonymous":false,"inputs":[{"indexed":true,"internalType":"address","name":"user","type":"address"},{"indexed":false,"internalType":"string","name":"username","type":"string"},{"indexed":false,"internalType":"string","name":"publicKey","type":"string"}],"name":"UserRegistered","type":"event"},{"inputs":[{"internalType":"string","name":"_username","type":"string"}],"name":"getAddressByUsername","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_user","type":"address"}],"name":"getPublicKeyByAddress","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"address","name":"_user","type":"address"}],"name":"getUsernameByAddress","outputs":[{"internalType":"string","name":"","type":"string"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"string","name":"_username","type":"string"},{"internalType":"string","name":"_publicKey","type":"string"}],"name":"registerUsername","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"_to","type":"address"},{"internalType":"string","name":"_message","type":"string"}],"name":"sendMessage","outputs":[],"stateMutability":"nonpayable","type":"function"},{"inputs":[{"internalType":"address","name":"","type":"address"}],"name":"users","outputs":[{"internalType":"string","name":"username","type":"string"},{"internalType":"string","name":"publicKey","type":"string"},{"internalType":"bool","name":"exists","type":"bool"}],"stateMutability":"view","type":"function"},{"inputs":[{"internalType":"string","name":"","type":"string"}],"name":"usernameToAddress","outputs":[{"internalType":"address","name":"","type":"address"}],"stateMutability":"view","type":"function"}]';
    _contract = DeployedContract(
      ContractAbi.fromJson(abi, 'BurnerChat'),
      EthereumAddress.fromHex(contractAddressHex),
    );
  }

  Future<void> _checkRegistration() async {
    final func = _contract.function('users');
    final response = await _client.call(
      contract: _contract,
      function: func,
      params: [_credentials.address],
    );
    
    _isRegistered = response[2] as bool;
    if (_isRegistered) {
      _username = response[0] as String;
    }
    notifyListeners();
  }

  Future<void> register(String name) async {
    final pubKey = CryptoUtils.getPublicKeyFromPrivateKey(_credentials);
    final func = _contract.function('registerUsername');
    
    final gasPrice = await _client.getGasPrice();

    await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract,
        function: func,
        parameters: [name, pubKey],
        gasPrice: gasPrice,
      ),
      chainId: 80002, // Amoy
    );
    
    _username = name;
    _isRegistered = true;
    notifyListeners();
  }

  Future<bool> claimTokens() async {
    if (_myAddress == null) return false;
    try {
      final response = await post(
        Uri.parse(faucetUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'address': _myAddress}),
      );
      if (response.statusCode == 200) {
        await _updateBalance(); // Refresh balance immediately
        return true;
      }
      return false;
    } catch (e) {
      print("Faucet error: $e");
      return false;
    }
  }

  Future<void> sendMessage(String recipientUsername, String text) async {
    // 1. Get recipient address and public key
    final getAddrFunc = _contract.function('getAddressByUsername');
    final addrResponse = await _client.call(contract: _contract, function: getAddrFunc, params: [recipientUsername]);
    final recipientAddr = addrResponse[0] as EthereumAddress;

    if (recipientAddr.hex == "0x0000000000000000000000000000000000000000") {
      throw Exception("User not found");
    }

    final getPubKeyFunc = _contract.function('getPublicKeyByAddress');
    final pubKeyResponse = await _client.call(contract: _contract, function: getPubKeyFunc, params: [recipientAddr]);
    final peerPubKey = pubKeyResponse[0] as String;

    // 2. Encrypt
    final sharedSecret = CryptoUtils.deriveSharedSecret(_credentials, peerPubKey);
    final encrypted = CryptoUtils.encryptMessage(text, sharedSecret);

    // 3. Send
    final sendFunc = _contract.function('sendMessage');
    final gasPrice = await _client.getGasPrice();

    await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract,
        function: sendFunc,
        parameters: [recipientAddr, encrypted],
        gasPrice: gasPrice,
      ),
      chainId: 80002,
    );

    // 4. Local append
    final msg = ChatMessage(
      sender: _myAddress!,
      receiver: recipientAddr.hex,
      content: text,
      timestamp: DateTime.now(),
      isMe: true,
    );
    _messages.insert(0, msg);
    await _saveMessages();
    notifyListeners();
  }

  Future<void> syncMessages() async {
    if (_isSyncing || _myAddress == null) return;
    _isSyncing = true;

    try {
      final currentBlock = await _client.getBlockNumber();
      if (currentBlock <= _lastBlock) {
        _isSyncing = false;
        return;
      }

      final event = _contract.event('NewMessage');
      final filter = FilterOptions.events(
        contract: _contract,
        event: event,
        fromBlock: BlockNum.exact(_lastBlock + 1),
        toBlock: BlockNum.exact(currentBlock),
      );

      final logs = await _client.getLogs(filter);
      
      bool newMessages = false;
      for (final log in logs) {
        try {
          final decoded = event.decodeResults(log.topics!, log.data!);
          
          final senderAddr = decoded[0] as EthereumAddress;
          final receiverAddr = decoded[1] as EthereumAddress;
          final encryptedContent = decoded[2] as String;
          // Timestamp from block is usually needed, but here it's in the event?
          // Event definition: uint256 timestamp. Yes.
          final timestamp = DateTime.fromMillisecondsSinceEpoch((decoded[3] as BigInt).toInt() * 1000);

          if (receiverAddr.hex.toLowerCase() != _myAddress!.toLowerCase()) continue;

          // Decrypt
          String content = encryptedContent;
          try {
             String senderPubKey = _addressToPubKey[senderAddr.hex] ?? "";
             if (senderPubKey.isEmpty) {
               final getPubKeyFunc = _contract.function('getPublicKeyByAddress');
               final pubKeyResponse = await _client.call(contract: _contract, function: getPubKeyFunc, params: [senderAddr]);
               senderPubKey = pubKeyResponse[0] as String;
               _addressToPubKey[senderAddr.hex] = senderPubKey;
             }
             
             final sharedSecret = CryptoUtils.deriveSharedSecret(_credentials, senderPubKey);
             content = CryptoUtils.decryptMessage(encryptedContent, sharedSecret);
          } catch (e) {
            print("Decryption error: $e");
            content = "[Encrypted Message]";
          }

          final msg = ChatMessage(
            sender: senderAddr.hex,
            receiver: receiverAddr.hex,
            content: content,
            timestamp: timestamp,
            isMe: false,
          );

          if (!_messages.any((m) => m.timestamp == msg.timestamp && m.content == msg.content && m.sender == msg.sender)) {
             _messages.insert(0, msg);
             newMessages = true;
             
             // Notification
             String senderName = _addressToUsername[senderAddr.hex] ?? "Unknown";
             if (senderName == "Unknown") {
                 try {
                   final getNameFunc = _contract.function('getUsernameByAddress');
                   final nameResponse = await _client.call(contract: _contract, function: getNameFunc, params: [senderAddr]);
                   senderName = nameResponse[0] as String;
                   _addressToUsername[senderAddr.hex] = senderName;
                 } catch(_) {}
             }
             
             NotificationService().showNotification("New Message from $senderName", content);
          }
        } catch (e) {
          print("Log processing error: $e");
        }
      }

      if (newMessages) {
        await _saveMessages();
        notifyListeners();
      }

      _lastBlock = currentBlock;
    } catch (e) {
      print("Sync error: $e");
    } finally {
      _isSyncing = false;
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _messages.map((m) => jsonEncode(m.toJson())).toList();
    await prefs.setStringList('chat_history', data);
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('chat_history') ?? [];
    _messages = data.map((d) => ChatMessage.fromJson(jsonDecode(d))).toList();
    notifyListeners();
  }
}
