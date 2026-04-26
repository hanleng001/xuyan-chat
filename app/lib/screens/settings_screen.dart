import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../services/storage_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final StorageService _storage = StorageService();
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _vibrationEnabled = true;
  String _aiModel = 'nvidia/llama-3.1-nemotron-70b-instruct';
  bool _isLoading = true;
  bool _isCheckingUpdate = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final notifications = await _storage.getNotificationsEnabled();
    final sound = await _storage.getSoundEnabled();
    final vibration = await _storage.getVibrationEnabled();
    final model = await _storage.getAiModel();
    
    setState(() {
      _notificationsEnabled = notifications;
      _soundEnabled = sound;
      _vibrationEnabled = vibration;
      _aiModel = model ?? 'nvidia/llama-3.1-nemotron-70b-instruct';
      _isLoading = false;
    });
  }

  Future<void> _checkForUpdate() async {
    setState(() => _isCheckingUpdate = true);
    
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
          SnackBar(content: Text('检查更新失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isCheckingUpdate = false);
      }
    }
  }

  Future<void> _showAIConfigDialog() async {
    final apiKeyController = TextEditingController();
    final baseUrlController = TextEditingController();
    
    final currentKey = await _storage.getAIKey();
    final currentUrl = await _storage.getAIBaseUrl();
    
    apiKeyController.text = currentKey ?? '';
    baseUrlController.text = currentUrl ?? 'https://integrate.api.nvidia.com/v1';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('AI 配置'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'API 地址',
                  hintText: 'https://integrate.api.nvidia.com/v1',
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: apiKeyController,
                decoration: const InputDecoration(
                  labelText: 'API Key',
                  hintText: '输入你的 API Key',
                ),
                obscureText: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () async {
              await _storage.setAIBaseUrl(baseUrlController.text);
              await _storage.setAIKey(apiKeyController.text);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('配置已保存')),
                );
              }
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeProvider = context.watch<ThemeProvider>();

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('设置', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // 外观设置
          _buildSectionTitle('外观', isDark),
          _buildMenuItem(
            icon: Icons.dark_mode,
            iconColor: Colors.purple,
            title: '深色模式',
            subtitle: themeProvider.isDarkMode ? '已开启' : '已关闭',
            trailing: Switch(
              value: themeProvider.isDarkMode,
              onChanged: (value) => themeProvider.setDarkMode(value),
              activeColor: const Color(0xFF5B8DB8),
            ),
          ),

          // 通知设置
          _buildSectionTitle('通知', isDark),
          _buildMenuItem(
            icon: Icons.notifications,
            iconColor: Colors.green,
            title: '消息通知',
            trailing: Switch(
              value: _notificationsEnabled,
              onChanged: (value) async {
                await _storage.setNotificationsEnabled(value);
                setState(() => _notificationsEnabled = value);
              },
              activeColor: const Color(0xFF5B8DB8),
            ),
          ),
          _buildMenuItem(
            icon: Icons.volume_up,
            iconColor: Colors.orange,
            title: '声音',
            trailing: Switch(
              value: _soundEnabled,
              onChanged: _notificationsEnabled ? (value) async {
                await _storage.setSoundEnabled(value);
                setState(() => _soundEnabled = value);
              } : null,
              activeColor: const Color(0xFF5B8DB8),
            ),
          ),
          _buildMenuItem(
            icon: Icons.vibration,
            iconColor: Colors.teal,
            title: '振动',
            trailing: Switch(
              value: _vibrationEnabled,
              onChanged: _notificationsEnabled ? (value) async {
                await _storage.setVibrationEnabled(value);
                setState(() => _vibrationEnabled = value);
              } : null,
              activeColor: const Color(0xFF5B8DB8),
            ),
          ),

          // AI 设置
          _buildSectionTitle('AI 助手', isDark),
          _buildMenuItem(
            icon: Icons.psychology,
            iconColor: Colors.blue,
            title: 'AI 配置',
            subtitle: '配置 API 地址和密钥',
            onTap: _showAIConfigDialog,
          ),

          // 检查更新
          _buildSectionTitle('其他', isDark),
          _buildMenuItem(
            icon: Icons.update,
            iconColor: Colors.orange,
            title: '检查更新',
            subtitle: _isCheckingUpdate ? '检查中...' : '点击检查',
            onTap: _isCheckingUpdate ? null : _checkForUpdate,
            trailing: _isCheckingUpdate 
                ? const SizedBox(
                    width: 16, 
                    height: 16, 
                    child: CircularProgressIndicator(strokeWidth: 2)
                  )
                : Icon(Icons.chevron_right, color: Colors.grey[400]),
          ),

          const SizedBox(height: 32),

          // 退出登录
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ElevatedButton(
              onPressed: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('退出登录'),
                    content: const Text('确定要退出登录吗？'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('取消'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('退出', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && mounted) {
                  await context.read<AuthProvider>().logout();
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                  }
                }
              },
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
        title: Text(
          title, 
          style: TextStyle(
            fontSize: 15, 
            fontWeight: FontWeight.w500, 
            color: isDark ? Colors.white : Colors.black87
          )
        ),
        subtitle: subtitle != null 
            ? Text(subtitle, style: TextStyle(fontSize: 13, color: Colors.grey[500])) 
            : null,
        trailing: trailing ?? Icon(Icons.chevron_right, color: Colors.grey[400]),
        onTap: onTap,
      ),
    );
  }
}
