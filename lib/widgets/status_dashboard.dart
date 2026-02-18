import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class StatusDashboard extends StatefulWidget {
  const StatusDashboard({super.key});

  @override
  State<StatusDashboard> createState() => _StatusDashboardState();
}

class _StatusDashboardState extends State<StatusDashboard> {
  Future<List<_PermStatus>> _checkPermissions() async {
    final perms = [
      _PermStatus('Location', Permission.locationWhenInUse, Icons.location_on),
      _PermStatus('SMS', Permission.sms, Icons.sms),
      _PermStatus('Camera/Flashlight', Permission.camera, Icons.flash_on),
    ];
    for (final perm in perms) {
      perm.status = await perm.permission.status;
    }
    return perms;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_PermStatus>>(
      future: _checkPermissions(),
      builder: (context, snapshot) {
        final perms = snapshot.data;
        final hasMissing = perms?.any((p) => !p.status.isGranted) ?? false;
        final missing = perms?.where((p) => !p.status.isGranted).toList() ?? [];
        return Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (hasMissing)
                      IconButton(
                        icon: const Icon(Icons.warning, color: Colors.orange),
                        tooltip: 'Some permissions are missing',
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => StatefulBuilder(
                              builder: (context, setStateDialog) => AlertDialog(
                                title: const Text('Permissions Missing'),
                                content: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('The following permissions are not granted:'),
                                    const SizedBox(height: 8),
                                    ...missing.map((p) => Row(
                                          children: [
                                            Icon(p.icon, color: Colors.orange, size: 20),
                                            const SizedBox(width: 8),
                                            Text(p.label),
                                            const Spacer(),
                                            ElevatedButton(
                                              onPressed: () async {
                                                final status = await p.permission.request();
                                                if (!context.mounted) return;
                                                if (status.isGranted) {
                                                  Navigator.of(context).pop();
                                                  setState(() {}); // Refresh dashboard
                                                } else {
                                                  setStateDialog(() {}); // Refresh dialog
                                                }
                                              },
                                              child: const Text('Allow'),
                                            ),
                                          ],
                                        )),
                                    const SizedBox(height: 16),
                                    const Text('The app may not work properly without these permissions.'),
                                  ],
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('OK'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    Text(
                      'Status Dashboard',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: hasMissing ? Colors.orange.withOpacity(0.14) : Colors.green.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        hasMissing ? 'Needs Attention' : 'All Good',
                        style: TextStyle(
                          color: hasMissing ? Colors.orange.shade800 : Colors.green.shade800,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (perms == null)
                  const CircularProgressIndicator()
                else ...[
                  for (final p in perms)
                    Row(
                      children: [
                        Icon(p.icon, color: p.status.isGranted ? Colors.green : (p.status.isDenied ? Colors.orange : Colors.red)),
                        const SizedBox(width: 8),
                        Text(p.label),
                        const Spacer(),
                        Text(
                          p.status.isGranted
                              ? 'Granted'
                              : p.status.isDenied
                                  ? 'Denied'
                                  : p.status.toString(),
                          style: TextStyle(
                            color: p.status.isGranted ? Colors.green : (p.status.isDenied ? Colors.orange : Colors.red),
                          ),
                        ),
                      ],
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _PermStatus {
  final String label;
  final Permission permission;
  final IconData icon;
  late PermissionStatus status;
  _PermStatus(this.label, this.permission, this.icon);
}
