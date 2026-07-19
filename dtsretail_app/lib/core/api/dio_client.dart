import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/constants/api_constants.dart';

final dioClientProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: ApiConstants.connectTimeout,
      receiveTimeout: ApiConstants.receiveTimeout,
      contentType: 'application/json',
    ),
  );
  return dio;
});
