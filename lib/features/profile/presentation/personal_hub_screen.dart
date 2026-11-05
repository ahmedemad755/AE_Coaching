import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:ae_coaching/core/routes/app_router.dart';
import 'package:ae_coaching/core/session/session_storage.dart';
import 'package:ae_coaching/core/theme/app_theme.dart';
import 'package:ae_coaching/features/profile/data/local_profile_photo_store.dart';
import 'package:ae_coaching/features/profile/data/user_profile_repository.dart';
import 'package:ae_coaching/features/profile/presentation/profile_navigation.dart';
import 'package:ae_coaching/features/profile/presentation/profile_avatar.dart';
import 'package:ae_coaching/features/profile/domain/my_progress_summary_service.dart';
import 'package:ae_coaching/features/workout/data/repositories/session_exercise_repository.dart';
import 'package:ae_coaching/features/workout/data/repositories/workout_session_repository.dart';
import 'package:ae_coaching/l10n/app_localizations.dart';
import 'package:ae_coaching/service_locator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PersonalHubScreen extends StatefulWidget {
  const PersonalHubScreen({super.key, required this.onLogout});

  final ProfileLogoutCallback onLogout;

  @override
  State<PersonalHubScreen> createState() => _PersonalHubScreenState();
}

class _PersonalHubScreenState extends State<PersonalHubScreen> {
  StreamSubscription<User?>? _authSubscription;
  String _uid = '';
  String _name = '';
  String _phone = '';
  String? _photoPath;
  bool _photoBusy = false;
  bool _profileBusy = false;
  late Future<MyProgressSummary> _progress;

