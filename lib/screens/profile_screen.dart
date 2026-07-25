import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../services/update_service.dart';

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
  bool _canChangeId = true;
  int _daysRemaining = 0;
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
    final canChange = await ProfileService.canChangeDeviceId();
    final days = await ProfileService.getDaysRemainingForIdChange();

    if (mounted) {
      setState(() {
        _nameController.text = name;
        _deviceIdController.text = deviceId;
        _originalDeviceId = deviceId;
        _selectedAvatar = avatar;
        _canChangeId = canChange;
        _daysRemaining = days;
        _isLoading = false;
      });
    }
  }

  void _randomizeDeviceId() {
    setState(() {
      _deviceIdController.text = ProfileService.generateRandomDeviceId();
    });
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

                  // 3. Device ID Section with Randomize Button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Temporary Device ID',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.textTheme.bodyLarge?.color),
                      ),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.casino, size: 16),
                        label: const Text('Randomize', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: _randomizeDeviceId,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _deviceIdController,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.bluetooth),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true,
                      helperText: 'Unique ID used for offline BLE payments',
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 30-Day Status Banner
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.blue, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _canChangeId
                                ? 'You can randomize or update your Device ID anytime (recommended every 30 days).'
                                : 'Device ID changed recently. Next recommended change in $_daysRemaining day(s).',
                            style: const TextStyle(fontSize: 12, color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 36),

                  // 4. Save Profile Button
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

                  // 5. In-App Updater Check Button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.system_update),
                    label: const Text('Check for App Updates'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => UpdateService.checkForUpdates(context, silent: false),
                  ),
                ],
              ),
            ),
    );
  }
}
