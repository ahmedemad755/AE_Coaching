/// Composition-root barrel: re-exports the global `sl` GetIt instance
/// and every feature's `init*()` registration function, so every
/// existing `import 'package:ae_coaching/service_locator.dart';` call
/// site (AppBootstrap, the router, views) keeps working unchanged.
/// Stage 5 split the actual registration code by feature ownership
/// into `lib/core/di/*.dart` — this file holds no registration logic
/// of its own anymore.
library;

export 'core/di/sl_instance.dart';
export 'core/di/core_dependencies.dart';
export 'core/di/auth_dependencies.dart';
export 'core/di/workout_dependencies.dart';
export 'core/di/measurements_dependencies.dart';
export 'core/di/progress_photos_dependencies.dart';
export 'core/di/workout_programs_dependencies.dart';
