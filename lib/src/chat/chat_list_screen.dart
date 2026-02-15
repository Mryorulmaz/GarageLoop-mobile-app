import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'chat_list_view_model.dart';
import 'chat_screen.dart';
import 'chat_repository.dart';

class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  static const Color primaryBlue = Color(0xFF1A237E);
  static const Color primaryNavy = Color(0xFF1A237E);
  static const Color accentOrange = Color(0xFFFF8C00);

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChatListViewModel>(
      create: (_) => ChatListViewModel(),
      child: const _ChatListContent(),
    );
  }

}

class _ChatListContent extends StatelessWidget {
  const _ChatListContent();

  void _showSearchDialog(BuildContext context) {
    final vm = context.read<ChatListViewModel>();
    final TextEditingController searchController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Search Conversations',
            style: GoogleFonts.openSans(fontWeight: FontWeight.w600),
          ),
          content: TextField(
            controller: searchController,
            decoration: InputDecoration(
              hintText: 'Enter user name...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onChanged: (value) {
              vm.searchConversations(value);
            },
          ),
          actions: [
            TextButton(
              onPressed: () {
                vm.clearSearch();
                Navigator.of(context).pop();
              },
              child: Text(
                'Clear',
                style: GoogleFonts.openSans(color: Colors.grey.shade600),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Close',
                style: GoogleFonts.openSans(color: ChatListScreen.primaryBlue),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Messages',
          style: GoogleFonts.openSans(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        backgroundColor: ChatListScreen.primaryBlue,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: () => _showSearchDialog(context),
          ),
        ],
      ),
      body: const _ChatListBody(),
    );
  }
}

class _ChatListBody extends StatelessWidget {
  const _ChatListBody();

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatListViewModel>(
      builder: (context, vm, child) {
        if (vm.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (vm.conversations.isEmpty) {
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
                  'No conversations yet',
                  style: GoogleFonts.openSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start chatting with givers and claimers',
                  style: GoogleFonts.openSans(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: () {
                    _showStartChatDialog(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ChatListScreen.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(
                    'Start a Conversation',
                    style: GoogleFonts.openSans(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          );
        }

        return RepaintBoundary(
          child: ListView.builder(
            addAutomaticKeepAlives: false,
            addSemanticIndexes: false,
            itemCount: vm.conversations.length,
            itemBuilder: (context, index) {
              return Selector<ChatListViewModel, ChatConversation>(
                selector: (_, m) => m.conversations[index],
                builder: (context, conversation, __) => _ConversationTile(conversation: conversation),
              );
            },
          ),
        );
      },
    );
  }

  void _showStartChatDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            'Start a Conversation',
            style: GoogleFonts.openSans(fontWeight: FontWeight.w600),
          ),
          content: Text(
            'To start a conversation, go to any product detail page and use the "Send Message" or "Make Offer" buttons.',
            style: GoogleFonts.openSans(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Got it',
                style: GoogleFonts.openSans(color: ChatListScreen.primaryBlue),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ConversationTile extends StatefulWidget {
  const _ConversationTile({required this.conversation});

  final ChatConversation conversation;

  @override
  State<_ConversationTile> createState() => _ConversationTileState();
}

class _ConversationTileState extends State<_ConversationTile> {
  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  void _loadUserProfile() {
    final vm = Provider.of<ChatListViewModel>(context, listen: false);
    final currentUserId = vm.currentUserId;
    if (currentUserId != null) {
      final otherUserId = widget.conversation.getOtherParticipantId(currentUserId);
      if (otherUserId != null && otherUserId.isNotEmpty) {
        vm.loadUserProfile(otherUserId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatListViewModel>(
      builder: (context, vm, child) {
        return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Dismissible(
        key: Key(widget.conversation.id),
        direction: DismissDirection.endToStart, // Sağdan sola kaydırma
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.red,
          child: const Icon(
            Icons.delete,
            color: Colors.white,
            size: 30,
          ),
        ),
        confirmDismiss: (direction) async {
          return await _showDeleteConfirmation(context, vm);
        },
        onDismissed: (direction) {
          // Ignore errors in dismiss callback to prevent crashes
          vm.deleteConversation(widget.conversation.id).catchError((error) {
            debugPrint('Error deleting conversation on dismiss: $error');
          });
        },
        child: GestureDetector(
          onLongPress: () => _showDeleteOptions(context, vm),
          child: ListTile(
            onTap: () {
              vm.markAsRead(widget.conversation.id);
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatScreen(
                    otherUserId: vm.getOtherParticipantId(widget.conversation) ?? 'unknown',
                    otherUserName: vm.getConversationTitle(widget.conversation),
                  ),
                ),
              );
            },
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: ChatListScreen.primaryBlue,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              _getInitials(vm.getConversationTitle(widget.conversation)),
              style: GoogleFonts.openSans(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                vm.getConversationTitle(widget.conversation),
                style: GoogleFonts.openSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (vm.getUnreadCount(widget.conversation) > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: ChatListScreen.accentOrange,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  vm.getUnreadCount(widget.conversation).toString(),
                  style: GoogleFonts.openSans(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              widget.conversation.lastMessage,
              style: GoogleFonts.openSans(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(widget.conversation.lastMessageAt),
              style: GoogleFonts.openSans(
                fontSize: 12,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
            trailing: null,
          ),
        ),
      ),
    );
      },
    );
  }

  String _getInitials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'U';
    final parts = trimmed.split(RegExp(r"\s+")).where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts.first[0].toUpperCase();
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays > 0) {
      return '${time.day}/${time.month}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  // Silme onayı dialog'u
  Future<bool> _showDeleteConfirmation(BuildContext context, ChatListViewModel vm) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text('Are you sure you want to delete this conversation? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  // Basılı tutma ile silme seçenekleri
  void _showDeleteOptions(BuildContext context, ChatListViewModel vm) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete Conversation', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _confirmAndDelete(context, vm);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Silme işlemini onayla ve gerçekleştir
  void _confirmAndDelete(BuildContext context, ChatListViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Conversation'),
        content: const Text('Are you sure you want to delete this conversation? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await vm.deleteConversation(widget.conversation.id);
                if (context.mounted && vm.error != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(vm.error ?? 'Failed to delete conversation')),
                  );
                }
              } catch (e) {
                debugPrint('Error deleting conversation: $e');
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete conversation: ${e.toString()}')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