  @override
  void initState() {
    super.initState();
    _setAccount(FirebaseAuth.instance.currentUser, initial: true);
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) => _setAccount(user),
    );
  }

  void _setAccount(User? user, {bool initial = false}) {
    final uid = user?.uid ?? '';
    if (!initial && uid == _uid) return;
    if (!initial && mounted) {
      setState(() {
        _uid = uid;
        _photoPath = null;
        _loadAccountFields(user);
        _progress = _loadProgress(uid);
      });
    } else {
      _uid = uid;
      _loadAccountFields(user);
      _progress = _loadProgress(uid);
    }
    if (uid.isNotEmpty) _loadPhoto(uid);
  }

  void _loadAccountFields(User? user) {
    final session = sl<SessionStorage>();
    final sessionMatchesUser = user != null && session.currentUserUid == user.uid;
    _name = sessionMatchesUser ? session.currentUserName.trim() : '';
    if (_name.isEmpty) _name = user?.displayName?.trim() ?? '';
    _phone = sessionMatchesUser ? session.currentUserPhone.trim() : '';
    if (_phone.isEmpty) _phone = user?.phoneNumber ?? '';
  }

  Future<MyProgressSummary> _loadProgress(String uid) async {
    if (uid.isEmpty) return _emptyProgress();
    final sessionRepository = sl<WorkoutSessionRepository>();
    final setRepository = sl<SessionExerciseRepository>();
    final sessionBox = await sessionRepository.getUserBox();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      return _emptyProgress();
    }
    final setBox = await setRepository.getUserBox();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      return _emptyProgress();
    }
    return const MyProgressSummaryService().summarize(
      sessions: sessionRepository.getAllCompletedSessions(sessionBox),
      sets: setBox.values.toList(),
      now: DateTime.now(),
    );
  }

  MyProgressSummary _emptyProgress() => MyProgressSummary(
    completedWorkouts: 0,
    completedThisWeek: 0,
    completedThisMonth: 0,
    weeklyActivity: [],
  );

  Future<void> _loadPhoto(String uid) async {
    try {
      final path = await sl<LocalProfilePhotoStore>().getPhotoPath(uid);
      if (mounted && _uid == uid && FirebaseAuth.instance.currentUser?.uid == uid) {
        setState(() => _photoPath = path);
      }
    } catch (_) {
      if (mounted && _uid == uid) setState(() => _photoPath = null);
    }
  }

  Future<void> _showPhotoActions() async {
    final l10n = AppLocalizations.of(context)!;
    final uid = _uid;
    final selected = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.add_a_photo_outlined),
              title: Text(_photoPath == null ? l10n.profileAddPhoto : l10n.profileChangePhoto),
              onTap: () => Navigator.pop(sheetContext, 'pick'),
            ),
            if (_photoPath != null)
              ListTile(
                leading: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                title: Text(l10n.profileRemovePhoto),
                onTap: () => Navigator.pop(sheetContext, 'remove'),
              ),
          ],
        ),
      ),
    );
    if (!mounted ||
        selected == null ||
        _uid != uid ||
        FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }
    if (selected == 'pick') await _pickPhoto();
    if (selected == 'remove') await _removePhoto();
  }

  Future<void> _pickPhoto() async {
    final l10n = AppLocalizations.of(context)!;
    final uid = _uid;
    if (uid.isEmpty || _photoBusy) return;
    setState(() => _photoBusy = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 82,
        maxWidth: 1200,
        maxHeight: 1200,
      );
      if (picked == null || !mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      final codec = await ui.instantiateImageCodec(
        await File(picked.path).readAsBytes(),
      );
      final decoded = await codec.getNextFrame();
      decoded.image.dispose();
      codec.dispose();
      if (!mounted ||
          _uid != uid ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.profilePhotoPreviewTitle),
          content: Center(
            child: ClipOval(
              child: Image.file(
                File(picked.path),
                width: 176,
                height: 176,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 176,
                  height: 176,
                  child: Icon(Icons.broken_image_outlined, size: 48),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.save)),
          ],
        ),
      );
      if (accepted != true || !mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;

      final path = await sl<LocalProfilePhotoStore>().savePhoto(
        uid: uid,
        source: File(picked.path),
      );
      if (mounted && _uid == uid && FirebaseAuth.instance.currentUser?.uid == uid) {
        setState(() => _photoPath = path);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profilePhotoSaved)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profilePhotoSaveFailed)));
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _removePhoto() async {
    final l10n = AppLocalizations.of(context)!;
    if (_photoBusy || _uid.isEmpty) return;
    final uid = _uid;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileRemovePhoto),
        content: Text(l10n.profilePhotoRemoveConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.cancel)),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.delete)),
        ],
      ),
    );
    if (confirmed != true ||
        !mounted ||
        _uid != uid ||
        FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }
    setState(() => _photoBusy = true);
    try {
      await sl<LocalProfilePhotoStore>().removePhoto(uid);
      if (mounted && _uid == uid && FirebaseAuth.instance.currentUser?.uid == uid) {
        setState(() => _photoPath = null);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profilePhotoRemoved)));
      }
    } catch (_) {
      if (mounted) {
        if (_uid == uid && FirebaseAuth.instance.currentUser?.uid == uid) {
          await _loadPhoto(uid);
        }
        if (!mounted ||
            _uid != uid ||
            FirebaseAuth.instance.currentUser?.uid != uid) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profilePhotoRemoveFailed)));
      }
    } finally {
      if (mounted) setState(() => _photoBusy = false);
    }
  }

  Future<void> _editName() async {
    final l10n = AppLocalizations.of(context)!;
    if (_profileBusy || _uid.isEmpty) return;
    final uid = _uid;
    final controller = TextEditingController(text: _name);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.profileNameEditTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 80,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: l10n.fullNameHint),
          onSubmitted: (value) => Navigator.pop(dialogContext, value.trim()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(l10n.cancel)),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: Text(l10n.save)),
        ],
      ),
    );
    controller.dispose();
    if (name == null ||
        !mounted ||
        _uid != uid ||
        FirebaseAuth.instance.currentUser?.uid != uid) {
      return;
    }
    if (name.isEmpty || name.length > 80) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileNameInvalid)));
      return;
    }

    setState(() => _profileBusy = true);
    try {
      await sl<UserProfileRepository>().updateName(uid: uid, name: name);
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      await sl<SessionStorage>().updateCurrentUserName(uid: uid, name: name);
      if (mounted && _uid == uid) {
        setState(() => _name = name);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileNameSaved)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.profileNameSaveFailed)));
      }
    } finally {
      if (mounted) setState(() => _profileBusy = false);
    }
  }

  Future<void> _openSettings() async {
    await Navigator.pushNamed(
      context,
      AppNavigator.appSettings,
      arguments: AppSettingsArgs(onLogout: widget.onLogout),
    );
  }

  Future<void> _openProgress() async {
    await Navigator.pushNamed(context, AppNavigator.myProgress);
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.appColors;
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final photoPath = _photoPath;
    if (uid.isEmpty || uid != _uid) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.personalHubTitle)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: colors.canvas,
      appBar: AppBar(
        title: Text(l10n.personalHubTitle),
        actions: [
          IconButton(tooltip: l10n.appSettingsTitle, onPressed: _openSettings, icon: const Icon(Icons.settings_outlined)),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 30),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ProfileAvatar(
                name: _name,
                photoPath: photoPath,
                semanticLabel: photoPath == null ? l10n.profileAddPhoto : l10n.profileChangePhoto,
                isLoading: _photoBusy,
                onTap: _showPhotoActions,
                onImageError: () {
                  if (mounted && _uid == uid && _photoPath == photoPath) {
                    setState(() => _photoPath = null);
                  }
                },
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name.isEmpty ? l10n.profileNameUnavailable : _name, maxLines: 2, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
                    if (_phone.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 5,
                        children: [
                          Text(l10n.profilePhoneLabel),
                          const SizedBox(width: 5),
                          Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text(_phone),
                          ),
                        ],
                      ),
                      Text(l10n.profilePhoneVerificationNote, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: colors.textMuted)),
                    ],
                    const SizedBox(height: 6),
                    Text(l10n.profileHeaderSubtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: colors.textMuted)),
                  ],
                ),
              ),
              IconButton(
                tooltip: l10n.profileEditName,
                onPressed: _profileBusy ? null : _editName,
                icon: _profileBusy ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(l10n.myProgressTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          FutureBuilder<MyProgressSummary>(
            future: _progress,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(padding: EdgeInsets.all(18), child: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                return ListTile(leading: const Icon(Icons.info_outline), title: Text(l10n.progressDataUnavailable));
              }
              final progress = snapshot.data ?? _emptyProgress();
              if (progress.completedWorkouts == 0) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.fitness_center, color: Theme.of(context).colorScheme.primary),
                  title: Text(l10n.progressNoCompletedWorkouts),
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: _Metric(value: progress.completedWorkouts, label: l10n.progressCompletedWorkoutsLabel)),
                      const SizedBox(width: 8),
                      Expanded(child: _Metric(value: progress.completedThisWeek, label: l10n.progressThisWeekLabel)),
                      const SizedBox(width: 8),
                      Expanded(child: _Metric(value: progress.completedThisMonth, label: l10n.progressThisMonthLabel)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _openProgress,
                      icon: const Icon(Icons.insights_outlined),
                      label: Text(l10n.profileProgressAction),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Divider(),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.settings_outlined),
            title: Text(l10n.appSettingsTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openSettings,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insights_outlined),
            title: Text(l10n.myProgressTitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: _openProgress,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.logout),
            title: Text(l10n.logoutTooltip),
            subtitle: Text(l10n.settingsLogoutDescription),
            onTap: widget.onLogout,
          ),
        ],
      ),
    );
  }

}

class _Metric extends StatelessWidget {
  const _Metric({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 86),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text('$value', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 3),
        Text(label, maxLines: 2, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: context.appColors.textMuted)),
      ],
    ),
  );
}
