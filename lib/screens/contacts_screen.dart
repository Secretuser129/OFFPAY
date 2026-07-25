import 'package:flutter/material.dart';
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                decoration: const InputDecoration(
                  hintText: 'Search contacts...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: _filterContacts,
              )
            : const Text('Trusted Contacts'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
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
                        color: Colors.indigo[200],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'No trusted contacts yet. Save contacts from transaction details.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              )
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
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo,
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
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Device: ${contact.deviceId}'),
                              Text('${contact.totalTransactions} transactions'),
                            ],
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.send, color: Colors.indigo),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Direct pay coming soon!'),
                                    behavior: SnackBarBehavior.floating,
                                  ),
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
                  );
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
