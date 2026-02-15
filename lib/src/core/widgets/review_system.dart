import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ReviewSystem extends StatelessWidget {
  final double rating;
  final int totalReviews;
  final int positiveReviews;
  final int neutralReviews;
  final int negativeReviews;
  final List<Review>? recentReviews;
  final bool showDetailed;

  const ReviewSystem({
    super.key,
    required this.rating,
    required this.totalReviews,
    this.positiveReviews = 0,
    this.neutralReviews = 0,
    this.negativeReviews = 0,
    this.recentReviews,
    this.showDetailed = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                Icons.star,
                color: Colors.amber.shade600,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Reviews & Ratings',
                style: GoogleFonts.openSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Rating overview
          Row(
            children: [
              // Star rating display
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        rating.toStringAsFixed(1),
                        style: GoogleFonts.openSans(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStarRating(rating),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$totalReviews reviews',
                    style: GoogleFonts.openSans(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              
              const Spacer(),
              
              // Review breakdown
              if (showDetailed) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _buildReviewBar('5', 5, positiveReviews, totalReviews),
                    _buildReviewBar('4', 4, positiveReviews, totalReviews),
                    _buildReviewBar('3', 3, neutralReviews, totalReviews),
                    _buildReviewBar('2', 2, negativeReviews, totalReviews),
                    _buildReviewBar('1', 1, negativeReviews, totalReviews),
                  ],
                ),
              ] else ...[
                // Simple stats
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${((positiveReviews / (totalReviews == 0 ? 1 : totalReviews)) * 100).toStringAsFixed(0)}% positive',
                      style: GoogleFonts.openSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.green.shade600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$totalReviews total reviews',
                      style: GoogleFonts.openSans(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          
          // Recent reviews
          if (recentReviews != null && recentReviews!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              'Recent Reviews',
              style: GoogleFonts.openSans(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            ...recentReviews!.take(3).map((review) => _buildReviewItem(review)),
          ],
        ],
      ),
    );
  }

  Widget _buildStarRating(double rating) {
    return Row(
      children: List.generate(5, (index) {
        final starIndex = index + 1;
        final isFilled = starIndex <= rating;
        final isHalfFilled = starIndex - 0.5 <= rating && starIndex > rating;
        
        return Icon(
          isFilled ? Icons.star : (isHalfFilled ? Icons.star_half : Icons.star_border),
          color: Colors.amber.shade600,
          size: 20,
        );
      }),
    );
  }

  Widget _buildReviewBar(String label, int starCount, int count, int total) {
    final percentage = total == 0 ? 0.0 : (count / total);
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.openSans(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.star,
            color: Colors.amber.shade600,
            size: 12,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: percentage,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.amber.shade600,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            count.toString(),
            style: GoogleFonts.openSans(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewItem(Review review) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Reviewer name
              Text(
                review.reviewerName,
                style: GoogleFonts.openSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              // Rating
              _buildStarRating(review.rating),
            ],
          ),
          if (review.comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: GoogleFonts.openSans(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            _formatDate(review.date),
            style: GoogleFonts.openSans(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else {
      return 'Just now';
    }
  }
}

class Review {
  final String id;
  final String reviewerName;
  final double rating;
  final String comment;
  final DateTime date;
  final String? reviewerImageUrl;

  Review({
    required this.id,
    required this.reviewerName,
    required this.rating,
    required this.comment,
    required this.date,
    this.reviewerImageUrl,
  });
}

class ReviewSummary extends StatelessWidget {
  final double rating;
  final int totalReviews;
  final int positiveReviews;
  final int neutralReviews;
  final int negativeReviews;

  const ReviewSummary({
    super.key,
    required this.rating,
    required this.totalReviews,
    this.positiveReviews = 0,
    this.neutralReviews = 0,
    this.negativeReviews = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.star,
          color: Colors.amber.shade600,
          size: 16,
        ),
        const SizedBox(width: 4),
        Text(
          '${rating.toStringAsFixed(1)} • $totalReviews reviews',
          style: GoogleFonts.openSans(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
        if (totalReviews > 0) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _getRatingColor(rating).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getRatingText(rating),
              style: GoogleFonts.openSans(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: _getRatingColor(rating),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4.5) return Colors.green;
    if (rating >= 3.5) return Colors.orange;
    return Colors.red;
  }

  String _getRatingText(double rating) {
    if (rating >= 4.5) return 'Excellent';
    if (rating >= 3.5) return 'Good';
    if (rating >= 2.5) return 'Average';
    return 'Poor';
  }
}
