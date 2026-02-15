import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/app_localizations.dart';
import '../core/theme/app_theme.dart';

class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          l10n.termsOfService,
          style: GoogleFonts.openSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: AppTheme.primaryNavy,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              title: 'Terms of Service',
              content: 'Last updated: ${DateTime.now().year}',
              isHeader: true,
            ),
            const SizedBox(height: 24),
            
            _buildSection(
              title: '1. Acceptance of Terms',
              content: '''
By accessing and using GarageLoop, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to abide by the above, please do not use this service.
              ''',
            ),
            
            _buildSection(
              title: '2. Description of Service',
              content: '''
GarageLoop is a free‑only sharing community that connects givers and claimers in your area. Our service allows users to:

• Create and manage listings for items they want to give away
• Browse and search for free items nearby
• Communicate with other users through our chat system
• Manage their profile and preferences
• Access location-based features and recommendations
              ''',
            ),
            
            _buildSection(
              title: '3. User Accounts',
              content: '''
To use certain features of our service, you must create an account. You agree to:

• Provide accurate and complete information
• Maintain the security of your account credentials
• Notify us immediately of any unauthorized use
• Accept responsibility for all activities under your account
• Be at least 18 years old or have parental consent
              ''',
            ),
            
            _buildSection(
              title: '4. User Conduct',
              content: '''
You agree not to:

• Post illegal, harmful, or inappropriate content
• Harass, threaten, or intimidate other users
• Use the service for commercial purposes without permission
• Attempt to gain unauthorized access to our systems
• Interfere with the proper functioning of the service
• Violate any applicable laws or regulations
              ''',
            ),
            
            _buildSection(
              title: '5. Listing Guidelines',
              content: '''
When creating listings, you must:

• Provide accurate descriptions and photos
• Listings must be free for all users
• Include all relevant condition information
• Not post prohibited items (weapons, drugs, etc.)
• Respond to inquiries in a timely manner
• Remove claimed items promptly
              ''',
            ),
            
            _buildSection(
              title: '6. Safety and Security',
              content: '''
Your safety is our priority. We recommend:

• Meeting in public, well-lit locations
• Bringing a friend or family member to pickups
• Never sharing sensitive personal information
• Trusting your instincts and reporting suspicious activity
• Following local laws and regulations

We are not responsible for meetings or exchanges between users.
              ''',
            ),
            
            _buildSection(
              title: '7. Privacy and Data',
              content: '''
Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your information. By using our service, you consent to our data practices as described in our Privacy Policy.
              ''',
            ),
            
            _buildSection(
              title: '8. Intellectual Property',
              content: '''
• Our app, content, and trademarks are owned by GarageLoop
• You retain ownership of content you post
• You grant us a license to use your content for service provision
• You may not use our intellectual property without permission
              ''',
            ),
            
            _buildSection(
              title: '9. Disclaimers',
              content: '''
We provide our service "as is" without warranties. We are not responsible for:

• The quality or condition of items listed
• Exchanges between users
• User-generated content
• Third-party services or websites
• Technical issues beyond our control
              ''',
            ),
            
            _buildSection(
              title: '10. Limitation of Liability',
              content: '''
To the maximum extent permitted by law, GarageLoop shall not be liable for any indirect, incidental, special, consequential, or punitive damages, including but not limited to loss of profits, data, or use.
              ''',
            ),
            
            _buildSection(
              title: '11. Indemnification',
              content: '''
You agree to indemnify and hold harmless GarageLoop from any claims, damages, or expenses arising from your use of the service or violation of these terms.
              ''',
            ),
            
            _buildSection(
              title: '12. Termination',
              content: '''
We may terminate or suspend your account at any time for violations of these terms. You may also terminate your account at any time by contacting us or using the delete account feature.
              ''',
            ),
            
            _buildSection(
              title: '13. Changes to Terms',
              content: '''
We may update these terms from time to time. We will notify you of material changes by posting the new terms in the app and updating the "Last updated" date. Your continued use constitutes acceptance of the updated terms.
              ''',
            ),
            
            _buildSection(
              title: '14. Governing Law',
              content: '''
These terms are governed by the laws of the United States. Any disputes shall be resolved in the courts of competent jurisdiction within the United States.
              ''',
            ),
            
            _buildSection(
              title: '15. Contact Information',
              content: '''
For questions about these terms, please contact us:

Email: garageloopwork@gmail.com
Address: United States

We will respond to your inquiry within 30 days.
              ''',
            ),
            
            const SizedBox(height: 40),
            
            // Footer
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    'Thank you for using GarageLoop',
                    style: GoogleFonts.openSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.primaryNavy,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'By using our service, you agree to these terms and our commitment to a safe, free sharing community.',
                    style: GoogleFonts.openSans(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({
    required String title,
    required String content,
    bool isHeader = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.openSans(
              fontSize: isHeader ? 24 : 18,
              fontWeight: FontWeight.w600,
              color: isHeader ? AppTheme.primaryNavy : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            content,
            style: GoogleFonts.openSans(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
