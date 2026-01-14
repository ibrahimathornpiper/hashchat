#!/bin/bash

# setup_cloud_ipa.sh
# Sets up the project for AltStore (iOS Unsigned) Cloud Build via GitHub Actions.
# Includes "Liquid Glass" design, AES Encryption, and Auto-Wallet generation.

set -e

echo "🔹 Starting HashChat Cloud Setup..."

# 1. Check Git
if ! command -v git &> /dev/null; then
    echo "❌ Git is not installed. Please install git first."
    exit 1
fi

if [ ! -d ".git" ]; then
    echo "🔸 Initializing Git repository..."
    git init
else
    echo "✅ Git repository detected."
fi

# 2. Update/Create pubspec.yaml in client/
echo "🔹 Configuring client/pubspec.yaml..."
mkdir -p client

# We overwrite pubspec.yaml to ensure compatibility with the new main.dart
cat > client/pubspec.yaml <<EOF
name: hashchat_client
description: A Burner Chat Client with Liquid Glass Design.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.0.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.6
  # UI
  glassmorphic: ^3.0.0
  google_fonts: ^6.1.0
  # Crypto
  web3dart: ^2.7.0
  encrypt: ^5.0.3
  http: ^1.1.0

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0

flutter:
  uses-material-design: true
EOF

# 3. Generate Liquid Glass App Code (client/lib/main.dart)
echo "🔹 Generating Liquid Glass App Logic (AES + Wallet)..."
mkdir -p client/lib

cat > client/lib/main.dart <<'EOF'
import 'dart:ui';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:glassmorphic/glassmorphic.dart';
import 'package:web3dart/web3dart.dart'; // For Wallet
import 'package:encrypt/encrypt.dart' as encrypt; // For AES
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const HashChatApp());
}

class HashChatApp extends StatelessWidget {
  const HashChatApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HashChat',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black,
        primarySwatch: Colors.blue,
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const LiquidHome(),
    );
  }
}

class LiquidHome extends StatefulWidget {
  const LiquidHome({super.key});

  @override
  State<LiquidHome> createState() => _LiquidHomeState();
}

class _LiquidHomeState extends State<LiquidHome> {
  String _walletAddress = "Generating...";
  String _privateKey = "";
  final TextEditingController _msgController = TextEditingController();
  final List<String> _messages = [];

  @override
  void initState() {
    super.initState();
    _generateBurnerWallet();
  }

  // --- CRYPTO LOGIC ---

  Future<void> _generateBurnerWallet() async {
    // 1. Generate random Eth private key
    var rng = Random.secure();
    Credentials cred = EthPrivateKey.createRandom(rng);
    EthereumAddress address = await cred.extractAddress();
    
    setState(() {
      _privateKey = (cred as EthPrivateKey).privateKeyInt.toRadixString(16);
      _walletAddress = address.hex;
    });
  }

  String _encryptMessage(String plainText) {
    // Simple AES Encryption (In prod, derive key from secure storage or diffie-hellman)
    final key = encrypt.Key.fromUtf8('my32lengthsupersecretnooneknows1'); 
    final iv = encrypt.IV.fromLength(16);
    final encrypter = encrypt.Encrypter(encrypt.AES(key));
    
    final encrypted = encrypter.encrypt(plainText, iv: iv);
    return encrypted.base64;
  }

  void _sendMessage() {
    if (_msgController.text.isEmpty) return;
    
    final encrypted = _encryptMessage(_msgController.text);
    // In a real app, you'd broadcast 'encrypted' to the mesh/server here.
    
    setState(() {
      _messages.insert(0, "Me: ${_msgController.text} \n(Enc: ${encrypted.substring(0, 10)}...)");
      _msgController.clear();
    });
  }

  // --- UI LOGIC (Liquid Glass) ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // 1. Deep Mesh Gradient Background
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          // Ambient Blobs
          Positioned(
            top: -50,
            left: -50,
            child: _buildBlob(Colors.purpleAccent.withOpacity(0.4)),
          ),
          Positioned(
            bottom: 100,
            right: -60,
            child: _buildBlob(Colors.cyanAccent.withOpacity(0.4)),
          ),

