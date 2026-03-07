class AppFailure {
  final String message;
  final String? code;

  AppFailure(this.message, [this.code]);

  @override
  String toString() => message;
}
