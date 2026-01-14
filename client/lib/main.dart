import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'chat_service.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => ChatService(),
      child: const HashChatApp(),
    ),
  );
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
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
      ),
      home: const RootScreen(),
    );
  }
}

class RootScreen extends StatelessWidget {
  const RootScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatService>();
    
    if (chat.myAddress == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!chat.isRegistered) {
      return const RegistrationScreen();
    }

    return const ChatListScreen();
  }
}

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _buildBackground(),
          Center(
            child: GlassmorphicContainer(
              width: 350,
              height: 400,
              borderRadius: 30,
              blur: 20,
              alignment: Alignment.center,
              border: 2,
              linearGradient: LinearGradient(
                colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]
              ),
              borderGradient: LinearGradient(
                colors: [Colors.cyanAccent.withOpacity(0.5), Colors.purpleAccent.withOpacity(0.5)]
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text("Welcome to HashChat", 
                      style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    const Text("Secure, Decentralized, Unstoppable.", 
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70)),
                    const SizedBox(height: 10),
                    Consumer<ChatService>(
                      builder: (_, chat, __) {
                        final balance = double.tryParse(chat.balance) ?? 0.0;
                        return Column(
                          children: [
                            Text(
                              "Balance: ${chat.balance} Amoy MATIC",
                              style: TextStyle(
                                color: balance > 0.001 ? Colors.greenAccent : Colors.redAccent,
                                fontSize: 12,
                              ),
                            ),
                            if (balance < 0.01)
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: CupertinoButton(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  color: Colors.orangeAccent.withOpacity(0.2),
                                  child: const Text("Get Free Gas", style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                                  onPressed: () async {
                                    setState(() => _loading = true);
                                    final success = await chat.claimTokens();
                                    setState(() => _loading = false);
                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(success ? "Gas Sent! Wait a moment..." : "Failed to get gas. Try again later."))
                                      );
                                    }
                                  },
                                ),
                              ),
                            const SizedBox(height: 12),
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: chat.myAddress ?? ""));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("Address copied to clipboard"))
                                );
                              },
                              child: Text(
                                "Address: ${chat.myAddress?.substring(0, 6)}...${chat.myAddress?.substring(chat.myAddress!.length - 4)}",
                                style: const TextStyle(color: Colors.white54, fontSize: 10, decoration: TextDecoration.underline),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    CupertinoTextField(
                      controller: _nameController,
                      placeholder: "Enter Nickname",
                      placeholderStyle: const TextStyle(color: Colors.white38),
                      style: const TextStyle(color: Colors.white),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_loading) 
                      const CircularProgressIndicator()
                    else
                      SizedBox(
                        width: double.infinity,
                        child: CupertinoButton(
                          color: Colors.cyanAccent.withOpacity(0.2),
                          onPressed: () async {
                            setState(() => _loading = true);
                            try {
                              await context.read<ChatService>().register(_nameController.text);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text("Error: $e"))
                              );
                            }
                            setState(() => _loading = false);
                          },
                          child: const Text("Register Identity", style: TextStyle(color: Colors.cyanAccent)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        )
      ),
    );
  }
}

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  final TextEditingController _targetController = TextEditingController();
  final TextEditingController _msgController = TextEditingController();

  void _showNewChat() {
    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        height: 300,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2735),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: Column(
          children: [
            const Text("Start Secure Chat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            CupertinoTextField(
              controller: _targetController,
              placeholder: "Recipient Nickname",
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(15),
              ),
            ),
            const SizedBox(height: 20),
            CupertinoButton.filled(
              onPressed: () {
                Navigator.pop(ctx);
                _openChat(_targetController.text);
              },
              child: const Text("Open Channel"),
            )
          ],
        ),
      ),
    );
  }

  void _showGasPopup(BuildContext context, ChatService chat) {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text("Wallet Status"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Text("Balance: ${chat.balance} POL"),
            const SizedBox(height: 10),
            const Text("Your Public Address:", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            SelectableText(
              chat.myAddress ?? "",
              style: const TextStyle(fontSize: 10, color: Colors.cyanAccent),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text("Copy Address"),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: chat.myAddress ?? ""));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Address copied!"))
              );
            },
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text("Get Free Gas"),
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await chat.claimTokens();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(success ? "Refill on the way!" : "Refill failed."))
                );
              }
            },
          ),
          CupertinoDialogAction(
            child: const Text("Close"),
            onPressed: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _openChat(String nickname) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ChatDetailScreen(nickname: nickname)));
  }

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatService>();
    final balance = double.tryParse(chat.balance) ?? 0.0;
    
    return Scaffold(
      appBar: AppBar(
        title: Text("HashChat // ${chat.username}", style: GoogleFonts.outfit(fontSize: 18)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (balance < 0.01)
             IconButton(
               onPressed: () => _showGasPopup(context, chat),
               icon: const Icon(CupertinoIcons.drop_fill, color: Colors.redAccent)
             ),
          IconButton(onPressed: _showNewChat, icon: const Icon(CupertinoIcons.add_circled)),
        ],
      ),
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          _buildBackground(),
          SafeArea(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: chat.messages.length,
              itemBuilder: (ctx, i) {
                final msg = chat.messages[i];
                return _buildChatTile(msg);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 70,
        borderRadius: 15,
        blur: 10,
        alignment: Alignment.centerLeft,
        border: 1,
        linearGradient: LinearGradient(colors: [Colors.white.withOpacity(0.1), Colors.white.withOpacity(0.05)]),
        borderGradient: LinearGradient(colors: [Colors.white24, Colors.transparent]),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: Colors.cyanAccent.withOpacity(0.2),
            child: const Icon(CupertinoIcons.person, color: Colors.cyanAccent),
          ),
          title: Text(msg.receiver.substring(0, 8), style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text(msg.content, maxLines: 1, overflow: TextOverflow.ellipsis),
          trailing: Text(DateFormat('HH:mm').format(msg.timestamp), style: const TextStyle(fontSize: 10, color: Colors.white54)),
          onTap: () => _openChat("User"), // Logic to get nickname
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
        )
      ),
    );
  }
}

