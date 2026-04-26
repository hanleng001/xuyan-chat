import 'dart:async';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _signatureController = TextEditingController();
  final TextEditingController _xuyanIdController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  String? _avatarUrl;
  String? _originalNickname;
  String? _currentXuyanId; // 已设置的序言号
  bool _isLoading = false;
  bool _isUploading = false;
  bool _isCheckingXuyanId = false;
  String? _xuyanIdCheckMsg; // 序言号可用性提示
  bool _xuyanIdAvailable = false;

  @override
  void initState() {
    super.initState();
    final authProvider = context.read<AuthProvider>();
    _nicknameController.text = authProvider.nickname ?? '';
    _signatureController.text = authProvider.user?.signature ?? '';
    _avatarUrl = authProvider.avatar;
    _originalNickname = authProvider.nickname;
    _currentXuyanId = authProvider.user?.xuyanId;
  }

  Future<void> _pickAvatar() async {
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );
      if (image == null) return;

      setState(() => _isUploading = true);

      // 使用 AuthProvider 上传头像
      final avatarUrl = await context.read<AuthProvider>().uploadAvatar(image.path);
      
      if (avatarUrl != null) {
        // 同步更新本地缓存
        final storage = StorageService();
        await storage.setAvatar(avatarUrl);
        setState(() {
          _avatarUrl = avatarUrl;
          _isUploading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('头像已更新'), backgroundColor: Colors.green),
          );
          // 返回true触发profile刷新
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('头像上传失败'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('上传失败：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _saveProfile() async {
    final nickname = _nicknameController.text.trim();
    if (nickname.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('昵称不能为空'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await context.read<AuthProvider>().updateProfile(
            nickname: nickname,
            bio: _signatureController.text.trim(),
          );

      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('资料已更新'), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('更新失败'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('更新失败：$e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nicknameController.dispose();
    _signatureController.dispose();
    _xuyanIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFF5B8DB8);

    return Scaffold(
      appBar: AppBar(
        title: const Text('编辑资料', style: TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isDark ? const Color(0xFF1A1A2E) : Colors.white,
        foregroundColor: isDark ? Colors.white : Colors.black87,
        elevation: 0.5,
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading || _isUploading ? null : _saveProfile,
            child: _isLoading
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : Text('保存', style: TextStyle(color: primaryColor, fontSize: 16)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 头像
          Center(
            child: GestureDetector(
              onTap: _isUploading ? null : _pickAvatar,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: primaryColor.withOpacity(0.1),
                    backgroundImage: _avatarUrl != null && _avatarUrl!.isNotEmpty ? NetworkImage(_avatarUrl!.startsWith('http') ? _avatarUrl! : '${ApiConfig.baseUrl}$_avatarUrl') : null,
                    child: _avatarUrl == null || _avatarUrl!.isEmpty
                        ? Icon(Icons.person, size: 50, color: primaryColor)
                        : null,
                  ),
                  if (_isUploading)
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      ),
                    )
                  else
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 16),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text('点击更换头像', style: TextStyle(fontSize: 13, color: Colors.grey[500])),
          ),
          const SizedBox(height: 32),

          // 昵称
          _buildTextField(
            controller: _nicknameController,
            label: '昵称',
            hint: '输入你的昵称',
            maxLength: 20,
            isDark: isDark,
          ),
          const SizedBox(height: 16),

          // 个性签名
          _buildTextField(
            controller: _signatureController,
            label: '个性签名',
            hint: '介绍一下自己吧',
            maxLength: 100,
            maxLines: 3,
            isDark: isDark,
          ),

          const SizedBox(height: 16),

          // 序言号
          if (_currentXuyanId != null) ...[
            // 已设置序言号 - 只读展示
            _buildXuyanIdDisplay(isDark),
          ] else ...[
            // 未设置序言号 - 可设置
            _buildXuyanIdSetter(isDark),
          ],

          const SizedBox(height: 32),

          // 保存按钮
          ElevatedButton(
            onPressed: _isLoading || _isUploading ? null : _saveProfile,
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                : const Text('保存修改', style: TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  Widget _buildXuyanIdDisplay(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('序言号', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Text('@$_currentXuyanId', style: TextStyle(fontSize: 16, color: isDark ? Colors.white70 : Colors.black87, fontWeight: FontWeight.w500)),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('已设置', style: TextStyle(fontSize: 11, color: Colors.green)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text('设置后不可修改，可用于登录', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Widget _buildXuyanIdSetter(bool isDark) {
    final primaryColor = const Color(0xFF5B8DB8);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('序言号', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _xuyanIdController,
                style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87),
                decoration: InputDecoration(
                  hintText: '4-20位字母或数字',
                  hintStyle: TextStyle(color: Colors.grey[400]),
                  prefixText: '@',
                  prefixStyle: TextStyle(fontSize: 16, color: isDark ? Colors.grey[400] : Colors.grey[600], fontWeight: FontWeight.w500),
                  counterText: '',
                  filled: true,
                  fillColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  suffixIcon: _isCheckingXuyanId
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                ),
                maxLength: 20,
                onChanged: _onXuyanIdChanged,
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _xuyanIdAvailable ? _setXuyanId : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: Colors.grey[300],
              ),
              child: const Text('设置', style: TextStyle(fontSize: 14)),
            ),
          ],
        ),
        if (_xuyanIdCheckMsg != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _xuyanIdCheckMsg!,
              style: TextStyle(
                fontSize: 12,
                color: _xuyanIdAvailable ? Colors.green : Colors.red,
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text('设置后不可修改，可用于登录', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
      ],
    );
  }

  Timer? _xuyanIdDebounce;

  void _onXuyanIdChanged(String value) {
    setState(() {
      _xuyanIdCheckMsg = null;
      _xuyanIdAvailable = false;
    });

    _xuyanIdDebounce?.cancel();

    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    // 格式预检
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(trimmed)) {
      setState(() {
        _xuyanIdCheckMsg = '只能包含字母和数字';
      });
      return;
    }
    if (trimmed.length < 4) {
      setState(() {
        _xuyanIdCheckMsg = '至少4个字符';
      });
      return;
    }

    _xuyanIdDebounce = Timer(const Duration(milliseconds: 600), () {
      _checkXuyanIdAvailability(trimmed);
    });
  }

  Future<void> _checkXuyanIdAvailability(String xuyanId) async {
    setState(() {
      _isCheckingXuyanId = true;
      _xuyanIdCheckMsg = null;
    });

    try {
      final available = await context.read<AuthProvider>().checkXuyanId(xuyanId);
      if (mounted) {
        setState(() {
          _isCheckingXuyanId = false;
          _xuyanIdAvailable = available ?? false;
          _xuyanIdCheckMsg = _xuyanIdAvailable ? '该序言号可用' : '该序言号已被使用';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isCheckingXuyanId = false;
          _xuyanIdCheckMsg = '检查失败，请重试';
        });
      }
    }
  }

  Future<void> _setXuyanId() async {
    final xuyanId = _xuyanIdController.text.trim();
    if (xuyanId.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final success = await context.read<AuthProvider>().setXuyanId(xuyanId);
      if (mounted) {
        if (success) {
          setState(() {
            _currentXuyanId = xuyanId;
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('序言号设置成功！'), backgroundColor: Colors.green),
          );
        } else {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('设置失败，请重试'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
        );
      }
    }
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool isDark,
    int maxLength = 50,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isDark ? Colors.grey[400] : Colors.grey[600])),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLength: maxLength,
          maxLines: maxLines,
          style: TextStyle(fontSize: 16, color: isDark ? Colors.white : Colors.black87),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey[400]),
            counterText: '',
            filled: true,
            fillColor: isDark ? const Color(0xFF2A2A3E) : const Color(0xFFF5F5F5),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}
