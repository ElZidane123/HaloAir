class ResponseDataMap {
  bool success;
  String message;
  Map? data;
  ResponseDataMap({
    required this.success,
    required this.message,
    this.data,
  });
}