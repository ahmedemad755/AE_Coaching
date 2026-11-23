enum FcmNotificationDestination { home }

class FcmNotificationRouting {
  const FcmNotificationRouting._();

  static FcmNotificationDestination? destinationForData(
    Map<String, dynamic> data,
  ) {
    if (data['type'] == 'inactivity_reminder') {
      return FcmNotificationDestination.home;
    }
    return null;
  }
}
