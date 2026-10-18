import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../viewmodels/campaign_viewmodel.dart';
import '../../../viewmodels/auth_viewmodel.dart';

class CampaignDashboardScreen extends StatefulWidget {
  const CampaignDashboardScreen({super.key});

  @override
  State<CampaignDashboardScreen> createState() => _CampaignDashboardScreenState();
}

class _CampaignDashboardScreenState extends State<CampaignDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authVM = Provider.of<AuthViewModel>(context, listen: false);
      Provider.of<CampaignViewModel>(context, listen: false).fetchCampaigns(authVM.userUid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = Provider.of<CampaignViewModel>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bulk Messaging', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: ElevatedButton.icon(
              onPressed: () => context.push('/create-campaign'),
              icon: const Icon(Icons.add),
              label: const Text('New Campaign'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366), // 🚀 NAYA: WhatsApp Green theme
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          )
        ],
      ),
      backgroundColor: Colors.grey.shade50,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Text(
              'Create and manage bulk messaging campaigns with advanced features.',
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Expanded(
            child: vm.isLoading
                ? const Center(child: CircularProgressIndicator())
                : vm.campaigns.isEmpty
                    ? const Center(child: Text('No campaigns yet. Click "New Campaign" to start!'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final bool isMobile = constraints.maxWidth < 700;
                          return GridView.builder(
                            padding: const EdgeInsets.all(16),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: isMobile ? 1 : 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              mainAxisExtent: isMobile ? 170 : 220,
                            ),
                            itemCount: vm.campaigns.length,
                            itemBuilder: (context, index) {
                              final c = vm.campaigns[index];
                              final progressPercent = (c.progress * 100).toStringAsFixed(0);
                              
                              return Card(
                                elevation: 2,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    // Top Header Bar
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF25D366), // 🚀 NAYA: WhatsApp Green
                                        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              c.name,
                                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: Colors.black,
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  c.status == 'Completed' ? Icons.check_circle_outline : Icons.sync, 
                                                  color: Colors.white, size: 14
                                                ),
                                                const SizedBox(width: 4),
                                                Text(c.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          InkWell(
                                            onTap: () async {
                                              final confirm = await showDialog<bool>(
                                                context: context,
                                                builder: (ctx) => AlertDialog(
                                                  title: const Text('Delete Campaign'),
                                                  content: Text('Are you sure you want to delete "${c.name}"?'),
                                                  actions: [
                                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                                    TextButton(
                                                      onPressed: () => Navigator.pop(ctx, true),
                                                      child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                                    ),
                                                  ],
                                                ),
                                              );
                                              if (confirm == true && context.mounted) {
                                                await vm.deleteCampaign(c.id);
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Campaign deleted successfully')),
                                                );
                                              }
                                            },
                                            child: const Padding(
                                              padding: EdgeInsets.all(4.0),
                                              child: Icon(Icons.delete, color: Colors.white70, size: 18),
                                            ),
                                          )
                                        ],
                                      ),
                                    ),
                                    // Progress Bar
                                    Padding(
                                      padding: const EdgeInsets.all(12.0),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              const Text('Progress', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
                                              Text('$progressPercent%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          LinearProgressIndicator(
                                            value: c.progress,
                                            backgroundColor: Colors.grey.shade200,
                                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF25D366)), // 🚀 NAYA: WhatsApp Green
                                            minHeight: 6,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ],
                                      ),
                                    ),
                                    // Stats Grid
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          _StatBox(label: 'Total', value: c.total, color: Colors.grey.shade800, bgColor: Colors.grey.shade100),
                                          _StatBox(label: 'Sent', value: c.sent, color: Colors.green.shade700, bgColor: Colors.green.shade50),
                                          _StatBox(label: 'Pending', value: c.pending, color: Colors.orange.shade700, bgColor: Colors.orange.shade50),
                                          _StatBox(label: 'Failed', value: c.failed, color: Colors.red.shade700, bgColor: Colors.red.shade50),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  final Color bgColor;

  const _StatBox({required this.label, required this.value, required this.color, required this.bgColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text('$value', style: TextStyle(fontSize: 16, color: color, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