          // 2. Main Content
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                _buildGlassHeader(),
                const SizedBox(height: 20),
                Expanded(child: _buildChatList()),
                _buildInputArea(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBlob(Color color) {
    return Container(
      height: 300,
      width: 300,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [BoxShadow(color: color, blurRadius: 80, spreadRadius: 20)],
      ),
    );
  }

  Widget _buildGlassHeader() {
    return GlassmorphicContainer(
      width: double.infinity,
      height: 140,
      borderRadius: 20,
      blur: 20,
      alignment: Alignment.center,
      border: 2,
      linearGradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
          stops: const [0.1, 1],
      ),
      borderGradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withOpacity(0.5),
          Colors.white.withOpacity(0.1),
        ],
      ),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("HashChat // Identity", style: GoogleFonts.outfit(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            SelectableText(
              _walletAddress,
              style: GoogleFonts.sourceCodePro(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text("Status: Connected (Burner Mode)", style: GoogleFonts.outfit(color: Colors.greenAccent, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildChatList() {
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _messages.length,
      itemBuilder: (ctx, i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: GlassmorphicContainer(
            width: double.infinity,
            height: 60,
            borderRadius: 12,
            blur: 10,
            alignment: Alignment.centerLeft,
            border: 1,
            linearGradient: LinearGradient(colors: [Colors.white.withOpacity(0.05), Colors.white.withOpacity(0.01)]),
            borderGradient: LinearGradient(colors: [Colors.white.withOpacity(0.2), Colors.transparent]),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(_messages[i], style: const TextStyle(color: Colors.white)),
            ),
          ),
        );
      },
    );
  }

  Widget _buildInputArea() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Expanded(
            child: CupertinoTextField(
              controller: _msgController,
              placeholder: "Type a secret...",
              placeholderStyle: TextStyle(color: Colors.white.withOpacity(0.4)),
              style: const TextStyle(color: Colors.white),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
          const SizedBox(width: 10),
          CupertinoButton(
            padding: EdgeInsets.zero,
            color: Colors.cyanAccent.withOpacity(0.2),
            onPressed: _sendMessage,
            borderRadius: BorderRadius.circular(20),
            child: const Icon(CupertinoIcons.arrow_up_circle_fill, color: Colors.cyanAccent),
          )
        ],
      ),
    );
  }
}
EOF

# 4. Generate GitHub Actions Workflow for AltStore
echo "🔹 Creating GitHub Workflow (.github/workflows/altstore_build.yml)..."
mkdir -p .github/workflows

cat > .github/workflows/altstore_build.yml <<EOF
name: Build iOS IPA (No-Codesign)

on:
  push:
    branches: [ "main" ]
  workflow_dispatch:

jobs:
  build_ios_unsigned:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2
        with:
          channel: 'stable'
          
      - name: Install Dependencies
        working-directory: ./client
        run: flutter pub get

      - name: Build iOS (No Codesign)
        working-directory: ./client
        run: |
          flutter build ios --release --no-codesign
          
      - name: Package IPA (Payload Method)
        run: |
          mkdir Payload
          # Move the built .app into Payload
          mv client/build/ios/iphoneos/Runner.app Payload/
          # Zip it up
          zip -r burner_chat.ipa Payload
          
      - name: Upload IPA Artifact
        uses: actions/upload-artifact@v3
        with:
          name: burner-chat-ipa
          path: burner_chat.ipa
EOF

# 5. Git Commit & Instructions
echo "🔹 Preparing Git Commit..."
git add .
git commit -m "feat: setup cloud build and liquid glass UI" || echo "Nothing to commit or working tree clean."

echo "--------------------------------------------------------"
echo "✅ SETUP COMPLETE!"
echo "To push this to your repository, run the following manually:"
echo ""
echo "  git remote remove origin 2>/dev/null || true"
echo "  git remote add origin https://ibrhaimathornpiper@github.com/ibrahimathornpiper/hashchat.git"
echo "  git branch -M main"
echo "  git push -u origin main"
echo ""
echo "⚠️  NOTE: The Token provided will handle authentication automatically."
echo "--------------------------------------------------------"
