import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'chat_view_model.dart';

class ChatScreen extends StatelessWidget {
  const ChatScreen({
    super.key, 
    required this.otherUserId,
    required this.otherUserName,
    this.initialMessage,
  });

  final String otherUserId;
  final String otherUserName;
  final String? initialMessage;

  static const Color primaryBlue = Color(0xFF1A237E);
  static const Color primaryNavy = Color(0xFF1A237E);
  static const Color accentOrange = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatViewModel>(
      create: (_) => ChatViewModel()..initialize(otherUserId, otherUserName, initialMessage),
      child: const _ChatContent(),
    );
  }
}

class _ChatContent extends StatefulWidget {
  const _ChatContent();

  @override
  State<_ChatContent> createState() => _ChatContentState();
}

class _ChatContentState extends State<_ChatContent> {
  String _otherUserName = 'Loading...';

  @override
  void initState() {
    super.initState();
    _loadOtherUserInfo();
  }

  Future<void> _loadOtherUserInfo() async {
    final chatScreen = context.findAncestorWidgetOfExactType<ChatScreen>();
    final otherUserId = chatScreen?.otherUserId;
    
    if (otherUserId != null) {
      final vm = Provider.of<ChatViewModel>(context, listen: false);
      final profile = await vm.getUserProfile(otherUserId);
      
      if (mounted) {
        setState(() {
          _otherUserName = profile.displayName;
        });
      }
    } else {
      final otherUserName = chatScreen?.otherUserName ?? 'Unknown User';
      setState(() {
        _otherUserName = otherUserName;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            _otherUserName,
            style: GoogleFonts.openSans(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
        backgroundColor: ChatScreen.primaryBlue,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: const SafeArea(child: _ChatBody()),
    );
  }
}

class _ChatBody extends StatelessWidget {
  const _ChatBody();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Messages list
        Expanded(
          child: _MessagesList(),
        ),
        
        // Message input
        _MessageInput(),
      ],
    );
  }
}

class _MessagesList extends StatefulWidget {
  @override
  State<_MessagesList> createState() => _MessagesListState();
}

