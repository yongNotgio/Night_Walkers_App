import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const int _totalPages = 3;
  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isRequestingPermissions = false;
  late final List<_RequiredPermission> _requiredPermissions;
  final Map<Permission, PermissionStatus> _permissionStatuses = {};

  @override
  void initState() {
    super.initState();
    _requiredPermissions = _buildRequiredPermissions();
    _refreshPermissionStatuses();
  }

  List<_RequiredPermission> _buildRequiredPermissions() {
    final common = <_RequiredPermission>[
      _RequiredPermission(
        permission: Permission.locationWhenInUse,
        title: 'Location',
        description: 'Shares your position during an alert.',
        icon: Icons.location_on_outlined,
      ),
      _RequiredPermission(
        permission: Permission.camera,
        title: 'Camera/Flashlight',
        description: 'Uses flashlight strobe for emergency signaling.',
        icon: Icons.flashlight_on_outlined,
      ),
      _RequiredPermission(
        permission: Permission.contacts,
        title: 'Contacts',
        description: 'Imports emergency contacts from your phone.',
        icon: Icons.contacts_outlined,
      ),
      _RequiredPermission(
        permission: Permission.notification,
        title: 'Notifications',
        description: 'Required for background mode foreground service.',
        icon: Icons.notifications_active_outlined,
      ),
    ];

    if (Platform.isAndroid) {
      return [
        ...common,
        _RequiredPermission(
          permission: Permission.sms,
          title: 'SMS',
          description: 'Sends direct emergency text messages.',
          icon: Icons.sms_outlined,
        ),
        _RequiredPermission(
          permission: Permission.phone,
          title: 'Phone',
          description: 'Needed by Android telephony APIs for direct SMS.',
          icon: Icons.phone_android_outlined,
        ),
      ];
    }

    return common;
  }

  Future<void> _refreshPermissionStatuses() async {
    final nextStatuses = <Permission, PermissionStatus>{};
    for (final item in _requiredPermissions) {
      nextStatuses[item.permission] = await item.permission.status;
    }
    if (!mounted) return;
    setState(() {
      _permissionStatuses
        ..clear()
        ..addAll(nextStatuses);
    });
  }

  Future<void> _requestAllPermissions() async {
    setState(() => _isRequestingPermissions = true);
    for (final item in _requiredPermissions) {
      final current = await item.permission.status;
      if (current.isGranted) continue;
      await item.permission.request();
    }
    await _refreshPermissionStatuses();
    if (!mounted) return;
    setState(() => _isRequestingPermissions = false);
  }

  bool get _allRequiredPermissionsGranted {
    if (_permissionStatuses.length != _requiredPermissions.length) return false;
    return _requiredPermissions.every(
      (item) => _permissionStatuses[item.permission]?.isGranted == true,
    );
  }

  bool get _hasPermanentlyDeniedPermission {
    return _requiredPermissions.any(
      (item) => _permissionStatuses[item.permission]?.isPermanentlyDenied == true,
    );
  }

  Future<void> _finishOnboarding() async {
    if (!_allRequiredPermissionsGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please allow all required permissions to continue.'),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showOnboarding', false);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _nextPage() {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finishOnboarding();
    }
  }

  void _prevPage() {
    if (_currentPage == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: [
                  _WelcomeStep(colorScheme: colorScheme),
                  _PermissionsStep(
                    permissions: _requiredPermissions,
                    statuses: _permissionStatuses,
                    isRequesting: _isRequestingPermissions,
                    onAllowAll: _requestAllPermissions,
                    onOpenSettings: openAppSettings,
                    hasPermanentlyDenied: _hasPermanentlyDeniedPermission,
                  ),
                  _ReadyStep(
                    allPermissionsGranted: _allRequiredPermissionsGranted,
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    OutlinedButton(
                      onPressed: _prevPage,
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 84),
                  Expanded(
                    child: Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(
                          _totalPages,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: _currentPage == index ? 22 : 10,
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              color: _currentPage == index
                                  ? colorScheme.primary
                                  : colorScheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: _nextPage,
                    child: Text(_currentPage == _totalPages - 1 ? 'Enter App' : 'Next'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'Night Walkers',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fast emergency trigger, direct SMS alerts, and optional background volume-key activation.',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 24),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withOpacity(0.45),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _IntroItem(icon: Icons.bolt, text: 'Trigger emergency mode instantly'),
                _IntroItem(icon: Icons.sms, text: 'Send direct SMS to emergency contacts'),
                _IntroItem(icon: Icons.volume_down, text: 'Use 3x volume-down in background mode'),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'Setup takes less than a minute.',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _IntroItem extends StatelessWidget {
  const _IntroItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _PermissionsStep extends StatelessWidget {
  const _PermissionsStep({
    required this.permissions,
    required this.statuses,
    required this.isRequesting,
    required this.onAllowAll,
    required this.onOpenSettings,
    required this.hasPermanentlyDenied,
  });

  final List<_RequiredPermission> permissions;
  final Map<Permission, PermissionStatus> statuses;
  final bool isRequesting;
  final VoidCallback onAllowAll;
  final Future<bool> Function() onOpenSettings;
  final bool hasPermanentlyDenied;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Required Permissions',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Grant all to enable core safety features.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: permissions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = permissions[index];
                final status = statuses[item.permission];
                final granted = status?.isGranted == true;
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: granted
                        ? Colors.green.withOpacity(0.09)
                        : colorScheme.surfaceContainerHighest.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: granted
                          ? Colors.green.withOpacity(0.35)
                          : colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(item.icon, color: granted ? Colors.green : colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(item.description),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        granted ? 'Allowed' : 'Needed',
                        style: TextStyle(
                          color: granted ? Colors.green : colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: isRequesting ? null : onAllowAll,
              icon: const Icon(Icons.verified_user_outlined),
              label: Text(isRequesting ? 'Requesting...' : 'Allow Required Permissions'),
            ),
          ),
          if (hasPermanentlyDenied) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onOpenSettings,
                child: const Text('Open App Settings'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ReadyStep extends StatelessWidget {
  const _ReadyStep({required this.allPermissionsGranted});

  final bool allPermissionsGranted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            'You are ready',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            allPermissionsGranted
                ? 'All required permissions are granted. You can start using the app now.'
                : 'Some required permissions are still missing. Go back and allow all required permissions.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: allPermissionsGranted
                  ? Colors.green.withOpacity(0.12)
                  : colorScheme.errorContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(
                  allPermissionsGranted ? Icons.check_circle : Icons.warning_amber_rounded,
                  color: allPermissionsGranted ? Colors.green : colorScheme.error,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    allPermissionsGranted
                        ? 'Safety features fully enabled.'
                        : 'Grant all required permissions before entering the app.',
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            'Tip: Enable Background Mode in Settings for volume-key triggering while minimized.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _RequiredPermission {
  const _RequiredPermission({
    required this.permission,
    required this.title,
    required this.description,
    required this.icon,
  });

  final Permission permission;
  final String title;
  final String description;
  final IconData icon;
}
