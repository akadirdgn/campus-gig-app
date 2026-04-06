import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:open_filex/open_filex.dart';
import 'package:campusgig/models/message.dart';
import 'package:campusgig/theme/app_theme.dart';

class MessageBubble extends StatelessWidget {
  final Message message;
  final bool isMe;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback? onSelectionToggled;
  final Color accentColor;
  final Color secondaryAccent;
  final bool useDarkTheme;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.onSelectionToggled,
    this.accentColor = const Color(0xFF7CFF6B),
    this.secondaryAccent = const Color(0xFF1E9D4B),
    this.useDarkTheme = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSelectionMode ? onSelectionToggled : null,
      onLongPress: onSelectionToggled,
      child: Container(
        color: isSelected ? accentColor.withOpacity(0.1) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(
          mainAxisAlignment:
              isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (isSelectionMode && !isMe) _buildSelectionIndicator(),
            Flexible(
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75),
                decoration: BoxDecoration(
                  gradient: isMe
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [accentColor, secondaryAccent],
                        )
                      : null,
                  color: isMe
                      ? null
                      : (useDarkTheme ? const Color(0x1EFFFFFF) : Colors.white),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(24),
                    topRight: const Radius.circular(24),
                    bottomLeft: Radius.circular(isMe ? 24 : 8),
                    bottomRight: Radius.circular(isMe ? 8 : 24),
                  ),
                  border: Border.all(
                    color: isSelected
                        ? accentColor
                        : (isMe
                            ? accentColor.withOpacity(0.45)
                            : Colors.white
                                .withOpacity(useDarkTheme ? 0.12 : 0)),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    if (!isSelected)
                      BoxShadow(
                        color: (isMe ? accentColor : Colors.black)
                            .withOpacity(useDarkTheme ? 0.18 : 0.06),
                        blurRadius: 18,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(24),
                    topRight: const Radius.circular(24),
                    bottomLeft: Radius.circular(isMe ? 24 : 8),
                    bottomRight: Radius.circular(isMe ? 8 : 24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMessageContent(context),
                      _buildMetaFooter(),
                    ],
                  ),
                ),
              ),
            ),
            if (isSelectionMode && isMe) _buildSelectionIndicator(),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectionIndicator() {
    return Padding(
      padding: EdgeInsets.only(
        left: isMe ? 8.0 : 0.0,
        right: !isMe ? 8.0 : 0.0,
        bottom: 8.0,
      ),
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          border: Border.all(
            color: isSelected ? accentColor : Colors.grey.shade400,
            width: 2,
          ),
        ),
        child: isSelected
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context) {
    if (message.type == 'zoom_call') {
      return _buildZoomCard(context);
    }

    if (message.type == 'file') {
      return _buildFileAttachment(context, message.fileName ?? 'Dosya', message.fileLocalPath);
    }

    // Check if it's a PDF Attachment
    // Assuming metadata field: `metadata: {'fileType': 'pdf', 'fileName': 'Ödev_1.pdf', 'fileSize': '2.4 MB'}`
    // If the Message model does not have metadata yet, we can infer by content or add it.
    // For now we check if the content looks like a JSON string with a 'pdf' marker, or standard fallback.

    bool isPdf = false;
    String fileName = 'Document.pdf';
    String fileSize = 'Unknown Size';

    // A simple mockcheck if the content is highly structured like an attachment
    // (In reality, use strongly typed message.metadata maps)
    if (message.content.startsWith('[ATTACHMENT_PDF]')) {
      isPdf = true;
      final parts = message.content.split('|');
      if (parts.length >= 3) {
        fileName = parts[1];
        fileSize = parts[2];
      }
    }

    if (isPdf) {
      return _buildPdfAttachment(fileName, fileSize);
    }

    // Check for Lesson Link
    if (message.content.contains('[LESSON_LINK]')) {
      return _buildLessonLinkMessage(context);
    }

    // Check for Code Snippets
    final codeRegExp = RegExp(r"```([\w]*)\n([\s\S]*?)```");
    if (codeRegExp.hasMatch(message.content)) {
      return _buildRichCodeMessage(context, codeRegExp);
    }

    // Normal Text
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Text(
        message.content,
        style: TextStyle(
          color: isMe
              ? Colors.white
              : (useDarkTheme
                  ? const Color(0xFFE5E7EB)
                  : const Color(0xFF1E293B)),
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildFileAttachment(BuildContext context, String fileName, String? fileLocalPath) {
    return GestureDetector(
      onTap: () async {
        if (fileLocalPath != null && fileLocalPath.isNotEmpty) {
          final result = await OpenFilex.open(fileLocalPath);
          if (result.type != ResultType.done && context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Dosya açılamadı: \${result.message}')));
          }
        } else {
           if (context.mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dosya yolu bulunamadı.')));
           }
        }
      },
      child: Container(
        width: double.infinity,
        color: isMe
            ? Colors.white.withOpacity(0.1)
            : (useDarkTheme ? const Color(0x16FFFFFF) : Colors.grey.shade100),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.file, color: Colors.blue, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    style: TextStyle(
                      color: isMe
                          ? Colors.white
                          : (useDarkTheme ? Colors.white : Colors.black87),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Açmak için dokunun',
                    style: TextStyle(
                      color: isMe
                          ? Colors.white70
                          : (useDarkTheme
                              ? Colors.white54
                              : Colors.grey.shade600),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.externalLink,
              color: isMe ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPdfAttachment(String fileName, String fileSize) {
    return Container(
      width: double.infinity,
      color: isMe
          ? Colors.white.withOpacity(0.1)
          : (useDarkTheme ? const Color(0x16FFFFFF) : Colors.grey.shade100),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child:
                const Icon(LucideIcons.fileText, color: Colors.red, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fileName,
                  style: TextStyle(
                    color: isMe ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  fileSize,
                  style: TextStyle(
                    color: isMe ? Colors.white70 : Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            LucideIcons.download,
            color: isMe ? Colors.white : Colors.grey.shade600,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildRichCodeMessage(BuildContext context, RegExp codeRegExp) {
    // Splits text into plain text chunks and code block chunks
    List<Widget> spans = [];
    int lastEnd = 0;

    for (var match in codeRegExp.allMatches(message.content)) {
      // Add text before code block
      if (match.start > lastEnd) {
        final text = message.content.substring(lastEnd, match.start).trim();
        if (text.isNotEmpty) {
          spans.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              text,
              style: TextStyle(
                  color: isMe ? Colors.white : const Color(0xFF1E293B),
                  fontSize: 14),
            ),
          ));
        }
      }

      // Add Code Block
      final language = match.group(1) ?? '';
      final code = match.group(2) ?? '';
      spans.add(_buildCodeBlock(context, code.trim(), language));

      lastEnd = match.end;
    }

    // Add remaining text
    if (lastEnd < message.content.length) {
      final text = message.content.substring(lastEnd).trim();
      if (text.isNotEmpty) {
        spans.add(Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Text(
            text,
            style: TextStyle(
                color: isMe ? Colors.white : const Color(0xFF1E293B),
                fontSize: 14),
          ),
        ));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spans,
    );
  }

  Widget _buildCodeBlock(BuildContext context, String code, String language) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8), topRight: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  language.isNotEmpty ? language.toUpperCase() : 'CODE',
                  style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.bold),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: code));
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Kopyalandı')));
                  },
                  child: const Row(
                    children: [
                      Icon(LucideIcons.copy, color: Colors.grey, size: 12),
                      SizedBox(width: 4),
                      Text('Kopyala',
                          style: TextStyle(
                              color: Colors.grey,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Scrollable Code Content
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: Text(
              code,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Color(0xFFD4D4D4),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaFooter() {
    if (message.createdAt == null) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 8, top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            DateFormat('HH:mm').format(message.createdAt!),
            style: TextStyle(
              color: isMe ? Colors.white.withOpacity(0.7) : Colors.grey[400],
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (isMe) ...[
            const SizedBox(width: 4),
            Icon(LucideIcons.checkCheck,
                size: 12, color: Colors.white.withOpacity(0.8)),
          ],
        ],
      ),
    );
  }

  Widget _buildZoomCard(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [secondaryAccent, accentColor],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle),
                child: const Icon(LucideIcons.video,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Canlı Ders Odası',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text(
            'Lütfen derse katılmak için aşağıdaki butona tıklayın.',
            style: TextStyle(
                color: Colors.white,
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _launchZoomUrl(context, message.meetingLink),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF2D8CFF),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                elevation: 0,
              ),
              child: const Text('Görüşmeye Katıl',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLessonLinkMessage(BuildContext context) {
    // Extract lesson link and text
    final linkMatch = RegExp(r'\[LESSON_LINK\](.*?)\[\/LESSON_LINK\]')
        .firstMatch(message.content);
    final lessonLink = linkMatch?.group(1) ?? '';
    final textBefore = message.content.substring(0, linkMatch?.start ?? 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (textBefore.isNotEmpty)
            Text(
              textBefore.trim(),
              style: TextStyle(
                color: isMe
                    ? Colors.white
                    : (useDarkTheme
                        ? const Color(0xFFE5E7EB)
                        : const Color(0xFF1E293B)),
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              try {
                final Uri url = Uri.parse(lessonLink);
                if (!await launchUrl(url,
                    mode: LaunchMode.externalApplication)) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ders linki açılamadı.')),
                    );
                  }
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Hata: $e')),
                  );
                }
              }
            },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF38BDF8), Color(0xFF7C3AED)],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF38BDF8).withOpacity(0.4),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      LucideIcons.video,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ders Bağlantısı',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Tıkla - Dersi Aç',
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    LucideIcons.externalLink,
                    color: Colors.white,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _launchZoomUrl(BuildContext context, String? urlString) async {
    if (urlString == null || urlString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçersiz toplantı linki.')));
      return;
    }

    try {
      final Uri url = Uri.parse(urlString);
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                Text('Link açılamadı. Cihazınız desteklemiyor olabilir.')));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Link formatında hata: $e')));
    }
  }
}
