import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/connectivity_service.dart';
import '../../core/theme/app_theme.dart';

class NetworkAwareWidget extends StatelessWidget {
  final Widget child;
  final Widget? offlineWidget;
  final bool showOfflineMessage;

  const NetworkAwareWidget({
    super.key,
    required this.child,
    this.offlineWidget,
    this.showOfflineMessage = true,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, _) {
        // Bağlantı varsa normal widget'ı göster
        if (connectivityService.isConnected) {
          return child;
        }

        // Offline durumunda özel widget varsa onu göster
        if (offlineWidget != null) {
          return offlineWidget!;
        }

        // Varsayılan offline mesajı
        if (showOfflineMessage) {
          return _buildOfflineMessage();
        }

        // Mesaj göstermek istemiyorsa boş widget
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildOfflineMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.wifi_off,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No Internet Connection',
            style: GoogleFonts.openSans(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please check your connection and try again',
            style: GoogleFonts.openSans(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class NetworkAwareButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? offlineMessage;

  const NetworkAwareButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.offlineMessage,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, _) {
        final isConnected = connectivityService.isConnected;
        
        return ElevatedButton(
          onPressed: isConnected ? onPressed : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: isConnected 
              ? AppTheme.primaryNavy 
              : Colors.grey.shade300,
            foregroundColor: isConnected 
              ? Colors.white 
              : Colors.grey.shade600,
          ),
          child: child,
        );
      },
    );
  }
}

class NetworkAwareAction extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final String? offlineTooltip;

  const NetworkAwareAction({
    super.key,
    required this.onPressed,
    required this.child,
    this.offlineTooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, connectivityService, _) {
        final isConnected = connectivityService.isConnected;
        
        return Tooltip(
          message: isConnected ? '' : (offlineTooltip ?? 'No internet connection'),
          child: GestureDetector(
            onTap: isConnected ? onPressed : null,
            child: Opacity(
              opacity: isConnected ? 1.0 : 0.5,
              child: child,
            ),
          ),
        );
      },
    );
  }
}
