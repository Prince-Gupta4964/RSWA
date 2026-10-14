import 'package:flutter/material.dart';

class PrivacyPolicyView extends StatelessWidget {
  const PrivacyPolicyView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        surfaceTintColor: Colors.transparent,
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy for Property+',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 8),
            Text(
              'Effective Date: October 14, 2026',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            SizedBox(height: 24),
            Text(
              'Property+ ("we," "our," or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you visit or use our mobile application (the "App"). Please read this Privacy Policy carefully. If you do not agree with the terms of this privacy policy, please do not access the application.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
            SizedBox(height: 24),
            
            _SectionTitle(title: '1. Information We Collect'),
            Text(
              'We collect several types of information from and about users of our App, including information by which you may be personally identified, information about your real estate transactions, and usage metrics captured automatically during your sessions.\n\n'
              '• Personal Identification Data: Full name, personal and business email address, primary and secondary telephone numbers, professional role, agency name, and user account credentials provided upon registration.\n'
              '• Property and Listing Data: Specific geographical locations, property addresses, pricing details, specifications, photographs, floor plans, virtual tours, availability status, and lead interaction logs.\n'
              '• Technical and Usage Data: IP address, mobile device unique identifier (UUID), operating system version, browser type, network provider, crash logs, and feature usage analytics collected via standard server logs.\n'
              '• Device Permissions: Camera access to capture property photos, photo gallery access for upload functionality, storage access to persist temporary application data, and notification permissions for real-time lead alerts.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
            SizedBox(height: 24),

            _SectionTitle(title: '2. How We Use Your Information'),
            Text(
              'We utilize the collected information to operate, maintain, enhance, and personalize your experience with Property+. Specific business purposes include:\n\n'
              '• Provisioning, maintaining, and authenticating user accounts and user profiles.\n'
              '• Facilitating real estate property listings, lead routing, and portfolio management.\n'
              '• Executing authorized communications via third-party integrations (e.g., WhatsApp API) for direct lead management and client outreach.\n'
              '• Managing team collaboration, task assignment, role permissions, and agency administration.\n'
              '• Analyzing trends, auditing usage metrics, and diagnosing service glitches to optimize App stability and responsiveness.\n'
              '• Delivering mandatory operational communications, security updates, feature announcements, and system alerts.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
            SizedBox(height: 24),

            _SectionTitle(title: '3. Sharing & Disclosure of Information'),
            Text(
              'We respect your privacy and do not sell, rent, or lease your personal information to third parties for marketing purposes. We share data only under the following strictly defined conditions:\n\n'
              '• Legal and Regulatory Requirements: We may disclose personal data if required by law, subpoena, judicial court order, or to enforce our legal rights and terms of service.\n'
              '• Service Providers & Infrastructure: We share necessary elements of data with vetted third-party infrastructure providers (e.g., Firebase, cloud storage vendors, database hosting, and authentication services) to ensure reliable platform performance.\n'
              '• Business Transfers: In the event of a merger, acquisition, corporate reorganization, or sale of assets, user data may be transferred as part of the transaction under equivalent confidentiality protections.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
            SizedBox(height: 24),

            _SectionTitle(title: '4. Data Security and Retention'),
            Text(
              'We implement robust industry-standard technical, administrative, and physical safeguards—including SSL/TLS encryption for data in transit and AES encryption for data at rest—to prevent unauthorized access, alterative disclosure, or destruction of your information. Data is retained only for as long as your account remains active or as required by applicable legal, tax, and accounting regulations.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
            SizedBox(height: 24),

            _SectionTitle(title: '5. User Rights & Data Deletion'),
            Text(
              'You hold full rights regarding your personal information, including the right to access, rectify, port, or request permanent deletion of your account and associated records. You may submit account deletion requests via the account settings inside the App or by contacting support directly. Upon verified submission, your data will be purged or irreversibly anonymized from active databases within 30 days, subject to legitimate legal retention requirements.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
            SizedBox(height: 24),

            _SectionTitle(title: '6. Children\'s Privacy Protection'),
            Text(
              'Property+ is designed exclusively for adults and commercial real estate professionals. We do not knowingly solicit or collect personal data from individuals under the age of 18 (or 13 in relevant jurisdictions). If we discover that personal information of a minor has been gathered inadvertently, we will immediately delete the associated account and data logs.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
            SizedBox(height: 24),

            _SectionTitle(title: '7. Updates to This Privacy Policy'),
            Text(
              'We reserve the right to revise or update this Privacy Policy periodically to align with legal compliance, technological advancements, or App operational changes. We will notify you of material changes via push notifications or prominent in-app notices prior to updates taking effect.',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
            SizedBox(height: 24),

            _SectionTitle(title: '8. Contact Us'),
            Text(
              'If you have questions or comments about this Privacy Policy, please contact us at:\n\nEmail: atechitcompany@gmail.com',
              style: TextStyle(fontSize: 14, height: 1.5, color: Colors.black87),
            ),
            SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
      ),
    );
  }
}
