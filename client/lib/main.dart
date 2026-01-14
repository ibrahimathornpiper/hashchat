import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:glassmorphism/glassmorphism.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:local_auth/local_auth.dart';
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
        primaryColor: const Color(0xFF00FF41),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF00FF41),
          secondary: Color(0xFF008F11),
          surface: Colors.black,
          background: Colors.black,
        ),
        textTheme: GoogleFonts.firaCodeTextTheme(ThemeData.dark().textTheme).apply(
          bodyColor: const Color(0xFF00FF41),
          displayColor: const Color(0xFF00FF41),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF00FF41)),
      ),
      home: const AuthScreen(),
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  bool _isAuthenticating = false;
  String _authStatus = "Identity Verification Required";

  @override
  void initState() {
    super.initState();
    _authenticate();
  }

  Future<void> _authenticate() async {
    bool authenticated = false;
    try {
      setState(() {
        _isAuthenticating = true;
        _authStatus = "Scanning Biometrics...";
      });
      
      final bool canAuthenticateWithBiometrics = await auth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await auth.isDeviceSupported();

      if (!canAuthenticate) {
        // Fallback for emulators or devices without biometrics
        setState(() => _authStatus = "Biometrics Unavailable. Bypassing (Dev Mode)...");
        await Future.delayed(const Duration(seconds: 1));
        authenticated = true;
      } else {
        authenticated = await auth.authenticate(
          localizedReason: 'Scan FaceID/TouchID to access Secure Terminal',
          options: const AuthenticationOptions(
            stickyAuth: true,
            biometricOnly: false, // Allow PIN
          ),
        );
      }
    } on PlatformException catch (e) {
      setState(() => _authStatus = "Error: ${e.message}");
      return;
    } finally {
      setState(() => _isAuthenticating = false);
    }

    if (authenticated) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const RootScreen()),
        );
      }
    } else {
      setState(() => _authStatus = "Access Denied.");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 80, color: Color(0xFF00FF41)),
            const SizedBox(height: 20),
            Text(
              "HASHCHAT // SECURE TERMINAL",
              style: GoogleFonts.firaCode(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF00FF41),
              ),
            ),
            const SizedBox(height: 40),
            if (_isAuthenticating)
              const CircularProgressIndicator(color: Color(0xFF00FF41)),
            const SizedBox(height: 20),
            Text(
              _authStatus,
              style: GoogleFonts.firaCode(color: Colors.white54),
            ),
            if (!_isAuthenticating && _authStatus == "Access Denied.")
              TextButton(
                onPressed: _authenticate,
                child: Text("Retry", style: GoogleFonts.firaCode(color: const Color(0xFF00FF41))),
              )
          ],
        ),
      ),
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
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _buildBackground(),
          Center(
            child: Container(
              width: 350,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.black,
                border: Border.all(color: const Color(0xFF00FF41), width: 2),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00FF41).withOpacity(0.2), blurRadius: 20, spreadRadius: 2)
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(">> HASHCHAT_INIT", 
                    style: GoogleFonts.firaCode(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFF00FF41))),
                  const SizedBox(height: 10),
                  Text("[SECURE] [DECENTRALIZED] [UNSTOPPABLE]", 
                    textAlign: TextAlign.center,
                    style: GoogleFonts.firaCode(color: const Color(0xFF008F11), fontSize: 10)),
                  const SizedBox(height: 20),
                  Consumer<ChatService>(
                    builder: (_, chat, __) {
                      final balance = double.tryParse(chat.balance) ?? 0.0;
                      return Column(
                        children: [
                          Text(
                            "BALANCE: ${chat.balance} MATIC",
                            style: GoogleFonts.firaCode(
                              color: balance > 0.001 ? const Color(0xFF00FF41) : Colors.redAccent,
                              fontSize: 12,
                            ),
                          ),
                          if (balance < 0.01)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.orangeAccent,
                                  side: const BorderSide(color: Colors.orangeAccent),
                                ),
                                child: Text("REQ_GAS()", style: GoogleFonts.firaCode(fontSize: 12)),
                                onPressed: () async {
                                  setState(() => _loading = true);
                                  final success = await chat.claimTokens();
                                  setState(() => _loading = false);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        backgroundColor: Colors.black,
                                        content: Text(
                                          success ? "> GAS_SENT: WAIT" : "> ERROR: GAS_FAILED",
                                          style: GoogleFonts.firaCode(color: const Color(0xFF00FF41)),
                                        )
                                      )
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
                                SnackBar(
                                  backgroundColor: Colors.black,
                                  content: Text("> ADDR_COPIED", style: GoogleFonts.firaCode(color: const Color(0xFF00FF41)))
                                )
                              );
                            },
                            child: Text(
                              "ADDR: ${chat.myAddress?.substring(0, 6)}...${chat.myAddress?.substring(chat.myAddress!.length - 4)}",
                              style: GoogleFonts.firaCode(color: Colors.white54, fontSize: 10, decoration: TextDecoration.underline),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _nameController,
                    style: GoogleFonts.firaCode(color: const Color(0xFF00FF41)),
                    cursorColor: const Color(0xFF00FF41),
                    decoration: InputDecoration(
                      hintText: "ENTER_CODENAME",
                      hintStyle: GoogleFonts.firaCode(color: const Color(0xFF008F11)),
                      enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF008F11))),
                      focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF41))),
                      filled: true,
                      fillColor: const Color(0xFF0D0208),
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_loading) 
                    const CircularProgressIndicator(color: Color(0xFF00FF41))
                  else
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF00FF41),
                          side: const BorderSide(color: Color(0xFF00FF41)),
                          padding: const EdgeInsets.all(16),
                        ),
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
                        child: Text("REGISTER_IDENTITY()", style: GoogleFonts.firaCode(fontWeight: FontWeight.bold)),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      color: Colors.black,
      child: Center(
        child: Opacity(
          opacity: 0.05,
          child: Text(
            "101010101010101010101010\n010101010101010101010101\n101010101010101010101010",
            style: GoogleFonts.firaCode(fontSize: 40, color: Colors.green),
            textAlign: TextAlign.center,
          ),
        ),
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

  void _showNewChat() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(0)),
        side: BorderSide(color: Color(0xFF00FF41)),
      ),
      builder: (ctx) => Container(
        height: 300,
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text("INIT_SECURE_CHANNEL()", style: GoogleFonts.firaCode(fontSize: 18, fontWeight: FontWeight.bold, color: const Color(0xFF00FF41))),
            const SizedBox(height: 20),
            TextField(
              controller: _targetController,
              style: GoogleFonts.firaCode(color: const Color(0xFF00FF41)),
              cursorColor: const Color(0xFF00FF41),
              decoration: InputDecoration(
                hintText: "TARGET_CODENAME",
                hintStyle: GoogleFonts.firaCode(color: const Color(0xFF008F11)),
                enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF008F11))),
                focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF00FF41))),
                filled: true,
                fillColor: const Color(0xFF0D0208),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF00FF41),
                  side: const BorderSide(color: Color(0xFF00FF41)),
                  padding: const EdgeInsets.all(16),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _openChat(_targetController.text);
                },
                child: Text("OPEN_CHANNEL", style: GoogleFonts.firaCode(fontWeight: FontWeight.bold)),
              ),
            )
          ],
        ),
      ),
    );
  }

  void _showGasPopup(BuildContext context, ChatService chat) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape:  Border.all(color: const Color(0xFF00FF41)),
        title: Text("WALLET_STATUS", style: GoogleFonts.firaCode(color: const Color(0xFF00FF41))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("BALANCE: ${chat.balance} POL", style: GoogleFonts.firaCode(color: Colors.white)),
            const SizedBox(height: 10),
            Text("PUBLIC_KEY:", style: GoogleFonts.firaCode(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF008F11))),
            SelectableText(
              chat.myAddress ?? "",
              style: GoogleFonts.firaCode(fontSize: 10, color: const Color(0xFF00FF41)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            child: Text("COPY_ADDR", style: GoogleFonts.firaCode(color: const Color(0xFF00FF41))),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: chat.myAddress ?? ""));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Address copied!"))
              );
            },
          ),
          TextButton(
            child: Text("REQ_GAS", style: GoogleFonts.firaCode(color: Colors.orangeAccent)),
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
          TextButton(
            child: Text("CLOSE", style: GoogleFonts.firaCode(color: Colors.white54)),
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("HASHCHAT // ${chat.username}", style: GoogleFonts.firaCode(fontSize: 18, color: const Color(0xFF00FF41))),
        backgroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: const Color(0xFF008F11), height: 1)),
        actions: [
          if (balance < 0.01)
             IconButton(
               onPressed: () => _showGasPopup(context, chat),
               icon: const Icon(Icons.local_gas_station, color: Colors.redAccent)
             ),
          IconButton(
            onPressed: _showNewChat, 
            icon: const Icon(Icons.add_circle_outline, color: Color(0xFF00FF41))
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBackground(),
          ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: chat.messages.length,
            itemBuilder: (ctx, i) {
              final msg = chat.messages[i];
              return _buildChatTile(msg);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildChatTile(ChatMessage msg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.black,
        border: Border.all(color: const Color(0xFF008F11)),
        boxShadow: [BoxShadow(color: const Color(0xFF00FF41).withOpacity(0.05), blurRadius: 5)],
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF00FF41)),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.person_outline, color: Color(0xFF00FF41)),
        ),
        title: Text(msg.receiver.substring(0, 8), style: GoogleFonts.firaCode(fontWeight: FontWeight.bold, color: const Color(0xFF00FF41))),
        subtitle: Text(msg.content, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.firaCode(color: Colors.white70)),
        trailing: Text(DateFormat('HH:mm').format(msg.timestamp), style: GoogleFonts.firaCode(fontSize: 10, color: const Color(0xFF008F11))),
        onTap: () => _openChat("User"), // Logic to get nickname
      ),
    );
  }

  Widget _buildBackground() {
    return Container(
      color: Colors.black,
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text("TARGET: ${widget.nickname}", style: GoogleFonts.firaCode(color: const Color(0xFF00FF41))),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Color(0xFF00FF41)),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(color: const Color(0xFF008F11), height: 1)),
      ),
      body: Column(
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
          color: msg.isMe ? const Color(0xFF00FF41).withOpacity(0.1) : Colors.white10,
          border: Border.all(color: msg.isMe ? const Color(0xFF00FF41) : Colors.white24),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(15),
            topRight: const Radius.circular(15),
            bottomLeft: msg.isMe ? const Radius.circular(15) : Radius.zero,
            bottomRight: msg.isMe ? Radius.zero : const Radius.circular(15),
          ),
        ),
        child: Text(msg.content, style: GoogleFonts.firaCode(color: Colors.white)),
      ),
    );
  }

  Widget _buildInput(ChatService chat) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.black,
        border: Border(top: BorderSide(color: Color(0xFF008F11))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _msgController,
                style: GoogleFonts.firaCode(color: const Color(0xFF00FF41)),
                cursorColor: const Color(0xFF00FF41),
                decoration: InputDecoration(
                  hintText: "INSERT_PAYLOAD...",
                  hintStyle: GoogleFonts.firaCode(color: const Color(0xFF008F11)),
                  filled: true,
                  fillColor: const Color(0xFF0D0208),
                  border: const OutlineInputBorder(borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 10),
            IconButton(
              onPressed: () async {
                if (_msgController.text.isEmpty) return;
                final text = _msgController.text;
                _msgController.clear();
                await chat.sendMessage(widget.nickname, text);
              },
              icon: const Icon(Icons.send, color: Color(0xFF00FF41)),
            )
          ],
        ),
      ),
    );
  }
}