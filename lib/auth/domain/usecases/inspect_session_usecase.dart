import 'package:ae_coaching/auth/domain/entities/auth_session_inspection.dart';
import 'package:ae_coaching/auth/domain/repositories/auth_repository.dart';

/// Startup/reconciliation check: is there a real Firebase session
/// underneath a Hive-logged-out UI, and if so, is it complete or a
/// resumable partial registration?
class InspectSessionUseCase {
  final AuthRepository repository;

  InspectSessionUseCase(this.repository);

  Future<AuthSessionInspection> call() => repository.inspectCurrentSession();
}
