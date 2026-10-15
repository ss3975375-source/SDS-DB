import 'package:flutter/material.dart';
import 'offline_message_repository.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({
    super.key,
    required this.conversationId,
    required this.conversationName,
    required this.currentUserId,
    required this.repository,
  });

  final String conversationId;
  final String conversationName;
  final String currentUserId;
  final OfflineMessageRepository repository;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _composer = TextEditingController();
  late Future<List<OfflineMessage>> _messages;
  bool _sending = false;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _messages = widget.repository.listConversation(widget.conversationId);
    _refresh();
  }

  @override
  void dispose() {
    _composer.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_syncing) return;
    _syncing = true;
    try {
      await widget.repository.flushPending();
      await widget.repository.syncConversation(widget.conversationId);
    } catch (_) {
      // Keep locally stored messages visible when offline or the server is unavailable.
    } finally {
      _syncing = false;
      if (mounted) {
        setState(() => _messages = widget.repository.listConversation(widget.conversationId));
      }
    }
  }

  Future<void> _send() async {
    final body = _composer.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    _composer.clear();
    try {
      await widget.repository.sendOrQueue(
        conversationId: widget.conversationId,
        senderId: widget.currentUserId,
        body: body,
      );
      if (mounted) setState(() => _messages = widget.repository.listConversation(widget.conversationId));
      await _refresh();
    } catch (_) {
      if (mounted) {
        _composer.text = body;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Message saved locally if possible. Check your connection and retry sync.')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.conversationName),
      actions: [
        IconButton(
          tooltip: 'Sync messages',
          onPressed: _refresh,
          icon: const Icon(Icons.sync),
        ),
      ],
    ),
    body: Column(
      children: [
        Expanded(
          child: FutureBuilder<List<OfflineMessage>>(
            future: _messages,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Unable to open this conversation.'),
                      const SizedBox(height: 8),
                      FilledButton(onPressed: () => setState(() => _messages = widget.repository.listConversation(widget.conversationId)), child: const Text('Retry')),
                    ],
                  ),
                );
              }
              final items = snapshot.data ?? const <OfflineMessage>[];
              if (items.isEmpty) {
                return RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(children: const [
                    SizedBox(height: 180),
                    Center(child: Text('No messages yet. Say hello.')),
                  ]),
                );
              }
              return RefreshIndicator(
                onRefresh: _refresh,
                child: ListView.builder(
                  reverse: false,
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final message = items[index];
                    final mine = message.senderId == widget.currentUserId;
                    final deleted = message.deletedAt != null;
                    return Align(
                      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .78),
                        child: Card(
                          color: mine ? Theme.of(context).colorScheme.primaryContainer : null,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(deleted ? 'Message deleted' : message.body),
                                const SizedBox(height: 4),
                                Text(
                                  '${TimeOfDay.fromDateTime(message.createdAt.toLocal()).format(context)} · ${message.state == 'pending' ? 'Pending sync' : message.state == 'synced' ? 'Synced' : 'Sent'}',
                                  style: Theme.of(context).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _composer,
                    minLines: 1,
                    maxLines: 5,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Message',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send message',
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
