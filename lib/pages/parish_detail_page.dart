import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/parish.dart';
import '../main.dart' show kPrimaryColor, kSecondaryColor, kBackgroundColor, kBackgroundColorDark, kCardColor, kCardColorDark, favoritesManager, themeNotifier;
import '../widgets/custom_icons.dart';

class ParishDetailPage extends StatefulWidget {
  final Parish parish;

  const ParishDetailPage({Key? key, required this.parish}) : super(key: key);

  @override
  State<ParishDetailPage> createState() => _ParishDetailPageState();
}

class _ParishDetailPageState extends State<ParishDetailPage> {
  @override
  void initState() {
    super.initState();
    favoritesManager.addListener(_onChanged);
    themeNotifier.addListener(_onChanged);
  }

  @override
  void dispose() {
    favoritesManager.removeListener(_onChanged);
    themeNotifier.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
  }

  Parish get parish => widget.parish;

  Future<void> _launchMaps() async {
    final address = '${parish.address}, ${parish.city} ${parish.zipCode}';
    final encodedAddress = Uri.encodeComponent(address);
    final Uri mapsUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedAddress');

    if (await canLaunchUrl(mapsUrl)) {
      await launchUrl(mapsUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchPhone() async {
    final phoneNumber = parish.phone.replaceAll(RegExp(r'[^\d+]'), '');
    final Uri phoneUrl = Uri.parse('tel:$phoneNumber');

    if (await canLaunchUrl(phoneUrl)) {
      await launchUrl(phoneUrl);
    }
  }

  Future<void> _launchWebsite() async {
    if (parish.website.isEmpty || parish.website == 'No Website') return;

    String url = parish.website;
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    final Uri websiteUrl = Uri.parse(url);
    if (await canLaunchUrl(websiteUrl)) {
      await launchUrl(websiteUrl, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _launchBulletin() async {
    if (parish.bulletinUrl == null || parish.bulletinUrl!.isEmpty) return;

    final Uri bulletinUri = Uri.parse(parish.bulletinUrl!);
    if (await canLaunchUrl(bulletinUri)) {
      await launchUrl(bulletinUri, mode: LaunchMode.externalApplication);
    }
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final year = (date.year % 100).toString().padLeft(2, '0');
    return '$month-$day-$year';
  }

  Widget _buildHeaderBackground() {
    final hasImage = parish.imageUrl != null && parish.imageUrl!.isNotEmpty;

    if (hasImage) {
      // Show actual parish image with gradient overlay
      return Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: parish.imageUrl!,
            fit: BoxFit.cover,
            placeholder: (context, url) => _buildPlaceholderBackground(),
            errorWidget: (context, url, error) => _buildPlaceholderBackground(),
          ),
          // Gradient overlay for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.7),
                ],
              ),
            ),
          ),
          // Parish name at bottom
          Positioned(
            bottom: 20,
            left: 24,
            right: 24,
            child: Text(
              parish.name,
              style: GoogleFonts.lato(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: const Offset(0, 1),
                    blurRadius: 4,
                    color: Colors.black.withOpacity(0.5),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    } else {
      // Show placeholder background
      return _buildPlaceholderBackground();
    }
  }

  Widget _buildPlaceholderBackground() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            kSecondaryColor,
            kSecondaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.church,
              size: 50,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              parish.name,
              style: GoogleFonts.lato(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFavorite = favoritesManager.isFavorite(parish.name);
    final isDark = themeNotifier.isDarkMode;
    final backgroundColor = isDark ? kBackgroundColorDark : kBackgroundColor;
    final cardColor = isDark ? kCardColorDark : kCardColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // App Bar with Hero Image
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: kSecondaryColor,
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: cardColor.withOpacity(0.9),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new, color: kPrimaryColor, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: cardColor.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    color: isFavorite ? Colors.amber : kPrimaryColor,
                    size: 24,
                  ),
                  onPressed: () {
                    favoritesManager.toggleFavorite(parish.name);
                  },
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeaderBackground(),
            ),
          ),
          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Address Card (tappable to open in maps)
                  _TappableInfoCard(
                    icon: Icon(Icons.location_on, color: kPrimaryColor, size: 26),
                    title: 'Address',
                    content: '${parish.address}\n${parish.city} ${parish.zipCode}',
                    color: kPrimaryColor,
                    cardColor: cardColor,
                    textColor: textColor,
                    actionIcon: Icons.directions,
                    actionLabel: 'Get Directions',
                    onTap: _launchMaps,
                  ),
                  const SizedBox(height: 16),

                  // Bulletin Button
                  if (parish.bulletinUrl != null && parish.bulletinUrl!.isNotEmpty)
                    _BulletinButton(
                      cardColor: cardColor,
                      textColor: textColor,
                      onTap: _launchBulletin,
                    ),
                  if (parish.bulletinUrl != null && parish.bulletinUrl!.isNotEmpty)
                    const SizedBox(height: 16),

                  // Mass Times Card
                  _ScheduleCard(
                    icon: Icon(Icons.access_time, color: kSecondaryColor, size: 26),
                    title: 'Mass Times',
                    items: parish.massTimes,
                    emptyMessage: 'No Mass times available',
                    color: kSecondaryColor,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // Confession Times Card
                  _ScheduleCard(
                    icon: CustomIcon.confession(color: kPrimaryColor, size: 26),
                    title: 'Confession Times',
                    items: parish.confTimes,
                    emptyMessage: 'By Appointment Only',
                    color: kPrimaryColor,
                    cardColor: cardColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                    isDark: isDark,
                  ),
                  const SizedBox(height: 16),

                  // Adoration Times Card
                  if (parish.adoration.isNotEmpty)
                    _ScheduleCard(
                      icon: CustomIcon.monstrance(color: Colors.orange, size: 26),
                      title: 'Adoration',
                      items: parish.adoration,
                      emptyMessage: '',
                      color: Colors.orange,
                      cardColor: cardColor,
                      textColor: textColor,
                      subtextColor: subtextColor,
                      isDark: isDark,
                    ),
                  if (parish.adoration.isNotEmpty)
                    const SizedBox(height: 16),

                  // Events Summary Card
                  if (parish.eventsSummary != null && parish.eventsSummary!.isNotEmpty)
                    _buildEventsCard(cardColor, textColor, subtextColor),
                  if (parish.eventsSummary != null && parish.eventsSummary!.isNotEmpty)
                    const SizedBox(height: 16),

                  // Contact Info Card
                  _buildContactCard(cardColor, textColor, subtextColor),
                  const SizedBox(height: 20),

                  // Last Updated indicator and feedback button
                  _buildDataVerificationSection(subtextColor, cardColor, textColor),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsCard(Color cardColor, Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.purple.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event,
                  color: Colors.purple,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Upcoming Events',
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            parish.eventsSummary!,
            style: GoogleFonts.lato(
              fontSize: 14,
              color: textColor,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataVerificationSection(Color subtextColor, Color cardColor, Color textColor) {
    return Column(
      children: [
        // Last updated text
        if (parish.lastUpdated != null)
          Text(
            'Data last updated: ${_formatDate(parish.lastUpdated!)}',
            style: GoogleFonts.lato(
              fontSize: 12,
              color: subtextColor,
            ),
          ),
        const SizedBox(height: 12),
        // Feedback prompt
        InkWell(
          onTap: () => _showDataFeedbackSheet(cardColor, textColor, subtextColor),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: kPrimaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.fact_check_outlined,
                  size: 16,
                  color: kPrimaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  'Is this information accurate?',
                  style: GoogleFonts.lato(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showDataFeedbackSheet(Color cardColor, Color textColor, Color subtextColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DataFeedbackSheet(
        parish: parish,
        cardColor: cardColor,
        textColor: textColor,
        subtextColor: subtextColor,
      ),
    );
  }

  Widget _buildContactCard(Color cardColor, Color textColor, Color subtextColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kSecondaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.contact_phone,
                  color: kSecondaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                'Contact Information',
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Phone (tappable to call)
          _TappableContactRow(
            icon: Icons.phone,
            label: 'Phone',
            value: parish.phone,
            textColor: textColor,
            subtextColor: subtextColor,
            onTap: parish.phone != 'No Phone Listed' ? _launchPhone : null,
          ),
          const SizedBox(height: 12),
          // Website (tappable to open)
          _TappableContactRow(
            icon: Icons.language,
            label: 'Website',
            value: parish.website.isNotEmpty ? parish.website : 'N/A',
            textColor: textColor,
            subtextColor: subtextColor,
            onTap: (parish.website.isNotEmpty && parish.website != 'No Website') ? _launchWebsite : null,
          ),
        ],
      ),
    );
  }
}

class _TappableInfoCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final String content;
  final Color color;
  final Color cardColor;
  final Color textColor;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback? onTap;

  const _TappableInfoCard({
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
    required this.cardColor,
    required this.textColor,
    required this.actionIcon,
    required this.actionLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 15,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: icon,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      content,
                      style: GoogleFonts.lato(
                        fontSize: 15,
                        color: textColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 12),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        actionIcon,
                        color: color,
                        size: 20,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      actionLabel,
                      style: GoogleFonts.lato(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleCard extends StatelessWidget {
  final Widget icon;
  final String title;
  final List<String> items;
  final String emptyMessage;
  final Color color;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;
  final bool isDark;

  const _ScheduleCard({
    required this.icon,
    required this.title,
    required this.items,
    required this.emptyMessage,
    required this.color,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: icon,
              ),
              const SizedBox(width: 16),
              Text(
                title,
                style: GoogleFonts.lato(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: (isDark ? Colors.white : Colors.grey).withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: subtextColor,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    emptyMessage,
                    style: GoogleFonts.lato(
                      fontSize: 14,
                      color: subtextColor,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            )
          else
            ...items.map((item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(top: 6),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          item,
                          style: GoogleFonts.lato(
                            fontSize: 15,
                            color: textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}

class _TappableContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color textColor;
  final Color subtextColor;
  final VoidCallback? onTap;

  const _TappableContactRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.textColor,
    required this.subtextColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isClickable = onTap != null;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isClickable ? kPrimaryColor : Colors.grey).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 20,
                color: isClickable ? kPrimaryColor : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.lato(
                      fontSize: 12,
                      color: subtextColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      color: isClickable ? kPrimaryColor : textColor,
                      decoration: isClickable ? TextDecoration.underline : null,
                      decorationColor: kPrimaryColor,
                    ),
                  ),
                ],
              ),
            ),
            if (isClickable)
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: kPrimaryColor.withOpacity(0.6),
              ),
          ],
        ),
      ),
    );
  }
}

class _BulletinButton extends StatelessWidget {
  final Color cardColor;
  final Color textColor;
  final VoidCallback onTap;

  const _BulletinButton({
    required this.cardColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 15,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.article,
                  color: Colors.red,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Weekly Bulletin',
                      style: GoogleFonts.lato(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'View the latest parish bulletin',
                      style: GoogleFonts.lato(
                        fontSize: 13,
                        color: textColor.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.open_in_new,
                  color: Colors.red,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DataFeedbackSheet extends StatefulWidget {
  final Parish parish;
  final Color cardColor;
  final Color textColor;
  final Color subtextColor;

  const _DataFeedbackSheet({
    required this.parish,
    required this.cardColor,
    required this.textColor,
    required this.subtextColor,
  });

  @override
  State<_DataFeedbackSheet> createState() => _DataFeedbackSheetState();
}

class _DataFeedbackSheetState extends State<_DataFeedbackSheet> {
  final Set<String> _selectedIssues = {};
  final TextEditingController _commentsController = TextEditingController();
  bool _isSubmitting = false;
  bool? _isAccurate;

  final List<Map<String, dynamic>> _issueOptions = [
    {'id': 'mass_times', 'label': 'Mass Times', 'icon': Icons.access_time},
    {'id': 'confession', 'label': 'Confession Times', 'icon': Icons.favorite},
    {'id': 'adoration', 'label': 'Adoration', 'icon': Icons.brightness_5},
    {'id': 'address', 'label': 'Address', 'icon': Icons.location_on},
    {'id': 'phone', 'label': 'Phone Number', 'icon': Icons.phone},
    {'id': 'website', 'label': 'Website', 'icon': Icons.language},
    {'id': 'other', 'label': 'Other', 'icon': Icons.more_horiz},
  ];

  @override
  void dispose() {
    _commentsController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (_isAccurate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select whether the data is accurate', style: GoogleFonts.lato()),
          backgroundColor: Colors.red[400],
        ),
      );
      return;
    }

    if (_isAccurate == false && _selectedIssues.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select at least one issue', style: GoogleFonts.lato()),
          backgroundColor: Colors.red[400],
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Build email content
    final parish = widget.parish;
    final subject = Uri.encodeComponent(
      _isAccurate == true
          ? 'Data Confirmed: ${parish.name}'
          : 'Data Issue Report: ${parish.name}',
    );

    final bodyLines = <String>[
      'Parish: ${parish.name}',
      'Address: ${parish.address}, ${parish.city} ${parish.zipCode}',
      '',
    ];

    if (_isAccurate == true) {
      bodyLines.add('Status: DATA CONFIRMED ACCURATE');
    } else {
      bodyLines.add('Status: ISSUES REPORTED');
      bodyLines.add('');
      bodyLines.add('Fields with issues:');
      for (final issue in _selectedIssues) {
        final label = _issueOptions.firstWhere((o) => o['id'] == issue)['label'];
        bodyLines.add('  - $label');
      }
      if (_commentsController.text.trim().isNotEmpty) {
        bodyLines.add('');
        bodyLines.add('Additional details:');
        bodyLines.add(_commentsController.text.trim());
      }
    }

    bodyLines.addAll([
      '',
      '---',
      'Sent from Introibo App',
    ]);

    final body = Uri.encodeComponent(bodyLines.join('\n'));
    final mailtoUrl = Uri.parse('mailto:feedback@massgpt.org?subject=$subject&body=$body');

    try {
      if (await canLaunchUrl(mailtoUrl)) {
        await launchUrl(mailtoUrl);
        if (mounted) {
          Navigator.of(context).pop();
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not open email app', style: GoogleFonts.lato()),
              backgroundColor: Colors.red[400],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening email: $e', style: GoogleFonts.lato()),
            backgroundColor: Colors.red[400],
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      padding: EdgeInsets.only(bottom: bottomPadding),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: widget.subtextColor.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kPrimaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.fact_check,
                    color: kPrimaryColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Verify Parish Data',
                        style: GoogleFonts.lato(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: widget.textColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.parish.name,
                        style: GoogleFonts.lato(
                          fontSize: 13,
                          color: widget.subtextColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: widget.subtextColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question
                  Text(
                    'Is the information for this parish accurate?',
                    style: GoogleFonts.lato(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: widget.textColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Yes/No buttons
                  Row(
                    children: [
                      Expanded(
                        child: _ChoiceButton(
                          label: 'Yes, it\'s accurate',
                          icon: Icons.check_circle_outline,
                          isSelected: _isAccurate == true,
                          color: Colors.green,
                          cardColor: widget.cardColor,
                          onTap: () {
                            setState(() {
                              _isAccurate = true;
                              _selectedIssues.clear();
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _ChoiceButton(
                          label: 'No, there\'s an issue',
                          icon: Icons.error_outline,
                          isSelected: _isAccurate == false,
                          color: Colors.orange,
                          cardColor: widget.cardColor,
                          onTap: () {
                            setState(() {
                              _isAccurate = false;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  // Issue selection (only shown when "No" is selected)
                  if (_isAccurate == false) ...[
                    const SizedBox(height: 24),
                    Text(
                      'What needs to be updated?',
                      style: GoogleFonts.lato(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: widget.textColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Select all that apply',
                      style: GoogleFonts.lato(
                        fontSize: 12,
                        color: widget.subtextColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _issueOptions.map((option) {
                        final isSelected = _selectedIssues.contains(option['id']);
                        return _IssueChip(
                          label: option['label'],
                          icon: option['icon'],
                          isSelected: isSelected,
                          cardColor: widget.cardColor,
                          textColor: widget.textColor,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedIssues.remove(option['id']);
                              } else {
                                _selectedIssues.add(option['id']);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    // Comments field
                    Text(
                      'Additional details (optional)',
                      style: GoogleFonts.lato(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.textColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: widget.subtextColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TextField(
                        controller: _commentsController,
                        maxLines: 3,
                        style: GoogleFonts.lato(
                          fontSize: 14,
                          color: widget.textColor,
                        ),
                        decoration: InputDecoration(
                          hintText: 'e.g., "Sunday 10AM Mass has been moved to 10:30AM"',
                          hintStyle: GoogleFonts.lato(
                            fontSize: 14,
                            color: widget.subtextColor,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(16),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  // Submit button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitFeedback,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(
                              _isAccurate == true ? 'Confirm Data' : 'Submit Feedback',
                              style: GoogleFonts.lato(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final Color cardColor;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.cardColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color.withOpacity(0.15) : cardColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.grey.withOpacity(0.3),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? color : Colors.grey,
                size: 28,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.lato(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? color : Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _IssueChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color cardColor;
  final Color textColor;
  final VoidCallback onTap;

  const _IssueChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.cardColor,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? kPrimaryColor : cardColor,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? kPrimaryColor : Colors.grey.withOpacity(0.3),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : textColor,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.lato(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? Colors.white : textColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
