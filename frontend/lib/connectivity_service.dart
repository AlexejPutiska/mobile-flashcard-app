import 'package:connectivity_plus/connectivity_plus.dart';

/// Služba `ConnectivityService` zisťuje, či je zariadenie aktuálne online.
///
/// Využíva balík `connectivity_plus`, ktorý kontroluje pripojenie cez mobilné dáta alebo Wi-Fi.
class ConnectivityService {
  /// Asynchrónne zistí, či je zariadenie pripojené k internetu
  /// (cez mobilné dáta alebo Wi-Fi).
  ///
  /// Vracia `true`, ak je pripojenie aktívne, inak `false`.
  static Future<bool> isOnline() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult == ConnectivityResult.mobile ||
           connectivityResult == ConnectivityResult.wifi;
  }
}
