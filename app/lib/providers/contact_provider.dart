import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../models/friend_request_model.dart';
import '../services/friend_service.dart';
import '../services/socket_service.dart';

class ContactProvider extends ChangeNotifier {
  final FriendService _friendService = FriendService();
  
  List<UserModel> _friends = [];
  List<FriendRequestModel> _friendRequests = []; // 收到的好友请求
  List<FriendRequestModel> _sentRequests = []; // 自己发出的好友请求
  List<UserModel> _searchResults = [];
  int _pendingRequestCount = 0;
  bool _isLoading = false;
  bool _isSearching = false;
  String? _errorMessage;

  List<UserModel> get friends => _friends;
  List<FriendRequestModel> get friendRequests => _friendRequests;
  List<FriendRequestModel> get sentRequests => _sentRequests;
  List<UserModel> get searchResults => _searchResults;
  int get pendingRequestCount => _pendingRequestCount;
  bool get isLoading => _isLoading;
  bool get isSearching => _isSearching;
  String? get errorMessage => _errorMessage;

  List<FriendRequestModel> get pendingRequests {
    return _friendRequests.where((r) => r.isPending).toList();
  }

  Future<void> loadFriends() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _friends = await _friendService.getFriends();
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadFriendRequests() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _friendService.getFriendRequests();
      _friendRequests = result['received'] ?? [];
      _sentRequests = result['sent'] ?? [];
      _pendingRequestCount = _friendRequests.where((r) => r.isPending).length;
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadPendingRequestCount() async {
    try {
      _pendingRequestCount = await _friendService.getPendingRequestCount();
      notifyListeners();
    } catch (e) {
      // Ignore
    }
  }

  Future<void> searchUsers(String keyword) async {
    if (keyword.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    _isSearching = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _searchResults = await _friendService.searchUsers(keyword);
      _isSearching = false;
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<bool> sendFriendRequest(String userId, {String? message}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _friendService.sendFriendRequest(userId: userId, message: message);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> respondToFriendRequest(String requestId, bool accept) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      if (accept) {
        await _friendService.acceptFriendRequest(requestId);
      } else {
        await _friendService.rejectFriendRequest(requestId);
      }
      
      // 从列表中移除已处理的请求
      _friendRequests.removeWhere((r) => r.id == requestId);
      _pendingRequestCount = _friendRequests.where((r) => r.isPending).length;
      
      // 如果接受，刷新好友列表
      if (accept) {
        await loadFriends();
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeFriend(String friendId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _friendService.removeFriend(friendId);
      _friends.removeWhere((f) => f.id == friendId);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<UserModel?> getUserProfile(String userId) async {
    try {
      return await _friendService.getUserProfile(userId);
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();
      return null;
    }
  }

  bool isFriend(String userId) {
    return _friends.any((f) => f.id == userId);
  }

  void clearSearchResults() {
    _searchResults = [];
    notifyListeners();
  }

  // Socket 事件处理
  void handleSocketEvent(String event, dynamic data) {
    switch (event) {
      case 'friend-request':
        if (data is Map<String, dynamic>) {
          final request = FriendRequestModel.fromJson(data);
          _friendRequests.insert(0, request);
          _pendingRequestCount++;
          notifyListeners();
        }
        break;
      case 'friend-accepted':
        // 好友请求被接受，刷新好友列表
        loadFriends();
        // 从发出的请求列表中移除
        if (data is Map && data['requestId'] != null) {
          _sentRequests.removeWhere((r) => r.id == data['requestId']);
        }
        break;
      case 'friend-rejected':
        // 好友请求被拒绝
        if (data is Map && data['requestId'] != null) {
          _sentRequests.removeWhere((r) => r.id == data['requestId']);
        }
        notifyListeners();
        break;
      case 'friend-removed':
        // 被好友删除
        if (data is Map && data['userId'] != null) {
          _friends.removeWhere((f) => f.id == data['userId']);
          notifyListeners();
        }
        break;
    }
  }
}
