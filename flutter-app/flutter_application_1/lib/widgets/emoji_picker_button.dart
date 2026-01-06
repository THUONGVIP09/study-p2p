import 'package:flutter/material.dart';

/// Simple emoji picker widget for chat
class EmojiPickerButton extends StatelessWidget {
  final Function(String emoji) onEmojiSelected;

  const EmojiPickerButton({
    Key? key,
    required this.onEmojiSelected,
  }) : super(key: key);

  // Common emojis organized by category
  static const List<String> _emojis = [
    // Smileys
    '😀', '😃', '😄', '😁', '😆', '😅', '🤣', '😂',
    '🙂', '😊', '😇', '🥰', '😍', '🤩', '😘', '😗',
    '😚', '😋', '😛', '😜', '🤪', '😝', '🤗', '🤭',
    // Gestures
    '👍', '👎', '👏', '🙌', '🤝', '✌️', '🤞', '🤟',
    '👌', '🤙', '👋', '🖐️', '✋', '🖖', '👊', '✊',
    // Hearts
    '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
    '💕', '💞', '💓', '💗', '💖', '💘', '💝', '💟',
    // Misc
    '🔥', '✨', '🌟', '💫', '⭐', '🎉', '🎊', '🎁',
    '🙏', '💪', '👀', '🤔', '😎', '🥺', '😢', '😭',
    '😤', '😠', '🤯', '😱', '😨', '😰', '😥', '🤗',
    // Animals
    '🐶', '🐱', '🐭', '🐹', '🐰', '🦊', '🐻', '🐼',
    // Objects
    '💻', '📱', '📚', '✏️', '📝', '💡', '🎮', '🎵',
  ];

  void _showEmojiPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => Container(
        height: 280,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Chọn biểu tượng',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 8,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                ),
                itemCount: _emojis.length,
                itemBuilder: (context, index) {
                  return InkWell(
                    onTap: () {
                      onEmojiSelected(_emojis[index]);
                      Navigator.pop(ctx);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: Colors.grey.shade100,
                      ),
                      child: Center(
                        child: Text(
                          _emojis[index],
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.emoji_emotions_outlined),
      color: Colors.amber.shade700,
      tooltip: 'Chọn biểu tượng',
      onPressed: () => _showEmojiPicker(context),
    );
  }
}
