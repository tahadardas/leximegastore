enum PaymentMethod { cod, shamCash }

extension PaymentMethodX on PaymentMethod {
  String get label {
    switch (this) {
      case PaymentMethod.cod:
        return 'الدفع عند الاستلام';
      case PaymentMethod.shamCash:
        return 'شام كاش';
    }
  }
}
