import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';  
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

  Future<void> _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('showOnboarding', false);
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }

  void _nextPage() async {
    if (_currentPage < _totalPages - 1) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      await _finishOnboarding();
    }
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (index) => setState(() => _currentPage = index),
                children: const [
                  _WelcomeStep(),
                  _FeatureExplanationStep(),
                  _PermissionStep(),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (_currentPage > 0)
                    TextButton(
                      onPressed: _prevPage,
                      child: const Text('Back'),
                    )
                  else
                    const SizedBox(width: 64),
                  Row(
                    children: List.generate(_totalPages, (index) => Container(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index ? Theme.of(context).colorScheme.primary : Colors.grey[300],
                      ),
                    )),
                  ),
                  TextButton(
                    onPressed: _nextPage,
                    child: Text(_currentPage == _totalPages - 1 ? 'Finish' : 'Next'),
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
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/animations/welcome.json', height: 190), 
              const SizedBox(height: 32),
              Text(
                'Welcome to Night Walkers!',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Your safety companion for night walks. Stay safe, stay connected.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureExplanationStep extends StatelessWidget {
  const _FeatureExplanationStep();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Lottie.asset('assets/animations/features.json', height: 180), // Placeholder
              const SizedBox(height: 32),
              Text(
                'How Night Walkers Helps You',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const FeatureTile(
                icon: Icons.warning,
                text: 'Panic Button: Instantly alert your contacts and sound an alarm.',
              ),
              const FeatureTile(
                icon: Icons.location_on,
                text: 'Location Sharing: Send your real-time location in emergencies.',
              ),
              const FeatureTile(
                icon: Icons.sms,
                text: 'SMS Alerts: Notify your emergency contacts quickly.',
              ),
              const FeatureTile(
                icon: Icons.flash_on,
                text: 'Flashlight: Use your phone as a safety signal.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FeatureTile extends StatelessWidget {
  final IconData icon;
  final String text;
  const FeatureTile({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }
}

class _PermissionStep extends StatefulWidget {
  const _PermissionStep();

  @override
  State<_PermissionStep> createState() => _PermissionStepState();
}

class _PermissionStepState extends State<_PermissionStep> {
  int _permIndex = 0;
  final List<_PermInfo> _permissions = [
    _PermInfo(
      title: 'Location Permission',
      description: 'We need your location to send your position to emergency contacts during an alert.',
      permission: Permission.locationWhenInUse,
      icon: Icons.location_on,
    ),
    _PermInfo(
      title: 'SMS Permission',
      description: 'We need SMS permission to notify your emergency contacts.',
      permission: Permission.sms,
      icon: Icons.sms,
    ),
    _PermInfo(
      title: 'Camera/Flashlight Permission',
      description: 'We need camera/flashlight access to use the flashlight in emergencies.',
      permission: Permission.camera,
      icon: Icons.flash_on,
    ),
  ];
  bool _isRequesting = false;

  Future<void> _requestPermission() async {
    setState(() => _isRequesting = true);
    final perm = _permissions[_permIndex].permission;
    final status = await perm.request();
    if (!mounted) return;
    setState(() => _isRequesting = false);
    if (status.isGranted) {
      if (_permIndex < _permissions.length - 1) {
        setState(() => _permIndex++);
      } else {
        // Mark onboarding as complete
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('showOnboarding', false);
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        }
      }
    } else if (status.isPermanentlyDenied) {
      // Show dialog to open app settings
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Permission Required'),
          content: const Text('This permission is required for the app to function. Please enable it in app settings.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
              child: const Text('Open Settings'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final perm = _permissions[_permIndex];
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(perm.icon, size: 80, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 32),
              Text(
                perm.title,
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                perm.description,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18),
              ),
              const SizedBox(height: 32),
              FutureBuilder<PermissionStatus>(
                future: perm.permission.status,
                builder: (context, snapshot) {
                  final granted = snapshot.data?.isGranted ?? false;
                  return ElevatedButton.icon(
                    icon: Icon(granted ? Icons.check_circle : Icons.lock_open),
                    label: Text(granted ? 'Granted' : 'Allow'),
                    onPressed: granted || _isRequesting ? null : _requestPermission,
                  );
                },
              ),
              if (_permIndex > 0)
                TextButton(
                  onPressed: _isRequesting ? null : () => setState(() => _permIndex--),
                  child: const Text('Back'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermInfo {
  final String title;
  final String description;
  final Permission permission;
  final IconData icon;
  const _PermInfo({required this.title, required this.description, required this.permission, required this.icon});
}
