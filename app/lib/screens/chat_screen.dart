import 'dart:async';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../models/message_model.dart';
import '../providers/chat_provider.dart';
import '../providers/contact_provider.dart';
import '../services/storage_service.dart';
import '../config/constants.dart';
import '../widgets/message_bubble.dart';
import '../widgets/chat_input.dart';
import '../widgets/avatar.dart';

class ChatScreen extends StatefulWidget {
  final String friendId;
  final String friendName;
  final String? friendAvatar;

  const ChatScreen({
    super.key,
    required this.friendId,
    required this.friendName,
    this.friendAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _isAiLoading = false;
  List<String> _aiSuggestions = [];
  bool _showEmoji = false;
  int _aiMode = 0; // 0=关闭, 1=半自动, 2=全自动
  final ScrollController _scrollController = ScrollController();
  Timer? _typingTimer;
  bool _isRecording = false;
  StreamSubscription? _messageSubscription;
  Timer? _autoReplyTimer;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // 半自动模式：监听新消息刷新建议
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = _chatProvider;
      if (chatProvider != null) {
        chatProvider.messageStream.listen((message) {
          if (_aiMode == 1 && message.senderId == widget.friendId && mounted) {
            _generateAiSuggestions();
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _chatProvider?.sendTypingStatus(widget.friendId, false);
    _typingTimer?.cancel();
    _scrollController.dispose();
    _autoReplyTimer?.cancel();
    _messageSubscription?.cancel();
    super.dispose();
  }

  ChatProvider? get _chatProvider {
    try {
      return Provider.of<ChatProvider>(context, listen: false);
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadMessages() async {
    final chatProvider = _chatProvider;
    if (chatProvider == null) return;
    await chatProvider.loadMessages(widget.friendId);
    chatProvider.markAsRead(widget.friendId);
    _scrollToBottom();
  }

  void _clearChatHistory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认清空'),
        content: const Text('确定要清空与该好友的聊天记录吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final chatProvider = _chatProvider;
      if (chatProvider != null) {
        await chatProvider.clearMessages(widget.friendId);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('聊天记录已清空')),
          );
        }
      }
    }
  }

  void _startRecording() {
    setState(() => _isRecording = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('录音功能开发中...')),
    );
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) setState(() => _isRecording = false);
    });
  }

  void _stopRecording() {
    setState(() => _isRecording = false);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage(String text) {
    if (text.isEmpty) return;
    final chatProvider = _chatProvider;
    if (chatProvider == null) return;
    
    // 用户手动发消息时，如果是全自动模式则切回半自动
    if (_aiMode == 2) {
      setState(() => _aiMode = 1);
    }
    
    chatProvider.sendMessage(
      friendId: widget.friendId,
      type: AppConstants.messageTypeText,
      content: text,
    );
    _scrollToBottom();
  }

  void _sendImage(String filePath) async {
    final chatProvider = _chatProvider;
    if (chatProvider == null) return;
    final mediaUrl = await chatProvider.uploadMedia(filePath, type: 'image');
    if (mediaUrl != null) {
      chatProvider.sendMessage(
        friendId: widget.friendId,
        type: AppConstants.messageTypeImage,
        content: '[图片]',
        mediaUrl: mediaUrl,
      );
      _scrollToBottom();
    }
  }

  void _showEmojiPicker() {
    setState(() => _showEmoji = !_showEmoji);
  }

  void _onTextChanged(String text) {
    if (text.isNotEmpty) {
      _chatProvider?.sendTypingStatus(widget.friendId, true);
      _typingTimer?.cancel();
      _typingTimer = Timer(const Duration(seconds: 3), () {
        _chatProvider?.sendTypingStatus(widget.friendId, false);
      });
    } else {
      _chatProvider?.sendTypingStatus(widget.friendId, false);
    }
  }

  Widget _buildEmojiPicker(bool isDark) {
    return Container(
      height: 250,
      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      child: GridView.builder(
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          childAspectRatio: 1,
        ),
        itemCount: EmojiData.basicEmojis.length,
        itemBuilder: (context, index) {
          final emoji = EmojiData.basicEmojis[index];
          return InkWell(
            onTap: () => _insertEmoji(emoji),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 24)),
            ),
          );
        },
      ),
    );
  }

  void _insertEmoji(String emoji) {
    setState(() => _showEmoji = false);
    _sendMessage(emoji);
  }

  /// 切换AI模式：0=关闭 → 1=半自动 → 2=全自动 → 0
  void _toggleAiMode() {
    setState(() {
      _aiMode = (_aiMode + 1) % 3;
    });
    
    if (_aiMode == 1) {
      // 半自动：立即生成建议
      _generateAiSuggestions();
    } else if (_aiMode == 2) {
      // 全自动：清除建议卡片，开始监听
      _aiSuggestions = [];
      _listenForAutoReply();
    } else {
      // 关闭
      _aiSuggestions = [];
      _autoReplyTimer?.cancel();
      _messageSubscription?.cancel();
    }
  }

  /// 半自动模式：生成AI建议
  Future<void> _generateAiSuggestions() async {
    final chatProvider = _chatProvider;
    if (chatProvider == null) return;
    
    final messages = chatProvider.getMessages(widget.friendId);
    final recentMessages = messages.take(10).toList().reversed.toList();
    
    if (recentMessages.isEmpty) {
      setState(() => _aiSuggestions = ['你好👋', '在吗？', '最近怎么样？']);
      return;
    }

    setState(() => _isAiLoading = true);

    try {
      final storage = StorageService();
      final apiKey = await storage.getAIKey();
      final baseUrl = await storage.getAIBaseUrl();

      final dio = Dio();
      final effectiveBaseUrl = baseUrl?.isNotEmpty == true 
          ? baseUrl! 
          : 'https://integrate.api.nvidia.com/v1';
      final effectiveApiKey = apiKey?.isNotEmpty == true 
          ? apiKey! 
          : null;

      if (effectiveApiKey == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先在设置中配置AI密钥')),
        );
        return;
      }

      final conversationContext = recentMessages.map((m) {
        final role = m.isMe ? '我' : widget.friendName;
        return '$role: ${m.content}';
      }).join('\n');

      final response = await dio.post(
        '$effectiveBaseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $effectiveApiKey',
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 15),
        ),
        data: {
          'model': 'qwen/qwen3.5-122b-a10b',
          'messages': [
            {
              'role': 'system',
              'content': '你是聊天助手。根据以下聊天记录，为用户生成3个简短自然的回复建议（每条不超过20个字），直接用换行符分隔输出，不要编号不要前缀。',
            },
            {
              'role': 'user',
              'content': '聊天记录:\n$conversationContext\n\n请生成3个回复建议:',
            },
          ],
          'temperature': 0.7,
          'max_tokens': 256,
        },
      );

      final choices = response.data['choices'] as List?;
      if (choices == null || choices.isEmpty) {
        if (mounted) setState(() => _aiSuggestions = ['好的👍', '收到', '嗯嗯']);
        return;
      }
      final reply = (choices[0]['message']['content'] as String? ?? '');
      final suggestions = reply
          .split('\n')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .take(3)
          .toList();

      if (suggestions.isNotEmpty && mounted) {
        setState(() => _aiSuggestions = suggestions);
      } else if (mounted) {
        setState(() => _aiSuggestions = ['好的👍', '收到', '嗯嗯']);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _aiSuggestions = ['好的👍', '收到', '嗯嗯']);
      }
    } finally {
      if (mounted) {
        setState(() => _isAiLoading = false);
      }
    }
  }

  /// 全自动模式：监听新消息并自动回复
  void _listenForAutoReply() {
    final chatProvider = _chatProvider;
    if (chatProvider == null) return;
    
    _messageSubscription = chatProvider.messageStream.listen((message) {
      // 只自动回复对方发的消息（非我发送的消息）
      if (message.isMe) return;
      // 确保是当前聊天对象的消息
      if (message.senderId != widget.friendId) return;
      // 循环检测：如果对方消息是AI自动发的，不回复
      if (message.mediaMeta?['autoReply'] == true) return;
      
      // 延迟2-4秒模拟"正在输入"
      _autoReplyTimer?.cancel();
      final delay = 2 + (message.content.length % 3);
      _autoReplyTimer = Timer(Duration(seconds: delay), () {
        _autoReplyToMessage(message);
      });
    });
  }

  /// 全自动：AI自动回复
  Future<void> _autoReplyToMessage(MessageModel message) async {
    if (_aiMode != 2) return; // 确认仍在全自动模式
    
    final chatProvider = _chatProvider;
    if (chatProvider == null) return;
    
    try {
      final storage = StorageService();
      final apiKey = await storage.getAIKey();
      final baseUrl = await storage.getAIBaseUrl();

      final dio = Dio();
      final effectiveBaseUrl = baseUrl?.isNotEmpty == true 
          ? baseUrl! 
          : 'https://integrate.api.nvidia.com/v1';
      final effectiveApiKey = apiKey?.isNotEmpty == true 
          ? apiKey! 
: null;

      if (apiKey?.isNotEmpty != true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('请先在设置中配置AI密钥')),
        );
        return;
      }

      final messages = chatProvider.getMessages(widget.friendId);
      final recentMessages = messages.take(10).toList().reversed.toList();
      
      final conversationContext = recentMessages.map((m) {
        final role = m.isMe ? '我' : widget.friendName;
        return '$role: ${m.content}';
      }).join('\n');

      final response = await dio.post(
        '$effectiveBaseUrl/chat/completions',
        options: Options(
          headers: {
            'Authorization': 'Bearer $effectiveApiKey',
            'Content-Type': 'application/json',
          },
          receiveTimeout: const Duration(seconds: 15),
        ),
        data: {
          'model': 'qwen/qwen3.5-122b-a10b',
          'messages': [
            {
              'role': 'system',
              'content': '你是用户的聊天助手。根据聊天记录，生成一个简短自然的回复（不超过30字）。直接输出回复内容，不要加引号、编号或前缀。',
            },
            {
              'role': 'user',
              'content': '聊天记录:\n$conversationContext\n\n请生成回复:',
            },
          ],
          'temperature': 0.8,
          'max_tokens': 128,
        },
      );

      final reply = response.data['choices'][0]['message']['content'] as String;
      final trimmed = reply.trim();
      
      if (trimmed.isNotEmpty) {
        chatProvider.sendMessage(
          friendId: widget.friendId,
          type: AppConstants.messageTypeText,
          content: trimmed,
          mediaMeta: {'autoReply': true}, // 标记AI自动回复
        );
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Auto reply failed: $e');
    }
  }

  /// 构建半自动模式的悬浮建议卡片
  Widget _buildSuggestionCard(bool isDark) {
    if (_aiMode != 1 || (_aiSuggestions.isEmpty && !_isAiLoading)) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF0F4F8),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF5B8DB8).withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: _isAiLoading
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(8),
                child: SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _aiSuggestions.map((suggestion) {
                return ActionChip(
                  label: Text(suggestion, style: const TextStyle(fontSize: 13)),
                  onPressed: () {
                    _sendMessage(suggestion);
                    // 发送后刷新建议
                    _generateAiSuggestions();
                  },
                  backgroundColor: isDark ? const Color(0xFF3A3A4E) : Colors.white,
                  side: BorderSide(
                    color: const Color(0xFF5B8DB8).withOpacity(0.3),
                  ),
                );
              }).toList(),
            ),
    );
  }

  Future<void> _recallMessage(String messageId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('撤回消息'),
        content: const Text('确定要撤回这条消息吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('撤回'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final chatProvider = _chatProvider;
      if (chatProvider == null) return;
      await chatProvider.recallMessage(widget.friendId, messageId);
    }
  }

  void _showMessageOptions(MessageModel message) {
    if (message.recalled) return;
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 复制
            if (message.type == 'text' && message.content.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.blue),
                title: const Text('复制'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('已复制'), backgroundColor: Colors.green),
                  );
                },
              ),
            // 撤回
            if (message.isMe)
              ListTile(
                leading: const Icon(Icons.undo, color: Colors.orange),
                title: const Text('撤回'),
                onTap: () {
                  Navigator.pop(context);
                  _recallMessage(message.id);
                },
              ),
            // 删除
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('删除'),
              onTap: () async {
                Navigator.pop(context);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('删除消息'),
                    content: const Text('确定要删除这条消息吗？'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('删除', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );
                if (confirm == true) {
                  final chatProvider = _chatProvider;
                  if (chatProvider != null) {
                    await chatProvider.deleteMessage(widget.friendId, message.id);
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 显示好友资料底部弹窗，含删除好友功能
  void _showFriendProfile() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FriendProfileSheet(
        friendId: widget.friendId,
        friendName: widget.friendName,
        friendAvatar: widget.friendAvatar,
      ),
    );
    if (result == 'deleted' && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _reAddFriend() async {
    try {
      final contactProvider = context.read<ContactProvider>();
      final success = await contactProvider.sendFriendRequest(widget.friendId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? '好友请求已发送，等待对方确认' : '发送失败'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败：$e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Avatar(
              imageUrl: widget.friendAvatar,
              size: 36,
              isOnline: false,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.friendName,
                    style: const TextStyle(fontSize: 16),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Consumer<ChatProvider>(
                    builder: (context, provider, child) {
                      if (provider.isUserTyping(widget.friendId)) {
                        return const Text(
                          '正在输入...',
                          style: TextStyle(fontSize: 11, color: Color(0xFF5B8DB8)),
                        );
                      }
                      return Text(
                        '在线',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'profile') {
                _showFriendProfile();
              } else if (value == 'clear') {
                _clearChatHistory();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'profile', child: Text('查看资料')),
              const PopupMenuItem(value: 'clear', child: Text('清空聊天记录')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<ChatProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = provider.getMessages(widget.friendId);
                final undeliverableHint = provider.undeliverableHints[widget.friendId];
                
                if (messages.isEmpty && undeliverableHint == null) {
                  return Center(
                    child: Text(
                      '暂无消息，开始聊天吧',
                      style: TextStyle(
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                        fontSize: 14,
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    // 非好友提示卡片
                    if (undeliverableHint != null)
                      _buildNotFriendCard(undeliverableHint, isDark),
                    // 消息列表
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        reverse: true,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[messages.length - 1 - index];
                          
                          if (index < messages.length - 1) {
                            final prev = messages[messages.length - 1 - index - 1];
                            if (_shouldShowDateSeparator(prev.createdAt, message.createdAt)) {
                              return Column(
                                children: [
                                  _buildDateSeparator(message.createdAt, isDark),
                                  MessageBubble(
                                    message: message,
                                    onLongPress: () => _showMessageOptions(message),
                                    onTap: message.status == MessageStatus.failed 
                                        ? () {
                                            _chatProvider?.sendMessage(
                                              friendId: widget.friendId,
                                              type: message.type,
                                              content: message.content,
                                              mediaUrl: message.mediaUrl,
                                            );
                                          }
                                        : null,
                                  ),
                                ],
                              );
                            }
                          }

                          return MessageBubble(
                            message: message,
                            onLongPress: () => _showMessageOptions(message),
                            onTap: message.status == MessageStatus.failed 
                                ? () {
                                    _chatProvider?.sendMessage(
                                      friendId: widget.friendId,
                                      type: message.type,
                                      content: message.content,
                                      mediaUrl: message.mediaUrl,
                                    );
                                  }
                                : null,
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          if (_showEmoji) _buildEmojiPicker(isDark),
          _buildSuggestionCard(isDark),
          ChatInput(
            onSendText: _sendMessage,
            onSendMedia: (path, type) {
              if (type == 'image') _sendImage(path);
            },
            onAiClick: _toggleAiMode,
            aiMode: _aiMode,
            onEmojiClick: _showEmojiPicker,
            showEmoji: _showEmoji,
            onTextChanged: _onTextChanged,
            isRecording: _isRecording,
            onStartRecording: _startRecording,
            onStopRecording: _stopRecording,
          ),
        ],
      ),
    );
  }

  Widget _buildNotFriendCard(Map<String, String> hint, bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF1A1A2E).withOpacity(0.9), const Color(0xFF2A2A3E).withOpacity(0.9)]
              : [const Color(0xFFF0F4F8), const Color(0xFFE8EFF5)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF5B8DB8).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(Icons.auto_stories, size: 36, color: const Color(0xFF5B8DB8).withOpacity(0.7)),
          const SizedBox(height: 12),
          Text(
            hint['title'] ?? '📖 对方已不在你的序言中',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            hint['subtitle'] ?? '如需续写，请重新添加好友',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: _reAddFriend,
            icon: const Icon(Icons.person_add, size: 18),
            label: const Text('重新添加'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF5B8DB8),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
        ],
      ),
    );
  }

  bool _shouldShowDateSeparator(DateTime prev, DateTime current) {
    return prev.year != current.year ||
        prev.month != current.month ||
        prev.day != current.day;
  }

  Widget _buildDateSeparator(DateTime date, bool isDark) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(date.year, date.month, date.day);
    
    String dateStr;
    if (messageDay == today) {
      dateStr = '今天';
    } else {
      final yesterday = today.subtract(const Duration(days: 1));
      if (messageDay == yesterday) {
        dateStr = '昨天';
      } else {
        dateStr = DateFormat('yyyy/MM/dd').format(date);
      }
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE8E8E8),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            dateStr,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ),
      ),
    );
  }
}

/// 好友资料底部弹窗
class _FriendProfileSheet extends StatelessWidget {
  final String friendId;
  final String friendName;
  final String? friendAvatar;

  const _FriendProfileSheet({
    required this.friendId,
    required this.friendName,
    this.friendAvatar,
  });

  Future<void> _deleteFriend(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('删除好友'),
        content: Text('确定要删除「$friendName」吗？删除后对方将无法给你发送消息。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        final contactProvider = context.read<ContactProvider>();
        final success = await contactProvider.removeFriend(friendId);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? '已删除好友' : '删除失败'),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
          if (success) Navigator.pop(context, 'deleted');
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('删除失败：$e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 拖拽条
            Container(
              margin: const EdgeInsets.only(top: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // 头像
            Avatar(
              imageUrl: friendAvatar,
              size: 72,
              isOnline: false,
            ),
            const SizedBox(height: 12),
            // 名字
            Text(
              friendName,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '@$friendId',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            const Divider(indent: 40, endIndent: 40),
            // 操作按钮
            ListTile(
              leading: Icon(Icons.person_remove, color: Colors.red[400]),
              title: Text(
                '删除好友',
                style: TextStyle(color: Colors.red[400], fontSize: 16),
              ),
              onTap: () => _deleteFriend(context),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
