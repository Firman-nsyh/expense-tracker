import 'package:flutter/material.dart';

class ChatPageContent extends StatelessWidget {
  const ChatPageContent({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Column(children: [
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
          ])),
      Expanded(
          child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
            _buildBotBubble("Halo! Ada yang bisa saya bantu?"),
            const SizedBox(height: 16),
            _buildUserBubble("Buatkan laporan bulan ini")
          ])),
      const SizedBox(height: 120)
    ]));
  }

  Widget _buildBotBubble(String message) => Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(16)),
      child: Text(message, style: const TextStyle(color: Colors.white)));

  Widget _buildUserBubble(String message) => Align(
      alignment: Alignment.centerRight,
      child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.blueAccent,
              borderRadius: BorderRadius.circular(16)),
          child: Text(message, style: const TextStyle(color: Colors.white))));
}