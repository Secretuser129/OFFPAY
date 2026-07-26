import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/transaction_model.dart';
import '../models/trusted_contact.dart';
import '../services/receipt_service.dart';

class TransactionDetailScreen extends StatefulWidget {
  final TransactionModel transaction;

  const TransactionDetailScreen({super.key, required this.transaction});

  @override
  State<TransactionDetailScreen> createState() => _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  bool _isContactSaved = false;

  @override
  void initState() {
    super.initState();
    _checkContactSaved();
  }

  Future<void> _checkContactSaved() async {
    await TrustedContactService.init();
    final saved = TrustedContactService.isContactSaved(widget.transaction.recipientId);
    if (mounted) setState(() => _isContactSaved = saved);
  }

  Future<void> _shareReceipt() async {
    await ReceiptService.generateAndShareReceipt(
      amount: widget.transaction.amount,
      recipientId: widget.transaction.recipientId,
      transactionId: widget.transaction.transactionId,
      timestamp: widget.transaction.timestamp,
      isCredit: widget.transaction.isCredit,
      status: widget.transaction.status,
    );
  }

  Future<void> _saveContact() async {
    await TrustedContactService.init();
    final contact = TrustedContact(
      name: widget.transaction.recipientId,
      deviceId: widget.transaction.recipientId,
      addedOn: DateTime.now(),
      totalTransactions: 1,
    );
    await TrustedContactService.addContact(contact);
    if (mounted) {
      setState(() => _isContactSaved = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved as Trusted Contact!'), backgroundColor: Colors.green),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final transaction = widget.transaction;
    final isCredit = transaction.isCredit;
    final formattedTime = DateFormat('EEEE, MMMM d, yyyy • HH:mm:ss').format(transaction.timestamp);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Details'),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Receipt',
            onPressed: _shareReceipt,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            const SizedBox(height: 10),
            // Header Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: isCredit ? Colors.green.shade100 : Colors.red.shade100,
                      child: Icon(
                        isCredit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                        size: 40,
                        color: isCredit ? Colors.green.shade800 : Colors.red.shade800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      isCredit ? 'Payment Received' : 'Payment Sent',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.hintColor),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${isCredit ? "+" : "−"}₹${transaction.amount.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 38,
                        fontWeight: FontWeight.bold,
                        color: isCredit ? Colors.green : Colors.red.shade700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green),
                          SizedBox(width: 6),
                          Text(
                            'Completed Offline via BLE',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Metadata Card
            Card(
              color: theme.cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: theme.brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.12)
                      : Colors.grey.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildDetailRow(
                      context,
                      label: 'Transaction ID',
                      value: transaction.transactionId,
                      canCopy: true,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      context,
                      label: 'Payment Status',
                      value: transaction.status,
                      isStatus: true,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      context,
                      label: isCredit ? 'Sender Device ID' : 'Recipient Device ID',
                      value: transaction.recipientId,
                      canCopy: true,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      context,
                      label: 'Date & Time',
                      value: formattedTime,
                    ),
                    const Divider(height: 24),
                    _buildDetailRow(
                      context,
                      label: 'Storage Duration',
                      value: 'Persisted (Stored for 30 Days)',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Share Receipt Button
            ElevatedButton.icon(
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Download / Share Receipt'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _shareReceipt,
            ),

            const SizedBox(height: 12),

            // Save as Trusted Contact Button
            OutlinedButton.icon(
              icon: Icon(_isContactSaved ? Icons.check_circle : Icons.person_add),
              label: Text(_isContactSaved ? 'Contact Saved' : 'Save as Trusted Contact'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: BorderSide(color: _isContactSaved ? Colors.green : Colors.indigo),
                foregroundColor: _isContactSaved ? Colors.green : Colors.indigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: _isContactSaved ? null : _saveContact,
            ),

            const SizedBox(height: 12),

            OutlinedButton.icon(
              icon: const Icon(Icons.arrow_back),
              label: const Text('Back to Dashboard'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                foregroundColor: theme.primaryColor,
                side: BorderSide(color: theme.primaryColor.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(BuildContext context, {required String label, required String value, bool canCopy = false, bool isStatus = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 2,
          child: Text(
            label,
            style: TextStyle(color: Theme.of(context).hintColor, fontSize: 13),
          ),
        ),
        Expanded(
          flex: 3,
          child: isStatus
              ? Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: value == 'VERIFIED'
                        ? Colors.green.withValues(alpha: 0.15)
                        : value == 'PENDING'
                            ? Colors.amber.withValues(alpha: 0.15)
                            : Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        value == 'VERIFIED'
                            ? Icons.verified
                            : value == 'PENDING'
                                ? Icons.hourglass_top
                                : Icons.cancel,
                        size: 14,
                        color: value == 'VERIFIED'
                            ? Colors.green
                            : value == 'PENDING'
                                ? Colors.amber.shade900
                                : Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        value == 'VERIFIED' ? 'Verified by Server Proof' : value == 'PENDING' ? 'Pending Server Sync' : 'Transfer Failed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: value == 'VERIFIED'
                              ? Colors.green
                              : value == 'PENDING'
                                  ? Colors.amber.shade900
                                  : Colors.red,
                        ),
                      ),
                    ],
                  ),
                )
              : Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                    if (canCopy)
                      IconButton(
                        icon: const Icon(Icons.copy, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: value));
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Copied $label to clipboard')),
                          );
                        },
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
