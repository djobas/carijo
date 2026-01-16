import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'logger_service.dart';

/// Represents the current connectivity state
enum ConnectivityStatus {
  /// Device is connected to the internet
  online,

  /// Device is offline
  offline,

  /// Connectivity status is unknown or being determined
  unknown,
}

/// Service for monitoring internet connectivity.
///
/// Provides a centralized way to check and monitor connectivity status,
/// enabling graceful degradation when offline and automatic sync when
/// connection is restored.
///
/// Example usage:
/// ```dart
/// final connectivity = Provider.of<ConnectivityService>(context);
/// if (connectivity.isOnline) {
///   await supabaseService.syncAll();
/// }
/// ```
class ConnectivityService extends ChangeNotifier {
  ConnectivityStatus _status = ConnectivityStatus.unknown;
  Timer? _checkTimer;
  
  /// The current connectivity status.
  ConnectivityStatus get status => _status;

  /// Whether the device is currently online.
  bool get isOnline => _status == ConnectivityStatus.online;

  /// Whether the device is currently offline.
  bool get isOffline => _status == ConnectivityStatus.offline;

  /// Creates a ConnectivityService and starts monitoring.
  ConnectivityService() {
    _initialize();
  }

  Future<void> _initialize() async {
    await checkConnectivity();
    // Check connectivity every 30 seconds
    _checkTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      checkConnectivity();
    });
  }

  /// Manually checks the current connectivity status.
  ///
  /// Attempts to resolve a known hostname to determine if internet
  /// access is available. Updates [status] and notifies listeners.
  Future<void> checkConnectivity() async {
    final previousStatus = _status;
    
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        _status = ConnectivityStatus.online;
      } else {
        _status = ConnectivityStatus.offline;
      }
    } on SocketException catch (_) {
      _status = ConnectivityStatus.offline;
    } on TimeoutException catch (_) {
      _status = ConnectivityStatus.offline;
    } catch (e) {
      LoggerService.warning('Connectivity check failed', error: e);
      _status = ConnectivityStatus.unknown;
    }

    if (_status != previousStatus) {
      LoggerService.info('Connectivity changed: ${previousStatus.name} -> ${_status.name}');
      notifyListeners();
    }
  }

  /// Disposes of resources used by this service.
  @override
  void dispose() {
    _checkTimer?.cancel();
    super.dispose();
  }
}

/// Mixin for widgets that need connectivity-aware behavior.
///
/// Provides convenient methods for checking connectivity and
/// showing appropriate feedback to users.
mixin ConnectivityAwareMixin<T extends StatefulWidget> on State<T> {
  /// Shows a warning snackbar when trying to perform an online-only action while offline.
  void showOfflineWarning(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.cloud_off, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text('Cannot $action while offline')),
          ],
        ),
        backgroundColor: Colors.orange.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