class ChatDetailScreen extends StatefulWidget {
  final String nickname;
  const ChatDetailScreen({super.key, required this.nickname});

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _msgController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final chat = context.watch<ChatService>();
    final messages = chat.messages.where((m) => true).toList(); // Simplified filter

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.nickname),
        backgroundColor: Colors.black54,
      ),
      body: Stack(
        children: [
          Container(color: const Color(0xFF0F2027)),
          Column(
            children: [
              Expanded(
                child: ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (ctx, i) {
                    final msg = messages[i];
                    return _buildBubble(msg);
                  },
                ),
              ),
              _buildInput(chat),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBubble(ChatMessage msg) {
    return Align(
      alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: const BoxConstraints(maxWidth: 250),
        decoration: BoxDecoration(
          color: msg.isMe ? Colors.cyanAccent.withOpacity(0.2) : Colors.white10,
          borderRadius: BorderRadius.circular(15).copyWith(
            bottomRight: msg.isMe ? Radius.zero : const Radius.circular(15),
            bottomLeft: msg.isMe ? const Radius.circular(15) : Radius.zero,
          ),
        ),
        child: Text(msg.content),
      ),
    );
  }

  Widget _buildInput(ChatService chat) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black26,
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: CupertinoTextField(
                controller: _msgController,
                placeholder: "Secure Message...",
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
            const SizedBox(width: 10),
            CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () async {
                if (_msgController.text.isEmpty) return;
                final text = _msgController.text;
                _msgController.clear();
                await chat.sendMessage(widget.nickname, text);
              },
              child: const Icon(CupertinoIcons.arrow_up_circle_fill, size: 40, color: Colors.cyanAccent),
            )
          ],
        ),
      ),
    );
  }
}