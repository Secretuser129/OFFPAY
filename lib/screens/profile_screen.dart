import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/profile_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../models/wallet_model.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _deviceIdController = TextEditingController();
  int _selectedAvatar = 0;
  String? _profileImagePath;
  bool _isLoading = true;
  String _originalDeviceId = '';

  final List<IconData> _avatars = [
    Icons.person,
    Icons.account_balance_wallet,
    Icons.shield,
    Icons.bolt,
    Icons.star,
    Icons.verified_user,
  ];

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final name = await ProfileService.getUserName();
    final deviceId = await ProfileService.getDeviceId();
    final avatar = await ProfileService.getAvatarIndex();
    final imagePath = await ProfileService.getProfileImagePath();

    if (mounted) {
      setState(() {
        _nameController.text = name;
        _deviceIdController.text = deviceId;
        _originalDeviceId = deviceId;
        _selectedAvatar = avatar;
        _profileImagePath = imagePath;
        _isLoading = false;
      });
    }
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (picked != null) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'offpay_profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final permanentFile = await File(picked.path).copy('${appDir.path}/$fileName');
        await ProfileService.setProfileImagePath(permanentFile.path);
        setState(() {
          _profileImagePath = permanentFile.path;
        });
      } catch (e) {
        await ProfileService.setProfileImagePath(picked.path);
        setState(() {
          _profileImagePath = picked.path;
        });
      }
    }
  }

  void _showAvatarOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: Colors.blueAccent),
              title: const Text('Choose Photo from Gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickImageFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.face_rounded, color: Colors.amber),
              title: const Text('Select Default Icon'),
              onTap: () {
                Navigator.pop(ctx);
                setState(() {
                  _profileImagePath = null;
                });
                ProfileService.setProfileImagePath('');
              },
            ),
            if (_profileImagePath != null && _profileImagePath!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Remove Photo', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _profileImagePath = null;
                  });
                  ProfileService.setProfileImagePath('');
                },
              ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAccount() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 26),
            SizedBox(width: 10),
            Text('Delete Account?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to permanently delete your OFFPAY Account? Your identity and account data will be deleted on local device storage as well as the server database. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Deleting account from local and server database...'), duration: Duration(seconds: 2)),
              );
              await ProfileService.deleteAccount();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Account permanently deleted.'), backgroundColor: Colors.red),
                );
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveProfile() async {
    final name = _nameController.text.trim();
    final deviceId = _deviceIdController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name.')),
      );
      return;
    }

    if (deviceId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please set a Device ID.')),
      );
      return;
    }

    final isIdChanged = deviceId != _originalDeviceId;
    await ProfileService.saveProfile(
      name: name,
      deviceId: deviceId,
      avatarIndex: _selectedAvatar,
      isDeviceIdChanged: isIdChanged,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('User Profile & Identity'),
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Avatar Selector Header
                  Center(
                    child: GestureDetector(
                      onTap: _showAvatarOptions,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 46,
                            backgroundColor: theme.primaryColor,
                            child: ClipOval(
                              child: (_profileImagePath != null &&
                                      _profileImagePath!.isNotEmpty &&
                                      File(_profileImagePath!).existsSync())
                                  ? Image.file(
                                      File(_profileImagePath!),
                                      width: 92,
                                      height: 92,
                                      fit: BoxFit.cover,
                                      errorBuilder: (ctx, err, stack) =>
                                          Icon(_avatars[_selectedAvatar], size: 48, color: Colors.white),
                                    )
                                  : Icon(_avatars[_selectedAvatar], size: 48, color: Colors.white),
                            ),
                          ),
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.amber.shade700,
                            child: const Icon(Icons.edit, size: 16, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Choose Your Avatar',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.bold, color: theme.hintColor),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(_avatars.length, (index) {
                      final isSelected = index == _selectedAvatar;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedAvatar = index),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? theme.primaryColor : theme.cardColor,
                            border: Border.all(
                              color: isSelected ? theme.primaryColor : Colors.grey.shade400,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            _avatars[index],
                            color: isSelected ? Colors.white : theme.hintColor,
                            size: 20,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 30),

                  // 2. User Name Field
                  Text(
                    'Your Display Name',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      hintText: 'e.g. Alex Hunter',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 3. Device ID Section (Read-Only from Server)
                  Text(
                    'Server Device ID',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _deviceIdController,
                    readOnly: true,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.bluetooth),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      helperText: 'Unique ID linked to your account for offline BLE payments',
                    ),
                  ),
                  const SizedBox(height: 28),
                  const SizedBox(height: 28),

                  // 6. Save Profile Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.save),
                    label: const Text('Save Profile & Settings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _saveProfile,
                  ),

                  const SizedBox(height: 16),

                  // 6. Logout Button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.logout, color: Colors.redAccent),
                    label: const Text('Logout', style: TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      side: const BorderSide(color: Colors.redAccent, width: 1.5),
                    ),
                    onPressed: () async {
                      await ProfileService.setLoggedIn(false);
                      if (context.mounted) {
                        final wallet = Provider.of<WalletModel>(context, listen: false);
                        await wallet.clearWallet();
                        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
                      }
                    },
                  ),

                  const SizedBox(height: 16),

                  // 7. Delete Account Red Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.delete_forever_rounded),
                    label: const Text('Delete Account', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _confirmDeleteAccount,
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
      // bottomNavigationBar removed for clean full-screen view
    );
  }
}
