import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../config/api_config.dart';
import 'package:dio/dio.dart';
import 'dart:convert';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isLoading = false;
  String? _currentModel;
  String? _apiKey;
  String? _baseUrl;

  @override
  void initState() {
    super.initState();
    _loadConfig();
    _addWelcomeMessage();
  }

  void _loadConfig() async {
    final storage = StorageService();
    final model = await storage.getAiModel();
    final key = await storage.getAIKey();
    final url = await storage.getAIBaseUrl();
    setState(() {
      _currentModel = model;
      _apiKey = key;
      _baseUrl = url;
    });
  }

  void _addWelcomeMessage() {
    setState(() {
      _messages.add({
        'role': 'assistant',
        'content': '你好！我是序言 AI 助手 🐶\n有什么可以帮你的吗？',
        'time': DateTime.now(),
      });
    });
  }

  Future<void> _sendMessage() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({
        'role': 'user',
        'content': text,
        'time': DateTime.now(),
      });
      _isLoading = true;
    });
    _inputController.clear();

    _scrollToBottom();

    try {
      // 构建消息列表
      final List<Map<String, String>> apiMessages = _messages
          .where((m) => m['role'] != null)
          .map((m) => {
                'role': m['role'] as String,
                'content': m['content'] as String,
              })
          .toList();

      final dio = Dio();
      final baseUrl = _baseUrl?.isNotEmpty == true ? _baseUrl! : 'https://integrate.api.nvidia.com/v1';
      final model = _currentModel?.isNotEmpty == true ? _currentModel! : 'meta/llama-3.1-8b-instruct';
      final apiKey = _apiKey?.isNotEmpty == true ? _apiKey! : null;
      if (apiKey == null) {
        setState(() { _isLoading = false; });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('请先在设置中配置AI密钥')),
          );
        }
        return;
      }

      final response = await dio.post(
        '$baseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          receiveTimeout: Duration(seconds: 60),
        ),
        data: {
          'model': model,
          'messages': apiMessages,
          'temperature': 0.7,
          'max_tokens': 1024,
        },
      );

      final reply = response.data['choices'][0]['message']['content'];
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': reply,
          'time': DateTime.now(),
        });
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _messages.add({
          'role': 'assistant',
          'content': '抱歉，请求出错了：${e.toString().length > 100 ? e.toString().substring(0, 100) : e}',
          'time': DateTime.now(),
        });
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF5B8DB8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 助手', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isUser = msg['role'] == 'user';
                return _buildMessageBubble(msg, isUser, isDark, primaryColor);
              },
            ),
          ),
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                  ),
                  const SizedBox(width: 8),
                  Text('AI 正在思考...', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                ],
              ),
            ),
          _buildInputArea(isDark, primaryColor),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isUser, bool isDark, Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            CircleAvatar(radius: 16, backgroundColor: primaryColor.withOpacity(0.1), child: Icon(Icons.smart_toy, size: 18, color: primaryColor)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser ? primaryColor : (isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5)),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                  bottomLeft: isUser ? Radius.circular(16) : Radius.circular(4),
                  bottomRight: isUser ? Radius.circular(4) : Radius.circular(16),
                ),
              ),
              child: Text(
                msg['content'],
                style: TextStyle(
                  fontSize: 15,
                  color: isUser ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(radius: 16, backgroundColor: Colors.grey[300], child: Icon(Icons.person, size: 18, color: Colors.grey[600])),
          ],
        ],
      ),
    );
  }

  Widget _buildInputArea(bool isDark, Color primaryColor) {
    return Container(
      padding: EdgeInsets.only(left: 16, right: 8, top: 8, bottom: MediaQuery.of(context).padding.bottom + 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _inputController,
              maxLines: 4,
              minLines: 1,
              decoration: InputDecoration(
                hintText: '和 AI 聊聊天...',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              ),
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: primaryColor),
            onPressed: _sendMessage,
          ),
        ],
      ),
    );
  }
}
