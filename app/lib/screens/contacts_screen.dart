import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/contact_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/avatar.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    _loadFriends();
  }

  Future<void> _loadFriends() async {
    final contactProvider = context.read<ContactProvider>();
    await contactProvider.loadFriends();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通讯录'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            onPressed: () {
              Navigator.of(context).pushNamed('/search');
            },
          ),
        ],
      ),
      body: Consumer<ContactProvider>(
        builder: (context, provider, child) {
          return Column(
            children: [
              // 快捷入口
              ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.group_add, color: Colors.orange),
                ),
                title: const Text('新朋友'),
                trailing: provider.pendingRequestCount > 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${provider.pendingRequestCount}',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 12),
                        ),
                      )
                    : const Icon(Icons.chevron_right, color: Colors.grey),
                onTap: () {
                  Navigator.of(context).pushNamed('/friend-requests');
                },
              ),
              const Divider(),
              // 好友列表
              if (provider.isLoading)
                const Expanded(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (provider.friends.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, 
                            size: 80, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text('暂无好友', 
                            style: TextStyle(color: Colors.grey[400])),
                        const SizedBox(height: 8),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed('/search');
                          },
                          child: const Text('添加好友'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: provider.friends.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                          child: Text(
                            '${provider.friends.length}位好友',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        );
                      }
                      final friend = provider.friends[index - 1];
                      return ListTile(
                        leading: Avatar(
                          imageUrl: friend.avatar,
                          size: 40,
                          isOnline: friend.isOnline,
                        ),
                        title: Text(friend.nickname ?? friend.xuyanId ?? ''),
                        subtitle: friend.signature != null
                            ? Text(
                                friend.signature!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        onTap: () {
                          Navigator.of(context).pushNamed(
                            '/chat',
                            arguments: {
                              'conversationId': friend.id,
                              'otherUserId': friend.id,
                              'otherUserName': friend.nickname ?? friend.xuyanId,
                              'otherUserAvatar': friend.avatar,
                            },
                          );
                        },
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
