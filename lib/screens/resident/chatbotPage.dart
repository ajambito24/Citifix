import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../constants/app_colors.dart';
import '../../controllers/chat_controller.dart';
import '../../utils/screen_util.dart';

class Chatbot extends StatefulWidget {
  const Chatbot({super.key});

  @override
  State<Chatbot> createState() => _ChatbotState();
}

class _ChatbotState extends State<Chatbot> {
  // Soft red used for error bubbles (AppColors.error @ 10%).
  static const Color _errorSoft = Color(0x1AF44336);

  final ChatController _chat = ChatController();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _chat.addListener(_scrollToBottom);
  }

  @override
  void dispose() {
    _chat.removeListener(_scrollToBottom);
    _chat.dispose();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _send([String? preset]) {
    final text = (preset ?? _inputController.text).trim();
    if (text.isEmpty || _chat.isTyping) return;

    _inputController.clear();
    _chat.send(text);
  }

  // ===== UI =====
  @override
  Widget build(BuildContext context) {
    ScreenUtil.init(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 38.w,
              height: 38.w,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.white,
              ),
              child: Icon(
                Icons.smart_toy,
                size: 22.w,
                color: AppColors.primary,
              ),
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CitiFix Assistant',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Ask about reports and the app',
                  style: TextStyle(fontSize: 12.sp),
                ),
              ],
            ),
          ],
        ),
      ),
      body: ListenableBuilder(
        listenable: _chat,
        builder: (context, _) {
          return Column(
            children: [
              Expanded(child: _buildMessageList()),
              _buildInputBar(),
            ],
          );
        },
      ),
    );
  }

  // ===== MESSAGE LIST =====
  Widget _buildMessageList() {
    final messages = _chat.messages;
    final hasFooter = _chat.isTyping || _chat.showSuggestions;
    final itemCount = messages.length + (hasFooter ? 1 : 0);

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: ScreenUtil.maxContentWidth),
        child: ListView.builder(
          controller: _scrollController,
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
          itemCount: itemCount,
          itemBuilder: (context, index) {
            if (index == messages.length) {
              return KeyedSubtree(
                key: const ValueKey('footer'),
                child: _chat.isTyping
                    ? _buildTypingIndicator()
                    : _buildSuggestions(),
              );
            }

            return KeyedSubtree(
              key: ValueKey('message_$index'),
              child: _buildMessage(messages[index]),
            );
          },
        ),
      ),
    );
  }

  double get _bubbleMaxWidth {
    final contentWidth = math.min(
      ScreenUtil.screenWidth,
      ScreenUtil.maxContentWidth,
    );
    return contentWidth * 0.72;
  }

  Widget _botAvatar() {
    return Container(
      width: 30.w,
      height: 30.w,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primarySoft,
      ),
      child: Icon(Icons.smart_toy, size: 17.w, color: AppColors.primary),
    );
  }

  Widget _buildMessage(ChatMessage message) {
    final isUser = message.isUser;

    final Color bubbleColor = isUser
        ? AppColors.primary
        : (message.isError ? _errorSoft : AppColors.white);

    final Color textColor = isUser
        ? AppColors.white
        : (message.isError ? AppColors.error : AppColors.textPrimary);

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: _bubbleMaxWidth),
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(18.r),
          topRight: Radius.circular(18.r),
          bottomLeft: Radius.circular(isUser ? 18.r : 4.r),
          bottomRight: Radius.circular(isUser ? 4.r : 18.r),
        ),
        boxShadow: isUser || message.isError
            ? null
            : [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 12.r,
                  offset: Offset(0, 4.h),
                ),
              ],
      ),
      child: Text(
        message.text,
        style: TextStyle(
          fontSize: 14.sp,
          height: 1.4,
          color: textColor,
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _botAvatar(),
            SizedBox(width: 8.w),
          ],
          Flexible(child: bubble),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 250.ms)
        .slideY(
          begin: 0.15,
          end: 0,
          duration: 250.ms,
          curve: Curves.easeOutCubic,
        );
  }

  // ===== TYPING INDICATOR =====
  Widget _buildTypingIndicator() {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _botAvatar(),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(18.r),
                topRight: Radius.circular(18.r),
                bottomLeft: Radius.circular(4.r),
                bottomRight: Radius.circular(18.r),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadow,
                  blurRadius: 12.r,
                  offset: Offset(0, 4.h),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: 2.5.w),
                  child: Container(
                    width: 8.w,
                    height: 8.w,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                  )
                      .animate(
                        delay: (i * 180).ms,
                        onPlay: (c) => c.repeat(reverse: true),
                      )
                      .fade(begin: 0.3, end: 1, duration: 450.ms)
                      .moveY(begin: 0, end: -4.h, duration: 450.ms),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ===== SUGGESTION CHIPS =====
  Widget _buildSuggestions() {
    return Padding(
      padding: EdgeInsets.only(top: 4.h, left: 38.w),
      child: Wrap(
        spacing: 8.w,
        runSpacing: 8.h,
        children: ChatController.suggestions.map((text) {
          return Material(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(20.r),
            child: InkWell(
              borderRadius: BorderRadius.circular(20.r),
              onTap: () => _send(text),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: AppColors.primary),
                ),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    ).animate(delay: 300.ms).fadeIn(duration: 350.ms);
  }

  // ===== INPUT BAR =====
  Widget _buildInputBar() {
    final isTyping = _chat.isTyping;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 16.r,
            offset: Offset(0, -4.h),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: ScreenUtil.maxContentWidth,
            ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 12.w, 10.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.send,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(fontSize: 15.sp),
                      onSubmitted: (_) => _send(),
                      decoration: _inputDecoration(),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Material(
                    color: isTyping ? AppColors.border : AppColors.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: isTyping ? null : _send,
                      child: SizedBox(
                        width: 48.w,
                        height: 48.w,
                        child: Icon(
                          Icons.send,
                          size: 22.w,
                          color: AppColors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration() {
    OutlineInputBorder border(Color color, [double width = 1]) {
      return OutlineInputBorder(
        borderRadius: BorderRadius.circular(24.r),
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return InputDecoration(
      hintText: 'Type a message...',
      hintStyle: TextStyle(
        fontSize: 14.sp,
        color: AppColors.textSecondary,
      ),
      filled: true,
      fillColor: AppColors.background,
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 18.w, vertical: 14.h),
      border: border(Colors.transparent),
      enabledBorder: border(Colors.transparent),
      focusedBorder: border(AppColors.primary, 1.6),
    );
  }
}