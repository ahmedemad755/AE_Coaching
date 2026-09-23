import 'package:get_it/get_it.dart';

/// The single, app-wide GetIt instance. Every dependency-registration
/// file in this directory imports this file (never `service_locator.dart`
/// itself) to avoid a circular import — `service_locator.dart` is a
/// pure re-export barrel that sits on top of these files, not underneath
/// them.
final sl = GetIt.instance;