class _MessagesListState extends State<_MessagesList> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = true;
  bool _showScrollToBottomButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final isAtBottom = _scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 100;
    
    if (isAtBottom != _isAtBottom) {
      setState(() {
        _isAtBottom = isAtBottom;
        _showScrollToBottomButton = !isAtBottom && _scrollController.position.maxScrollExtent > 0;
      });
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    
    if (animated) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
    
    setState(() {
      _isAtBottom = true;
      _showScrollToBottomButton = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatViewModel>(
      builder: (context, vm, child) {
        if (vm.messages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                Text(
                  'No messages yet',
                  style: GoogleFonts.openSans(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start the conversation!',
                  style: GoogleFonts.openSans(
                    fontSize: 14,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
            ),
          );
        }

        // Yeni mesaj geldiğinde otomatik olarak en alta kaydır (sadece kullanıcı zaten en alttaysa)
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (vm.messages.isNotEmpty && _isAtBottom) {
            _scrollToBottom(animated: false);
          }
        });

        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification.metrics.pixels <= notification.metrics.minScrollExtent + 48) {
                  vm.loadOlderMessages();
                }
                return false;
              },
              child: RepaintBoundary(
                child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                reverse: false,
                physics: const ClampingScrollPhysics(),
                itemCount: vm.messages.length,
                itemBuilder: (context, index) {
                  final message = vm.messages[index];
                  final currentUserId = vm.currentUserProfile?.id ?? FirebaseAuth.instance.currentUser?.uid;
                  final isMe = message.senderId == currentUserId;
                  return _MessageBubble(message: message, isMe: isMe);
                },
              ),
            ),
            ),
            
            // Scroll to bottom button
            if (_showScrollToBottomButton)
              Positioned(
                bottom: 16,
                right: 16,
                child: FloatingActionButton.small(
                  onPressed: () => _scrollToBottom(),
                  backgroundColor: ChatScreen.accentOrange,
                  child: const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _MessageBubble extends StatefulWidget {
  const _MessageBubble({required this.message, required this.isMe});

  final ChatMessage message;
  final bool isMe;

  @override
  State<_MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<_MessageBubble> {
  String _initials = 'U';

  @override
  void initState() {
    super.initState();
    _loadUserInitials();
  }

  Future<void> _loadUserInitials() async {
    final vm = Provider.of<ChatViewModel>(context, listen: false);
    _initials = vm.getInitials(widget.message.senderId);
    
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!widget.isMe) ...[
            // Other user avatar (small)
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: ChatScreen.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: GoogleFonts.openSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
          
          // Message bubble
          Flexible(
            child: GestureDetector(
              onLongPress: widget.isMe ? () => _showMessageOptions(context, widget.message) : null,
              child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: widget.isMe 
                  ? ChatScreen.accentOrange 
                  : Colors.white,
                borderRadius: BorderRadius.circular(18).copyWith(
                  bottomLeft: widget.isMe ? const Radius.circular(18) : const Radius.circular(4),
                  bottomRight: widget.isMe ? const Radius.circular(4) : const Radius.circular(18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.message.content,
                    style: GoogleFonts.openSans(
                      fontSize: 14,
                      color: widget.isMe ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: widget.isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    children: [
                      if (!widget.isMe) ...[
                        Text(
                          _formatTime(widget.message.timestamp),
                          style: GoogleFonts.openSans(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                      if (widget.isMe) ...[
                        _buildMessageStatusIcon(),
                        const SizedBox(width: 4),
                        Text(
                          _formatTime(widget.message.timestamp),
                          style: GoogleFonts.openSans(
                            fontSize: 11,
                            color: Colors.white.withAlpha((0.8 * 255).round()),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              ),
            ),
          ),
          
          if (widget.isMe) ...[
            // My avatar (small)
            Container(
              width: 24,
              height: 24,
              margin: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                color: ChatScreen.primaryNavy,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _initials,
                  style: GoogleFonts.openSans(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays > 0) {
      return '${time.day}/${time.month}';
    } else if (difference.inHours > 0) {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    } else {
      return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }

  Widget _buildMessageStatusIcon() {
    // Geçici mesajlar için saat ikonu
    if (widget.message.id.startsWith('temp_')) {
      return Icon(
        Icons.access_time,
        size: 12,
        color: Colors.white.withValues(alpha: 0.6),
      );
    }
    
    // WhatsApp benzeri iki tik sistemi
    if (widget.message.isRead) {
      // İki tik - mesaj okundu (siyah)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done_all,
            size: 12,
            color: Colors.black87,
          ),
        ],
      );
    } else if (widget.message.isDelivered) {
      // İki tik - mesaj ulaştı (gri)
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.done_all,
            size: 12,
            color: Colors.white.withValues(alpha: 0.8),
          ),
        ],
      );
    } else {
      // Tek tik - mesaj gönderildi
      return Icon(
        Icons.done,
        size: 12,
        color: Colors.white.withValues(alpha: 0.8),
      );
    }
  }

  void _showMessageOptions(BuildContext context, ChatMessage message) {
    // ChatViewModel'i önceden al
    final vm = Provider.of<ChatViewModel>(context, listen: false);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Message', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(bottomSheetContext);
                _deleteMessage(context, message, vm);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _deleteMessage(BuildContext context, ChatMessage message, ChatViewModel vm) {
    
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Message'),
        content: const Text('Are you sure you want to delete this message?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              // Use the pre-obtained vm reference
              vm.deleteMessage(message.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _MessageInput extends StatefulWidget {
  @override
  State<_MessageInput> createState() => _MessageInputState();
}

class _MessageInputState extends State<_MessageInput> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  bool _isComposing = false;
  late AnimationController _sendButtonAnimationController;
  late Animation<double> _sendButtonAnimation;
  Timer? _infoTimer;
  String? _lastInfo;

  @override
  void initState() {
    super.initState();
    _sendButtonAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _sendButtonAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _sendButtonAnimationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _sendButtonAnimationController.dispose();
    _infoTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatViewModel>(
      builder: (context, vm, child) {
        if (vm.info != null && vm.info != _lastInfo) {
          _lastInfo = vm.info;
          _infoTimer?.cancel();
          _infoTimer = Timer(const Duration(seconds: 4), () {
            if (mounted) {
              vm.clearInfo();
            }
          });
        }
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Info message
                if (vm.info != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.green.shade700, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vm.info!,
                            style: GoogleFonts.openSans(
                              fontSize: 12,
                              color: Colors.green.shade800,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Error message
                if (vm.error != null) ...[
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            vm.error!,
                            style: GoogleFonts.openSans(
                              fontSize: 12,
                              color: Colors.red.shade700,
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: () => vm.clearError(),
                          child: Icon(Icons.close, color: Colors.red.shade600, size: 16),
                        ),
                      ],
                    ),
                  ),
                ],
                
                // Message input row
                Row(
                  children: [
                    // Message input field
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: _isComposing 
                              ? ChatScreen.accentOrange.withValues(alpha: 0.5)
                              : Colors.grey.shade300,
                          ),
                        ),
                        child: TextField(
                          controller: _controller,
                          onChanged: (text) {
                            setState(() {
                              _isComposing = text.isNotEmpty && !vm.isSendingMessage;
                            });
                            if (_isComposing) {
                              _sendButtonAnimationController.forward();
                            } else {
                              _sendButtonAnimationController.reverse();
                            }
                          },
                          onSubmitted: _isComposing && !vm.isSendingMessage 
                            ? (text) => _handleSubmitted(vm) 
                            : null,
                          enabled: !vm.isSendingMessage,
                          decoration: InputDecoration(
                            hintText: vm.isSendingMessage ? 'Sending...' : 'Type a message...',
                            hintStyle: GoogleFonts.openSans(
                              color: vm.isSendingMessage 
                                ? Colors.grey.shade400
                                : Colors.grey.shade500,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                          // Performance optimizations
                          enableSuggestions: false,
                          autocorrect: false,
                          textInputAction: TextInputAction.send,
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    
                    // Send button with animation
                    AnimatedBuilder(
                      animation: _sendButtonAnimation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _sendButtonAnimation.value * 0.1 + 0.9,
                          child: Container(
                            decoration: BoxDecoration(
                              color: _isComposing && !vm.isSendingMessage
                                ? ChatScreen.accentOrange 
                                : Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: IconButton(
                              onPressed: _isComposing && !vm.isSendingMessage 
                                ? () => _handleSubmitted(vm) 
                                : null,
                              icon: vm.isSendingMessage
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.send,
                                    color: _isComposing 
                                      ? Colors.white 
                                      : Colors.grey.shade500,
                                    size: 20,
                                  ),
                              padding: const EdgeInsets.all(12),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleSubmitted(ChatViewModel vm) {
    final text = _controller.text.trim();
    if (text.isEmpty || vm.isSendingMessage) return;

    vm.sendMessage(text);
    
    _controller.clear();
    setState(() {
      _isComposing = false;
    });
    _sendButtonAnimationController.reverse();
  }
}
