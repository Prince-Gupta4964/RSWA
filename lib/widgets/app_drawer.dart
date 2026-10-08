import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../utils/role_permissions.dart';

class AppDrawer extends StatelessWidget {
  const AppDrawer({super.key});

  void _applyToBecomeCP(BuildContext context, AuthViewModel authVM) async {
    try {
      final docId = authVM.userUid;
      final collection = authVM.userData?['collection'] == 'customers' ? 'customers' : 'users';
      await FirebaseFirestore.instance.collection(collection).doc(docId).set({
        'cpUpgradeRequested': true,
        'upgradeStatus': 'Waiting for Approval',
        'requestedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('CP Upgrade Request submitted! Waiting for Admin approval.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final navigationShell = StatefulNavigationShell.of(context);

    final bool isWaitingApproval = authVM.userData?['cpUpgradeRequested'] == true ||
        authVM.userData?['upgradeStatus'] == 'Waiting for Approval';

    return Drawer(
      backgroundColor: Colors.white,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildHeader(context, authVM),
            const SizedBox(height: 20),
            const Divider(),

            // Customer Upgrade Option: Apply to Become CP / Waiting for Approval
            if (authVM.appRole == AppRole.viewer) ...[
              ListTile(
                leading: Icon(
                  isWaitingApproval ? Icons.hourglass_top_rounded : Icons.workspace_premium_rounded,
                  color: isWaitingApproval ? Colors.amber.shade800 : const Color(0xFFFF6B22),
                ),
                title: Text(
                  isWaitingApproval ? 'Waiting for Approval' : 'Apply to Become CP',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isWaitingApproval ? Colors.amber.shade800 : const Color(0xFFFF6B22),
                  ),
                ),
                subtitle: Text(
                  isWaitingApproval ? 'CP upgrade under Admin review' : 'Upgrade account to Channel Partner',
                  style: const TextStyle(fontSize: 11),
                ),
                onTap: isWaitingApproval
                    ? null
                    : () {
                        Navigator.pop(context);
                        _applyToBecomeCP(context, authVM);
                      },
              ),
              const Divider(),
            ],
            
            // Referral Link (For CPs and Admins)
            if (authVM.appRole == AppRole.cp || authVM.canManageUsers)
              ListTile(
                leading: const Icon(Icons.share_outlined, color: Color(0xFFFF6B22)),
                title: const Text('Share Referral Link', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Invite new partners to join', style: TextStyle(fontSize: 11)),
                onTap: () {
                  final String baseUrl = Uri.base.origin; 
                  final refLink = "$baseUrl/#/login?ref=${authVM.userData?['contactNo']}";
                  Clipboard.setData(ClipboardData(text: refLink));
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Referral link copied: $refLink')),
                  );
                },
              ),

            // Standard Navigation
            ListTile(
              leading: const Icon(Icons.dashboard_outlined),
              title: const Text('Dashboard'),
              selected: navigationShell.currentIndex == 0,
              onTap: () {
                Navigator.pop(context);
                navigationShell.goBranch(0);
              },
            ),

            // Restricted: Builders (Admin & Super Admin only)
            if (authVM.canManageUsers)
              ListTile(
                leading: const Icon(Icons.construction_rounded),
                title: const Text('Builders'),
                selected: navigationShell.currentIndex == 3,
                onTap: () {
                  Navigator.pop(context);
                  navigationShell.goBranch(3);
                },
              ),

            // Restricted: Admin Console (Admin & Super Admin only)
            if (authVM.canManageUsers)
              ListTile(
                leading: const Icon(Icons.admin_panel_settings_outlined),
                title: const Text('Admin Console'),
                selected: navigationShell.currentIndex == 4,
                onTap: () {
                  Navigator.pop(context);
                  navigationShell.goBranch(4);
                },
              ),

            // Restricted: Form Dropdowns Manager (Admin & Super Admin only)
            if (authVM.canManageUsers)
              ListTile(
                leading: const Icon(Icons.list_alt_rounded, color: Color(0xFFFF6B22)),
                title: const Text('Form Dropdowns / Companies', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Add & edit company names & options', style: TextStyle(fontSize: 11)),
                onTap: () {
                  Navigator.pop(context);
                  context.push('/dropdown-manager');
                },
              ),

            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: const Text('Recycle Bin'),
              onTap: () {
                Navigator.pop(context);
                context.push('/recycle-bin');
              },
            ),

            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Logout', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(context);
                await authVM.logout();
                if (context.mounted) {
                  context.go('/login');
                }
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AuthViewModel authVM) {
    final data = authVM.userData ?? {};
    final String status = (data['status'] ?? 'Active').toString();
    final String package = (data['membershipPackage'] ?? 'Standard').toString();

    return InkWell(
      onTap: () {
        Navigator.pop(context);
        context.push('/profile');
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundColor: const Color(0xFFFF6B22),
              child: Text(
                authVM.userName.isEmpty ? '?' : authVM.userName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    authVM.userName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
                  ),
                  if (authVM.userEmail.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      authVM.userEmail,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          status,
                          style: const TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          package,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    authVM.roleLabel,
                    style: TextStyle(fontSize: 12, color: const Color(0xFFFF6B22), fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
