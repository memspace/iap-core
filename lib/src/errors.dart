class BillingException implements Exception {
  final String code;
  final String message;
  final Object details;

  BillingException(this.code, this.message, [this.details]);
}
