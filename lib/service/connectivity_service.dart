import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:io';

class ConnectivityService {
  final Connectivity _connectivity = Connectivity();

  late final Stream<bool> _connectionStream;

  ConnectivityService() {
    _connectionStream = _connectivity.onConnectivityChanged
        .map((results) => results.any((result) => result != ConnectivityResult.none)) // แก้ตรงนี้ให้เช็คใน List
        .asBroadcastStream();
  }

  Stream<bool> get onConnectionChanged => _connectionStream;

  Future<bool> hasInternet() async {
    try {
      // แนะนำให้ใส่ timeout ไว้ด้วย เผื่อกรณีเน็ตหมุนวนค้าง
      final result = await InternetAddress.lookup('google.com').timeout(const Duration(seconds: 3));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } catch (_) {
      return false; 
    }
  }
}