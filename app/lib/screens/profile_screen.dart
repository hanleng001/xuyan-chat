import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../config/api_config.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/about_screen.dart';
import '../screens/settings_screen.dart';
import '../widgets/update_dialog.dart';
import 'login_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String _nickname = '用户';
  String _xuyanId = '';
  String _phone = '';
  String _avatar = '';
  String _version = '';
  bool _isLoading = true;
  int _deviceCount = 1; // 设备在线数
  StreamSubscription? _deviceSubscription;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _listenDeviceChanges();
  }

  void _listenDeviceChanges() {
    final socket = SocketService();
    _deviceSubscription = socket.onDeviceChange.listen((data) {
      if (data['type'] == 'new-device') {
        setState(() {
          _deviceCount = data['totalDevices'] ?? _deviceCount + 1;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('新设备登录: ${data['deviceName'] ?? '未知设备'}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      } else if (data['type'] == 'kicked') {
        // 被踢下线，跳转到登录页
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(data['reason'] ?? '您已被其他设备踢下线'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginScreen()),
            (_) => false,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _deviceSubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadUserInfo() async {
    final storage = StorageService();
    final nickname = await storage.getNickname();
    final xuyanId = await storage.getUsername();
    final avatar = await storage.getAvatar();
    
    // 获取版本号，容错处理
    String version = 'v1.1.3';
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (packageInfo.version.isNotEmpty) {
        version = 'v${packageInfo.version}';
      }
    } catch (e) {
      print('PackageInfo.fromPlatform() 失败: $e');
    }
    
    // 从API获取完整用户信息
    String apiXuyanId = '';
    try {
      final authProvider = context.read<AuthProvider>();
      final user = authProvider.user;
      if (user != null) {
        apiXuyanId = user.xuyanId ?? '';
        _phone = user.phone ?? '';
      }
    } catch (e) { /* ignore */ }
    
    setState(() {
      _nickname = nickname ?? '用户';
      // 优先使用API返回的xuyanId，没有才用本地缓存的
      _xuyanId = apiXuyanId.isNotEmpty ? apiXuyanId : (xuyanId ?? '');
      _avatar = avatar ?? '';
      _version = version;
      _isLoading = false;
    });
  }

  Future<void> _showSetXuyanIdDialog() async {
    final controller = TextEditingController();
    bool checking = false;
    String? error;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('设置序言号'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('4-20位字母和数字，唯一且不可修改',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      labelText: '序言号',
                      hintText: '例如: Xuyan2024',
                      border: const OutlineInputBorder(),
                      errorText: error,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: checking ? null : () async {
                    final id = controller.text.trim();
                    if (id.length < 4 || id.length > 20) {
                      setDialogState(() => error = '长度需4-20位');
                      return;
                    }
                    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(id)) {
                      setDialogState(() => error = '只能包含字母和数字');
                      return;
                    }
                    setDialogState(() { checking = true; error = null; });
                    
                    try {
                      final api = ApiService();
                      // 先检查是否可用
                      final checkResp = await api.get(
                        '${ApiEndpoints.checkXuyanId}?xuyanId=$id',
                      );
                      if (checkResp.data['available'] != true) {
                        setDialogState(() { checking = false; error = '该序言号已被使用'; });
                        return;
                      }
                      // 设置序言号
                      final resp = await api.post(
                        ApiEndpoints.setXuyanId,
                        data: {'xuyanId': id},
                      );
                      if (resp.statusCode == 200) {
                        Navigator.pop(context, true);
                      } else {
                        setDialogState(() { checking = false; error = resp.data['message'] ?? '设置失败'; });
                      }
                    } catch (e) {
                      setDialogState(() { checking = false; error = '网络错误，请重试'; });
                    }
                  },
                  child: checking 
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('确认设置'),
                ),
              ],
            );
          },
        );
      },
    );
    
    if (result == true) _loadUserInfo();
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('确定要退出登录吗？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('退出', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await context.read<AuthProvider>().logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF5B8DB8);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('我的', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadUserInfo,
              child: ListView(
                children: [
                  // 用户信息卡片
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: primaryColor.withOpacity(0.1),
                          backgroundImage: _avatar.isNotEmpty ? NetworkImage(_avatar.startsWith('http') ? _avatar : '${ApiConfig.baseUrl}$_avatar') : null,
                          child: _avatar.isEmpty ? Icon(Icons.person, size: 40, color: primaryColor) : null,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _nickname,
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
                              ),
                              if (_xuyanId.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '序言号: $_xuyanId',
                                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                                ),
                              ] else ...[
                                const SizedBox(height: 2),
                                Text(
                                  '未设置序言号',
                                  style: TextStyle(fontSize: 13, color: Colors.orange[400]),
                                ),
                              ],
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit, color: primaryColor),
                          onPressed: () async {
                            final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const EditProfileScreen()));
                            if (result == true) _loadUserInfo();
                          },
                        ),
                      ],
                    ),
                  ),

                  // 设置
                  _buildSectionTitle('设置', isDark),
                  if (_xuyanId.isEmpty)
                    _buildMenuItem(
                      icon: Icons.badge_outlined,
                      iconColor: Colors.blue,
                      title: '设置序言号',
                      subtitle: '唯一身份标识，设置后不可修改',
                      onTap: () => _showSetXuyanIdDialog(),
                    ),
                  _buildMenuItem(
                    icon: Icons.settings,
                    iconColor: Colors.grey,
                    title: '设置',
                    subtitle: '外观、通知、AI配置等',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                    },
                  ),

                  // 设备管理
                  _buildSectionTitle('安全', isDark),
                  _buildMenuItem(
                    icon: Icons.devices,
                    iconColor: Colors.green,
                    title: '在线设备',
                    subtitle: '当前 $_deviceCount 个设备在线',
                    onTap: () => _showDeviceList(),
                  ),

                  // 关于
                  _buildSectionTitle('关于', isDark),
                  _buildMenuItem(
                    icon: Icons.update,
                    iconColor: Colors.orange,
                    title: '检查更新',
                    subtitle: _version,
                    onTap: () async {
                      try {
                        final updateService = AppUpdateService();
                        final updateInfo = await updateService.checkForUpdate();
                        if (!mounted) return;
                        if (updateInfo != null && updateInfo.hasUpdate) {
                          showUpdateDialog(context, updateInfo);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('当前已是最新版本')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('检查更新失败')),
                          );
                        }
                      }
                    },
                  ),
                  _buildMenuItem(
                    icon: Icons.info,
                    iconColor: Colors.blue,
                    title: '关于序言',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                    },
                  ),

                  const SizedBox(height: 16),

                  // 退出登录
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: ElevatedButton(
                      onPressed: _logout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.withOpacity(0.1),
                        foregroundColor: Colors.red,
                        elevation: 0,
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('退出登录', style: TextStyle(fontSize: 16)),
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? Colors.grey[400] : Colors.grey[600],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: isDark ? Colors.white : Colors.black87)),
        subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500])) : null,
        trailing: trailing ?? Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }

  Future<void> _showDeviceList() async {
    final socket = SocketService();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.5,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('在线设备', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(context)),
                ],
              ),
              const Divider(),
              Expanded(
                child: FutureBuilder(
                  future: _fetchDevices(socket),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }
                    final devices = snapshot.data as List<Map<String, dynamic>>? ?? [];
                    if (devices.isEmpty) {
                      return Center(child: Text('暂无在线设备'));
                    }
                    return ListView.builder(
                      itemCount: devices.length,
                      itemBuilder: (context, index) {
                        final device = devices[index];
                        final isCurrent = device['isCurrent'] == true;
                        final deviceType = device['deviceType'] ?? 'unknown';
                        final deviceName = device['deviceName'] ?? '未知设备';
                        final connectedAt = device['connectedAt'] != null
                            ? _formatTime(device['connectedAt'] as int)
                            : '';

                        final IconData icon = deviceType == 'android'
                            ? Icons.phone_android
                            : deviceType == 'ios'
                                ? Icons.phone_iphone
                                : Icons.devices;

                        return ListTile(
                          leading: Icon(icon, color: isCurrent ? Colors.green : Colors.grey),
                          title: Text(deviceName),
                          subtitle: Text(isCurrent ? '当前设备 · $connectedAt' : connectedAt),
                          trailing: isCurrent
                              ? Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('当前', style: TextStyle(color: Colors.green, fontSize: 12)),
                                )
                              : TextButton(
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: Text('踢下线'),
                                        content: Text('确定要将 $deviceName 踢下线吗？'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('取消')),
                                          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('确定', style: TextStyle(color: Colors.red))),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      socket.kickDevice(device['socketId'] ?? '', (success) {
                                        if (success) {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('已踢下线'), backgroundColor: Colors.green),
                                          );
                                          Navigator.pop(context);
                                          setState(() => _deviceCount--);
                                        }
                                      });
                                    }
                                  },
                                  child: Text('踢下线', style: TextStyle(color: Colors.red, fontSize: 13)),
                                ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchDevices(SocketService socket) async {
    final completer = Completer<List<Map<String, dynamic>>>();
    socket.getDevices((devices) => completer.complete(devices));
    return completer.future.timeout(const Duration(seconds: 5), onTimeout: () => []);
  }

  String _formatTime(int timestamp) {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    return '${dt.month}/${dt.day} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}
