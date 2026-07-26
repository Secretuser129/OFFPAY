import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../services/reward_service.dart';
import '../widgets/global_apple_dock.dart';
import 'rewards_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _nameController = TextEditingController();
  final _deviceIdController = TextEditingController();
  int _selectedAvatar = 0;
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

    if (mounted) {
      setState(() {
        _nameController.text = name;
        _deviceIdController.text = deviceId;
        _originalDeviceId = deviceId;
        _selectedAvatar = avatar;
        _isLoading = false;
      });
    }
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
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 46,
                          backgroundColor: theme.primaryColor,
                          child: Icon(_avatars[_selectedAvatar], size: 48, color: Colors.white),
                        ),
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: Colors.amber.shade700,
                          child: const Icon(Icons.edit, size: 16, color: Colors.white),
                        ),
                      ],
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

                  // 4. Rewards & Scratch Cards Button
                  ElevatedButton.icon(
                    icon: const Icon(Icons.card_giftcard),
                    label: const Text(
                      '🎁 My Rewards & Scratch Cards',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.amber.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RewardsScreen()),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // 5. Collectible Roles & Abilities Section
                  Text(
                    'My Collectible Roles & Special Abilities',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                  ),
                  const SizedBox(height: 12),
                  _buildCollectibleRolesSection(theme),

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
                ],
              ),
            ),
      bottomNavigationBar: const GlobalAppleDock(activeRoute: '/profile'),
    );
  }

  Widget _buildCollectibleRolesSection(ThemeData theme) {
    final unlockedRoles = RewardService.getUnlockedRoles();
    final allRoles = RewardService.getAllAvailableRoles();
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      children: allRoles.map((role) {
        final isUnlocked = unlockedRoles.any((r) => r.id == role.id) ||
            role.id == 'pioneer'; // Pioneer unlocked by default as welcome badge

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isUnlocked
                ? (isDark ? Colors.indigo.withValues(alpha: 0.25) : Colors.indigo.withValues(alpha: 0.08))
                : (isDark ? Colors.grey.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1)),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isUnlocked
                  ? Colors.indigo.withValues(alpha: 0.5)
                  : Colors.grey.withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              Text(
                role.icon,
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: isUnlocked
                            ? (isDark ? Colors.white : Colors.black87)
                            : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      role.ability,
                      style: TextStyle(
                        fontSize: 11,
                        color: isUnlocked ? theme.hintColor : Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              if (isUnlocked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'ACTIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                )
              else
                const Icon(Icons.lock_outline, size: 18, color: Colors.grey),
            ],
          ),
        );
      }).toList(),
    );
  }
}
