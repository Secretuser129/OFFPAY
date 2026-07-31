/// Represents the current synchronization and cryptographic state of an offline transaction.
enum TransactionStatus {
  /// Successfully completed and verified on local ledger
  completed,

  /// Pending offline relay or server synchronization
  pending,

  /// Transaction failed or signature invalid
  failed,

  /// Synchronized with cloud server
  synced,
}