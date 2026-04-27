import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import '../constants/app_config.dart';
import '../main.dart';
import 'notification_helper_stub.dart' if (dart.library.html) 'notification_helper_web.dart' as notification_helper;

/// Listens to WebSocket for new-order events and notifies the seller (sound + in-app notification).
class NewOrderService {
  NewOrderService._();
  static final NewOrderService _instance = NewOrderService._();
  static NewOrderService get instance => _instance;

  /// Called when a new order is received for the current store (so e.g. OrdersScreen can refresh the list).
  static void Function()? onNewOrderForStore;

  io.Socket? _socket;
  bool _connecting = false;
  bool _stopped = false;
  int _retryAttempt = 0;
  Timer? _reconnectTimer;
  DateTime? _lastErrorLogAt;
  String? _lastErrorLogMsg;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _soundReady = false;

  /// Call once at app startup (e.g. after login or from main).
  void start() {
    _stopped = false;
    if (_socket?.connected == true || _connecting) return;
    _connecting = true;
    _retryAttempt = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _initSound();
    if (kIsWeb) {
      notification_helper.requestNotificationPermission();
    }
    _connect();
  }

  void _scheduleReconnect({required String reason, Object? err}) {
    if (_stopped) return;
    if (_reconnectTimer?.isActive == true) return; // already scheduled

    // Exponential backoff with a cap.
    _retryAttempt = (_retryAttempt + 1).clamp(1, 10);
    final backoffSeconds = (2 << (_retryAttempt - 1)).clamp(2, 60); // 2,4,8..60

    // Throttle noisy logs (like repeated timeouts).
    final msg = err != null ? '$reason: $err' : reason;
    final now = DateTime.now();
    final shouldLog = _lastErrorLogAt == null ||
        now.difference(_lastErrorLogAt!).inSeconds >= 15 ||
        _lastErrorLogMsg != msg;
    if (shouldLog) {
      _lastErrorLogAt = now;
      _lastErrorLogMsg = msg;
      debugPrint('[NewOrderService] WebSocket issue ($backoffSeconds s retry): $msg');
    }

    _reconnectTimer = Timer(Duration(seconds: backoffSeconds), () {
      _reconnectTimer = null;
      if (_socket?.connected == true || _connecting || _stopped) return;
      _connect();
    });
  }

  void _connect() {
    final uri = AppConfig.webSocketUrl;
    try {
      _socket = io.io(
        uri,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .disableAutoConnect()
            .build(),
      );
      _socket!.connect();
      _socket!.onConnect((_) {
        _connecting = false;
        _retryAttempt = 0;
        _reconnectTimer?.cancel();
        _reconnectTimer = null;
        debugPrint('[NewOrderService] WebSocket connected to $uri');
      });
      _socket!.onDisconnect((_) {
        _connecting = false;
        _socket?.dispose();
        _socket = null;
        _scheduleReconnect(reason: 'disconnected');
      });
      _socket!.onConnectError((err) {
        _connecting = false;
        _socket?.dispose();
        _socket = null;
        _scheduleReconnect(reason: 'connect error', err: err);
      });
      _socket!.onError((err) {
        _connecting = false;
        _scheduleReconnect(reason: 'socket error', err: err);
      });
      _socket!.on('new-order', _onNewOrder);
    } catch (e) {
      _connecting = false;
      _socket?.dispose();
      _socket = null;
      _scheduleReconnect(reason: 'failed to connect', err: e);
    }
  }

  void _initSound() {
    if (_soundReady) return;
    _audioPlayer.setReleaseMode(ReleaseMode.release);
    _soundReady = true;
  }

  Future<void> _playNotificationSound() async {
    if (kIsWeb) {
      try {
        await _audioPlayer.play(AssetSource('sounds/notification.wav'));
      } catch (_) {
        try {
          SystemSound.play(SystemSoundType.click);
        } catch (_) {}
      }
      return;
    }
    try {
      await _audioPlayer.play(AssetSource('sounds/notification.wav'));
    } catch (_) {
      try {
        await _audioPlayer.play(AssetSource('sounds/notification.wav'));
      } catch (_) {
        try {
          await _audioPlayer.play(UrlSource(
            'https://assets.mixkit.co/active_storage/sfx/2869-notification-perfect.mp3',
          ));
        } catch (_) {
          try {
            SystemSound.play(SystemSoundType.click);
          } catch (_) {}
        }
      }
    }
  }

  void _onNewOrder(dynamic raw) {
    final data = raw is Map ? raw : (raw != null ? {'storeId': raw.toString()} : <String, dynamic>{});
    final orderStoreId = data['storeId']?.toString();
    if (orderStoreId == null || orderStoreId.isEmpty) return;
    _checkAndNotify(orderStoreId, data);
  }

  Future<void> _checkAndNotify(String orderStoreId, Map<dynamic, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    final userRole = prefs.getString('userRole');
    final myStoreId = prefs.getString('storeId') ?? '';
    if (userRole != '3' || myStoreId.isEmpty) return;
    if (orderStoreId != myStoreId) return;
    await _playNotificationSound();
    _showNotification(data);
    onNewOrderForStore?.call();
  }

  void _showNotification(Map<dynamic, dynamic> data) {
    final orderId = data['orderId'] ?? data['number'] ?? '';
    final grandtotal = data['grandtotal'] ?? '';
    final msg = orderId.toString().isEmpty
        ? 'New order received!'
        : 'New order #$orderId${grandtotal.toString().isNotEmpty ? ' (₹$grandtotal)' : ''}';
    if (kIsWeb) {
      notification_helper.showBrowserNotification('New order', msg);
    }
    final context = navigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Call from anywhere (e.g. orders screen on refresh when new orders detected) to play the same notification sound.
  void playNotificationSound() {
    _initSound();
    _playNotificationSound();
  }

  void stop() {
    _stopped = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _connecting = false;
    _audioPlayer.dispose();
  }
}
