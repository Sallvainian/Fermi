import 'device_calendar_service_interface.dart';

// Conditional imports - Dart will choose the correct one at compile time
import 'device_calendar_service_stub.dart'
    if (dart.library.io) 'device_calendar_service_mobile.dart'
    if (dart.library.html) 'device_calendar_service_web.dart';

/// Factory for creating platform-specific DeviceCalendarService instances
abstract class DeviceCalendarServiceFactory {
  static DeviceCalendarServiceInterface create() {
    return getDeviceCalendarService();
  }
}