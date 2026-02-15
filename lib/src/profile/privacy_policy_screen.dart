import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../l10n/app_localizations.dart';
import '../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          l10n.privacyPolicy,
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
              title: 'Privacy Policy',
              content: 'Last updated: ${DateTime.now().year}',
              isHeader: true,
            ),
            const SizedBox(height: 24),
            
            _buildSection(
              title: '1. Information We Collect',
              content: '''
We collect information you provide directly to us, such as when you create an account, post listings, or contact other users. This may include:

• Account information (name, email)
• Listing information (photos and descriptions)
• Location data (to show nearby items)
• Communication data (chat messages)
• Usage data (app interactions, preferences)
              ''',
            ),
            
            _buildSection(
              title: '2. How We Use Your Information',
              content: '''
We use the information we collect to:

• Provide and maintain our free sharing services
• Connect givers and claimers in your local area
• Support communications between users
• Improve our app and user experience
• Ensure safety and prevent abuse
• Comply with legal obligations
              ''',
            ),
            
            _buildSection(
              title: '3. Information Sharing',
              content: '''
We do not sell your personal information. We may share your information with:

• Other users (as needed for sharing functionality)
• Service providers (cloud storage and infrastructure)
• Law enforcement (when required by law)
• Business partners (with your consent)
              ''',
            ),
            
            _buildSection(
              title: '4. Data Security',
              content: '''
We implement appropriate security measures to protect your information:

• Encryption of data in transit and at rest
• Secure authentication and authorization
• Regular security assessments
• Access controls and monitoring
              ''',
            ),
            
            _buildSection(
              title: '5. Your Rights',
              content: '''
You have the right to:

• Access your personal information
• Correct inaccurate information
• Delete your account and data
• Opt out of certain communications
• Request data portability
              ''',
            ),
            
            _buildSection(
              title: '6. Location Services',
              content: '''
We use location services to:

• Show you nearby listings
• Suggest safe meeting points
• Improve local search results
• Provide location-based features

You can control location access in your device settings.
              ''',
            ),
            
            _buildSection(
              title: '7. Cookies and Tracking',
              content: '''
We use cookies and similar technologies to:

• Remember your preferences
• Analyze app usage
• Improve performance
• Provide personalized content

You can control cookie settings in your browser.
              ''',
            ),
            
            _buildSection(
              title: '8. Third-Party Services',
              content: '''
We use third-party services for:

• Authentication (Google, Apple)
• Analytics (Firebase)
• Cloud storage (Firebase)

These services have their own privacy policies.
              ''',
            ),
            
            _buildSection(
              title: '9. Children\'s Privacy',
              content: '''
Our app is not intended for children under 13. We do not knowingly collect personal information from children under 13. If you believe we have collected such information, please contact us.
              ''',
            ),
            
            _buildSection(
              title: '10. Changes to This Policy',
              content: '''
We may update this privacy policy from time to time. We will notify you of any material changes by:

• Posting the new policy in the app
• Sending you an email notification
• Updating the "Last updated" date

Your continued use of the app constitutes acceptance of the updated policy.
              ''',
            ),
            
            _buildSection(
              title: '11. Contact Us',
              content: '''
If you have questions about this privacy policy, please contact us:

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
                    'We are committed to protecting your privacy and providing a safe free‑sharing experience.',
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
