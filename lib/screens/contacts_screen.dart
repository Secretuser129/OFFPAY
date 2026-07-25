import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart' as fb;
import 'package:flutter_animate/flutter_animate.dart';
import '../models/trusted_contact.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({Key? key}) : super(key: key);

  @override
  _ContactsScreenState createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  List<TrustedContact> _allContacts = [];
  List<TrustedContact> _filteredContacts = [];
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initAndLoad();
  }

  Future<void> _initAndLoad() async {
    await TrustedContactService.init();
    _loadContacts();
  }

  void _loadContacts() {
    final contacts = TrustedContactService.getContacts();
    setState(() {
      _allContacts = contacts;
      _filteredContacts = contacts;
    });
  }

  void _filterContacts(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredContacts = _allContacts;
      } else {
        _filteredContacts = _allContacts.where((c) =>
            c.name.toLowerCase().contains(query.toLowerCase()) ||
            c.deviceId.toLowerCase().contains(query.toLowerCase())).toList();
      }
    });
  }

  void _confirmDelete(TrustedContact contact) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Contact'),
        content: Text('Are you sure you want to remove ${contact.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await TrustedContactService.removeContact(contact.deviceId);
              _loadContacts();
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search contacts...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: theme.appBarTheme.foregroundColor?.withValues(alpha: 0.7) ?? Colors.white70),
                ),
                style: TextStyle(color: theme.appBarTheme.foregroundColor ?? Colors.white),
                onChanged: _filterContacts,
              )
            : const Text('Trusted Contacts'),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  _filterContacts('');
                }
              });
            },
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _allContacts.isEmpty
            ? Center(
                key: const ValueKey('empty'),
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.contacts_outlined,
                        size: 80,
                        color: theme.primaryColor.withValues(alpha: 0.4),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No trusted contacts yet. Save contacts from transaction details.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.hintColor,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ).animate().fade(duration: 500.ms).scale(begin: const Offset(0.9, 0.9))
            : ListView.builder(
                key: const ValueKey('list'),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                itemCount: _filteredContacts.length,
                itemBuilder: (context, index) {
                  final contact = _filteredContacts[index];
                  return Card(
                    elevation: 2,
                    margin: const EdgeInsets.only(bottom: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: isDark ? BorderSide(color: Colors.indigo.withValues(alpha: 0.3)) : BorderSide.none,
                    ),
                    color: theme.cardTheme.color,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: Colors.white,
                          child: Text(
                            contact.name.isNotEmpty
                                ? contact.name[0].toUpperCase()
                                : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          contact.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Device: ${contact.deviceId}',
                                style: TextStyle(fontSize: 12, color: theme.hintColor),
                              ),
                              Text(
                                '${contact.totalTransactions} transactions',
                                style: TextStyle(fontSize: 12, color: theme.hintColor),
                              ),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.send, color: theme.primaryColor),
                              onPressed: () {
                                // Instantiate device directly from MAC address (bonded device)
                                final fb.BluetoothDevice device = fb.BluetoothDevice.fromId(contact.deviceId);
                                Navigator.pushNamed(
                                  context,
                                  '/payment_input',
                                  arguments: {'device': device, 'recipientName': contact.name},
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.red),
                              onPressed: () => _confirmDelete(contact),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ).animate(delay: (100 * index).ms).fade(duration: 500.ms).slideX(begin: 0.1, end: 0);
                },
              ),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
