import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/contact_provider.dart';
import '../widgets/avatar.dart';

class SearchUserScreen extends StatefulWidget {
  const SearchUserScreen({super.key});

  @override
  State<SearchUserScreen> createState() => _SearchUserScreenState();
}

class _SearchUserScreenState extends State<SearchUserScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    setState(() => _isSearching = true);
    final provider = context.read<ContactProvider>();
    await provider.searchUsers(query);
    setState(() => _isSearching = false);
  }

  Future<void> _addFriend(String userId) async {
    final provider = context.read<ContactProvider>();
    final success = await provider.sendFriendRequest(userId);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '好友请求已发送' : provider.errorMessage ?? '发送失败'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '搜索序言号/昵称',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey[400]),
            suffixIcon: _searchController.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      _searchController.clear();
                      setState(() {});
                    },
                  )
                : null,
          ),
          onSubmitted: (_) => _search(),
          onChanged: (_) => setState(() {}),
        ),
        actions: [
          TextButton(
            onPressed: _isSearching ? null : _search,
            child: _isSearching
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('搜索'),
          ),
        ],
      ),
      body: Consumer<ContactProvider>(
        builder: (context, provider, child) {
          if (!_isSearching && provider.searchResults.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    '搜索好友',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: provider.searchResults.length,
            itemBuilder: (context, index) {
              final user = provider.searchResults[index];

              return ListTile(
                leading: Avatar(
                  imageUrl: user.avatar,
                  size: 48,
                  isOnline: user.isOnline,
                ),
                title: Text(user.nickname ?? user.xuyanId ?? ''),
                subtitle: user.signature != null
                    ? Text(
                        user.signature!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text(user.xuyanId != null && user.xuyanId!.isNotEmpty ? '@${user.xuyanId}' : '@用户'),
                trailing: provider.isFriend(user.id)
                    ? const Chip(
                        label: Text('已添加'),
                        backgroundColor: Colors.grey,
                        labelStyle: TextStyle(color: Colors.white, fontSize: 12),
                      )
                    : ElevatedButton(
                        onPressed: () => _addFriend(user.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF5B8DB8),
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('添加'),
                      ),
              );
            },
          );
        },
      ),
    );
  }
}
