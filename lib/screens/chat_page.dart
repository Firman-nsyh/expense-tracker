import 'package:flutter/material.dart';
import '../services/database_helper.dart';
import '../services/gemini_service.dart';

class ChatPageContent extends StatefulWidget {
  const ChatPageContent({super.key});

  @override
  State<ChatPageContent> createState() => _ChatPageContentState();
}

class _ChatPageContentState extends State<ChatPageContent> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  final List<Map<String, dynamic>> _messages = [
    {'text': 'Halo! Aku Moly, asisten keuanganmu. Ada yang ingin ditanyakan soal pengeluaranmu?', 'isBot': true}
  ];
  
  bool _isLoading = false;

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({'text': text, 'isBot': false});
      _isLoading = true;
    });
    _messageController.clear();
    _scrollToBottom();

    final transactions = await DatabaseHelper.instance.getAllTransactions();
    final reply = await GeminiService.instance.askFinancialQuestion(text, transactions);

    if (mounted) {
      setState(() {
        _messages.add({'text': reply, 'isBot': true});
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // ---> INI KUNCI SOLUSINYA <---
    // Deteksi tinggi keyboard. Jika keyboard terbuka, nilainya > 0.
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    
    // Jika keyboard terbuka, padding bawah menyesuaikan tinggi keyboard + 16px.
    // Jika tertutup, padding bawah 120px agar tidak tertutup Glass Navbar.
    final bottomPadding = keyboardHeight > 0 ? keyboardHeight + 16 : 120.0;

    return SafeArea(
      // Matikan SafeArea bawah agar kita bisa mengontrol padding manual dengan presisi
      bottom: false, 
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(children: [
              Icon(Icons.smart_toy, color: Colors.blueAccent),
              SizedBox(width: 12),
              Text("AI Assistant",
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold))
            ]),
          ),
          
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isBot = msg['isBot'] as bool;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: isBot 
                      ? _buildBotBubble(msg['text']) 
                      : _buildUserBubble(msg['text']),
                );
              },
            ),
          ),

          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: CircularProgressIndicator(color: Colors.blueAccent),
            ),

          // ---> MENGGUNAKAN PADDING DINAMIS <---
          AnimatedPadding(
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
            padding: EdgeInsets.fromLTRB(20, 0, 20, bottomPadding),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        hintText: "Tanya pengeluaran terbesarku...",
                        hintStyle: TextStyle(color: Colors.white38),
                        border: InputBorder.none,
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      // Gulir ke bawah otomatis saat kolom teks diklik (keyboard muncul)
                      onTap: () {
                        Future.delayed(const Duration(milliseconds: 300), _scrollToBottom);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _isLoading ? null : _sendMessage,
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: const BoxDecoration(
                        color: Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send, color: Colors.white, size: 20),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBotBubble(String message) => Align(
    alignment: Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(right: 60),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16).copyWith(bottomLeft: Radius.zero),
        border: Border.all(color: Colors.white10)
      ),
      child: Text(message, style: const TextStyle(color: Colors.white, height: 1.4)),
    ),
  );

  Widget _buildUserBubble(String message) => Align(
    alignment: Alignment.centerRight,
    child: Container(
      margin: const EdgeInsets.only(left: 60),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueAccent,
        borderRadius: BorderRadius.circular(16).copyWith(bottomRight: Radius.zero),
      ),
      child: Text(message, style: const TextStyle(color: Colors.white, height: 1.4)),
    ),
  );
}