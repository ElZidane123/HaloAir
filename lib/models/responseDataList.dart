class ResponseDataList {
  bool success;
  String message;
  List? data;
  ResponseDataList({
    required this.success,
    required this.message,
    this.data,
  });
}