import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../utils/role_permissions.dart';

class MyProfileView extends StatelessWidget {
  const MyProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = Provider.of<AuthViewModel>(context);
    final data = authVM.userData ?? {};
    final String firstLetter = authVM.userName.trim().isEmpty ? '?' : authVM.userName.trim()[0].toUpperCase();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => context.pop(),
        ),
        title: const Text('My Score', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        children: [
          // Header Profile Info
          Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFFF5F5F5),
                  child: Text(firstLetter, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF888888))),
                ),
                const SizedBox(height: 16),
                Text(authVM.userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF101828))),
                const SizedBox(height: 12),
                
                // 🚀 NAYA: Package and Status in one line
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildCompactTag('Status : Active', Colors.green.shade700),
                    const SizedBox(width: 8),
                    _buildCompactTag('Package : Gold',Colors.amber.shade800 ),
                  ],
                ),
                const SizedBox(height: 8),
                
                // 🚀 NAYA: Role Tag aligned with UI
                _buildCompactTag('Role : ${authVM.roleLabel}', Colors.blue.shade700),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Levels and Points
          _buildMetricsRow(),
          const SizedBox(height: 24),

          // Information Cards
          _buildInfoCard(
            title: 'Membership & Status',
            icon: Icons.verified_user_outlined,
            children: [
              _buildDetailRow('Status', 'Active', isSuccess: true),
              _buildDetailRow('Package', 'Delux'),
              _buildDetailRow('Joined On', '12 Jan 2024'),
            ],
          ),
          const SizedBox(height: 16),

          _buildInfoCard(
            title: 'Account Details',
            icon: Icons.badge_outlined,
            children: [
              _buildDetailRow('Email', authVM.userEmail),
              _buildDetailRow('Phone', data['contactNo']?.toString() ?? 'N/A'),
              _buildDetailRow('User UID', authVM.userUid),
            ],
          ),
          const SizedBox(height: 16),

          if (authVM.appRole == AppRole.viewer) ...[
            () {
              final bool isWaitingApproval = data['cpUpgradeRequested'] == true || data['upgradeStatus'] == 'Waiting for Approval';
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isWaitingApproval ? Colors.amber.shade50 : const Color(0xFFFFF1EA),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: isWaitingApproval ? Colors.amber.shade300 : const Color(0xFFFFD4C2)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          isWaitingApproval ? Icons.hourglass_top_rounded : Icons.workspace_premium_rounded,
                          color: isWaitingApproval ? Colors.amber.shade800 : const Color(0xFFFF6B22),
                          size: 28,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isWaitingApproval ? 'Waiting for Approval' : 'Become a Channel Partner',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                  color: isWaitingApproval ? Colors.amber.shade900 : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                isWaitingApproval
                                    ? 'Your CP upgrade request is under review by Admin.'
                                    : 'Upgrade your account to add leads, list properties, and earn commissions.',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!isWaitingApproval) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 44,
                        child: ElevatedButton(
                          onPressed: () async {
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
                                    backgroundColor: Colors.green,
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
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFF6B22),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                          child: const Text('Apply to Become CP', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }(),
            const SizedBox(height: 16),
          ],

          _buildInfoCard(
            title: 'Notifications',
            icon: Icons.notifications_active_outlined,
            children: [
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Allow Notifications', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                subtitle: const Text('Receive task assignment & system alerts', style: TextStyle(fontSize: 11, color: Colors.grey)),
                value: authVM.allowNotifications,
                activeColor: const Color(0xFF6B5800),
                onChanged: (val) {
                  authVM.setAllowNotifications(val);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Logout Button
          OutlinedButton.icon(
            onPressed: () async {
              await authVM.logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded, size: 20),
            label: const Text('LOGOUT', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: BorderSide(color: Colors.red.shade200),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildCompactTag(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildMetricsRow() {
    return Row(
      children: [
        _buildMetricItem('Level', 'Scout', Icons.military_tech_outlined, Colors.amber.shade700),
        const SizedBox(width: 12),
        _buildMetricItem('Points', '1500', Icons.stars_rounded, const Color(0xFFFF6B22)),
      ],
    );
  }

  Widget _buildMetricItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8), fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 20, color: color, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFFFF6B22), size: 20),
                const SizedBox(width: 12),
                Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1)),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isSuccess = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          const Text(' :  ', style: TextStyle(color: Colors.grey)),
          Expanded(
            flex: 3, 
            child: Text(
              value, 
              style: TextStyle(
                fontWeight: FontWeight.w600, 
                fontSize: 13, 
                color: isSuccess ? Colors.green.shade700 : Colors.black87,
              )
            )
          ),
        ],
      ),
    );
  }
}
