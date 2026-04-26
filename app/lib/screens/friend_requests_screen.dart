import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/contact_provider.dart';
import '../widgets/avatar.dart';

class FriendRequestsScreen extends StatefulWidget {
  const FriendRequestsScreen({super.key});

  @override
  State<FriendRequestsScreen> createState() => _FriendRequestsScreenState();
}

class _FriendRequestsScreenState extends State<FriendRequestsScreen> {
  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    final provider = context.read<ContactProvider>();
    await provider.loadFriendRequests();
  }

  Future<void> _acceptRequest(String requestId) async {
    final provider = context.read<ContactProvider>();
    final success = await provider.respondToFriendRequest(requestId, true);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '已添加为好友' : '操作失败'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  Future<void> _rejectRequest(String requestId) async {
    final provider = context.read<ContactProvider>();
    final success = await provider.respondToFriendRequest(requestId, false);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '已拒绝请求' : '操作失败'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('新朋友'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<ContactProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.friendRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_add_disabled_outlined, 
                      size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    '没有新的好友请求',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.friendRequests.length,
            itemBuilder: (context, index) {
              final request = provider.friendRequests[index];
              
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Avatar(
                      imageUrl: request.fromUserAvatar,
                      size: 48,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.fromUserNickname ?? 
                                request.fromUserName ?? '未知用户',
                          ),
                          if (request.message != null && 
                              request.message!.isNotEmpty)
                            Text(
                              request.message!,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey[600],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () => _rejectRequest(request.id),
                          child: const Text('忽略'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () => _acceptRequest(request.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF5B8DB8),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('接受'),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
