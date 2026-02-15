import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme/app_theme.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final List<_FAQItem> _faqs = [
    _FAQItem(
      question: 'How do I create a listing?',
      answer: 'To create a listing, tap the "Share" button on the home screen, take clear photos of your item, add a descriptive title and detailed description, and publish your listing. Your listing will be visible to people nearby.',
    ),
    _FAQItem(
      question: 'How do I add items to favorites?',
      answer: 'Tap the heart icon on any listing to add it to your favorites. You can view all your saved items in the "Favorites" section of your profile. This helps you keep track of items you\'re interested in.',
    ),
    _FAQItem(
      question: 'How do I contact a giver?',
      answer: 'Tap the "Send Message" button on the listing detail page to start a chat with the giver. Use messaging to ask questions and arrange pickup details.',
    ),
    _FAQItem(
      question: 'Why are location services needed?',
      answer: 'Location services help show you nearby listings and suggest safe meeting points. This saves you time and fuel by connecting you with givers in your community.',
    ),
    _FAQItem(
      question: 'How can I stay safe when meeting for pickup?',
      answer: 'Always meet in public places like coffee shops, shopping centers, or police stations. Avoid meeting alone at night and trust your instincts. GarageLoop recommends well-lit, busy areas for all pickups.',
    ),
    _FAQItem(
      question: 'How do I edit or delete my listing?',
      answer: 'Go to "My Listings" in your profile. Tap the "Edit" button next to the listing you want to modify, or tap "Delete" to remove it completely. Changes will be reflected immediately.',
    ),
    _FAQItem(
      question: 'How does free sharing work?',
      answer: 'All items are free to give and claim. Connect with the giver, arrange a safe pickup, and pass items along when you no longer need them.',
    ),
    _FAQItem(
      question: 'Is GarageLoop free to use?',
      answer: 'Yes! All listings are free to give and claim. There are no listing fees or transaction fees.',
    ),
    _FAQItem(
      question: 'How do I report inappropriate content?',
      answer: 'If you see inappropriate content or behavior, tap the "Report" button on the listing or user profile. Our team reviews all reports and takes appropriate action to maintain a safe community.',
    ),
    _FAQItem(
      question: 'What should I do if I have a problem?',
      answer: 'If you encounter any issues, please check our FAQ first. For additional help, you can reach out through the app\'s support system. We\'re committed to helping you have a great experience.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Help & Support',
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
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAboutUsSection(),
            const SizedBox(height: 24),
            _buildContactSection(),
            const SizedBox(height: 24),
            _buildFAQSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutUsSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.info_outline,
                  color: Color(0xFF4285F4),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'About Us',
                style: GoogleFonts.openSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'We’re a free‑only community for giving and receiving items. No prices, no payments—just neighbors helping neighbors. '
            'Our vision is to expand free sharing worldwide and reduce waste by keeping good items in use. '
            'Our mission is to promote reuse, reduce waste, and strengthen communities through generosity.',
            style: GoogleFonts.openSans(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.volunteer_activism_outlined,
                size: 16,
                color: const Color(0xFF4285F4),
              ),
              const SizedBox(width: 8),
              Text(
                'Free sharing community',
                style: GoogleFonts.openSans(
                  fontSize: 12,
                  color: const Color(0xFF4285F4),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.public_outlined,
                size: 16,
                color: const Color(0xFF4285F4),
              ),
              const SizedBox(width: 8),
              Text(
                'Global reuse vision',
                style: GoogleFonts.openSans(
                  fontSize: 12,
                  color: const Color(0xFF4285F4),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.eco_outlined,
                size: 16,
                color: const Color(0xFF4285F4),
              ),
              const SizedBox(width: 8),
              Text(
                'Reuse over waste',
                style: GoogleFonts.openSans(
                  fontSize: 12,
                  color: const Color(0xFF4285F4),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 16),
              Icon(
                Icons.free_breakfast_outlined,
                size: 16,
                color: const Color(0xFF4285F4),
              ),
              const SizedBox(width: 8),
              Text(
                'Always free',
                style: GoogleFonts.openSans(
                  fontSize: 12,
                  color: const Color(0xFF4285F4),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactSection() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.email_outlined,
                  color: Color(0xFF4285F4),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Contact Us',
                style: GoogleFonts.openSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Need help? We\'re here for you! Reach out to our support team and we\'ll get back to you as soon as possible.',
            style: GoogleFonts.openSans(
              fontSize: 14,
              color: Colors.grey.shade700,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: () async {
              final Uri emailUri = Uri(
                scheme: 'mailto',
                path: 'garageloopwork@gmail.com',
                queryParameters: {
                  'subject': 'GarageLoop Support Request',
                },
              );
              if (await canLaunchUrl(emailUri)) {
                await launchUrl(emailUri);
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not open email app'),
                    ),
                  );
                }
              }
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF4285F4).withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.email,
                    color: Color(0xFF4285F4),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Email Support',
                          style: GoogleFonts.openSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'garageloopwork@gmail.com',
                          style: GoogleFonts.openSans(
                            fontSize: 14,
                            color: const Color(0xFF4285F4),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    color: Color(0xFF4285F4),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We typically respond within 24-48 hours on business days.',
            style: GoogleFonts.openSans(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFAQSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF4285F4).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.help_outline,
                color: Color(0xFF4285F4),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Frequently Asked Questions',
              style: GoogleFonts.openSans(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _faqs.length,
            separatorBuilder: (context, index) => Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: Colors.grey.shade200,
            ),
            itemBuilder: (context, index) {
              return _FAQItemWidget(faq: _faqs[index]);
            },
          ),
        ),
      ],
    );
  }
}

class _FAQItem {
  final String question;
  final String answer;

  _FAQItem({
    required this.question,
    required this.answer,
  });
}

class _FAQItemWidget extends StatefulWidget {
  const _FAQItemWidget({required this.faq});
  final _FAQItem faq;

  @override
  State<_FAQItemWidget> createState() => _FAQItemWidgetState();
}

class _FAQItemWidgetState extends State<_FAQItemWidget> {
  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(
        widget.faq.question,
        style: GoogleFonts.openSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: Colors.black87,
        ),
      ),
      iconColor: const Color(0xFF4285F4),
      collapsedIconColor: Colors.grey.shade600,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Text(
            widget.faq.answer,
            style: GoogleFonts.openSans(
              fontSize: 13,
              color: Colors.grey.shade700,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

