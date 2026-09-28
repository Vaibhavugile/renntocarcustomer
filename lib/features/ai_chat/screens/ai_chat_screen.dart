import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/ai_chat_service.dart';
import '../services/ai_conversation_service.dart';
import '../services/ai_booking_state_service.dart';

class AIChatScreen extends StatefulWidget {
  final String tenantId;
  final String? conversationId;

  const AIChatScreen({
    super.key,
    required this.tenantId,
    this.conversationId,
  });

  @override
  State<AIChatScreen> createState() => _AIChatScreenState();
}

class _AIChatScreenState extends State<AIChatScreen>
    with TickerProviderStateMixin {
  // ============================================================
  // SERVICES
  // ============================================================

  final AIChatService _chatService = AIChatService.instance;
  final AIConversationService _conversationService =
      AIConversationService.instance;

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _messageController =
      TextEditingController();

  final ScrollController _scrollController =
      ScrollController();

  final FocusNode _messageFocusNode =
      FocusNode();

  // ============================================================
  // ANIMATIONS
  // ============================================================

  late final AnimationController _typingController;

  late final Animation<double> _typingAnimation;

  // ============================================================
  // STATE
  // ============================================================

  String? _conversationId;

  Stream<List<AIMessage>>? _messagesStream;

  Map<String, dynamic> _conversationState = {};

  AIBookingState? _bookingState;

  bool _isInitializing = true;

  bool _isSending = false;

  bool _showSuggestions = true;

  bool _showBookingCard = true;

  String? _errorMessage;

  DateTime? _lastMessageScrollTime;

  // ============================================================
  // CONSTANTS
  // ============================================================

  static const Color _background =
      Color(0xFFF7F8FA);

  static const Color _surface =
      Colors.white;

  static const Color _primary =
      Color(0xFF111827);

  static const Color _secondary =
      Color(0xFF6B7280);

  static const Color _border =
      Color(0xFFE5E7EB);

  static const Color _soft =
      Color(0xFFF1F3F5);

  static const Color _aiBubble =
      Color(0xFFF2F4F7);

  static const Color _userBubble =
      Color(0xFF111827);

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  static const List<_AIQuickAction> _quickActions = [
    _AIQuickAction(
      icon: Icons.directions_car_rounded,
      title: 'Find a car',
      message: 'I want to find a car for my trip.',
    ),
    _AIQuickAction(
      icon: Icons.calendar_month_rounded,
      title: 'Book a car',
      message: 'I want to book a car.',
    ),
    _AIQuickAction(
      icon: Icons.payments_outlined,
      title: 'Check price',
      message: 'Can you help me check the rental price?',
    ),
    _AIQuickAction(
      icon: Icons.location_on_outlined,
      title: 'Find a branch',
      message: 'Show me the available pickup branches.',
    ),
  ];

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _typingController = AnimationController(
      vsync: this,
      duration: const Duration(
        milliseconds: 900,
      ),
    )..repeat();

    _typingAnimation = CurvedAnimation(
      parent: _typingController,
      curve: Curves.easeInOut,
    );

    _initializeChat();
  }

  // ============================================================
  // INITIALIZE CHAT
  // ============================================================

  Future<void> _initializeChat() async {
    try {
      setState(() {
        _isInitializing = true;
        _errorMessage = null;
      });

      final conversationId =
          await _chatService.getOrCreateConversation(
        tenantId: widget.tenantId,
        conversationId: widget.conversationId,
      );

      final state =
          await _chatService.getConversationState(
        tenantId: widget.tenantId,
        conversationId: conversationId,
      );

      final bookingState =
          _chatService.getBookingState(state);

      if (!mounted) return;

      setState(() {
        _conversationId = conversationId;
        _conversationState =
            Map<String, dynamic>.from(state);
        _bookingState = bookingState;

        _messagesStream =
            _chatService.messagesStream(
          tenantId: widget.tenantId,
          conversationId: conversationId,
          limit: 100,
        );

        _isInitializing = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isInitializing = false;
        _errorMessage =
            'Unable to open your AI assistant. Please try again.';
      });
    }
  }

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<void> _sendMessage([
    String? predefinedMessage,
  ]) async {
    final text =
        (predefinedMessage ??
                _messageController.text)
            .trim();

    if (text.isEmpty || _isSending) {
      return;
    }

    if (text.length > 4000) {
      _showSnackBar(
        'Please keep your message under 4000 characters.',
        isError: true,
      );
      return;
    }

    _messageController.clear();

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _isSending = true;
      _showSuggestions = false;
      _errorMessage = null;
    });

    try {
      final response =
          await _chatService.sendMessage(
        tenantId: widget.tenantId,
        message: text,
        conversationId: _conversationId,
        conversationState:
            _conversationState,
        metadata: {
          'source': 'customer_ai_chat',
          'platform': 'flutter',
        },
      );

      if (!mounted) return;

      if (response.conversationId != null &&
          response.conversationId!.isNotEmpty) {
        _conversationId =
            response.conversationId;
      }

      _conversationState =
          Map<String, dynamic>.from(
        response.conversationState,
      );

      _bookingState =
          _chatService.getBookingState(
        _conversationState,
      );

      setState(() {
        _isSending = false;
      });

      _scrollToBottom(
        delayed: true,
      );
    } on AIChatException catch (e) {
      if (!mounted) return;

      setState(() {
        _isSending = false;
        _errorMessage = e.message;
      });

      _showSnackBar(
        e.message,
        isError: true,
      );
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isSending = false;
        _errorMessage =
            'Something went wrong. Please try again.';
      });

      _showSnackBar(
        'Unable to send your message.',
        isError: true,
      );
    }
  }

  // ============================================================
  // RETRY
  // ============================================================

  Future<void> _retryInitialization() async {
    await _initializeChat();
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _scrollToBottom({
    bool delayed = false,
  }) {
    if (!mounted) return;

    final now = DateTime.now();

    if (_lastMessageScrollTime != null &&
        now.difference(
              _lastMessageScrollTime!,
            ) <
            const Duration(
              milliseconds: 250,
            )) {
      return;
    }

    _lastMessageScrollTime = now;

    void scroll() {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(
          milliseconds: 350,
        ),
        curve: Curves.easeOutCubic,
      );
    }

    if (delayed) {
      Future.delayed(
        const Duration(
          milliseconds: 120,
        ),
        scroll,
      );
    } else {
      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) => scroll(),
      );
    }
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectPickupDate() async {
    final now = DateTime.now();

    final initialDate =
        _parseDate(
              _bookingState?.pickupDate,
            ) ??
            now;

    final selected =
        await showDatePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(
        const Duration(
          days: 365,
        ),
      ),
      initialDate: initialDate,
      builder: _datePickerBuilder,
    );

    if (selected == null) {
      return;
    }

    final formatted =
        _formatDateForAI(selected);

    await _sendMessage(
      'My pickup date is $formatted.',
    );
  }

  Future<void> _selectReturnDate() async {
    final now = DateTime.now();

    final pickup =
        _parseDate(
          _bookingState?.pickupDate,
        );

    final firstDate =
        pickup ?? now;

    final initialDate =
        _parseDate(
              _bookingState?.returnDate,
            ) ??
            firstDate;

    final selected =
        await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now.add(
        const Duration(
          days: 365,
        ),
      ),
      initialDate: initialDate.isBefore(
        firstDate,
      )
          ? firstDate
          : initialDate,
      builder: _datePickerBuilder,
    );

    if (selected == null) {
      return;
    }

    final formatted =
        _formatDateForAI(selected);

    await _sendMessage(
      'My return date is $formatted.',
    );
  }

  // ============================================================
  // TIME PICKER
  // ============================================================

  Future<void> _selectPickupTime() async {
    final selected =
        await showTimePicker(
      context: context,
      initialTime:
          _parseTime(
                _bookingState?.pickupTime,
              ) ??
              const TimeOfDay(
                hour: 10,
                minute: 0,
              ),
      builder: _timePickerBuilder,
    );

    if (selected == null) {
      return;
    }

    await _sendMessage(
      'My pickup time is ${_formatTime(selected)}.',
    );
  }

  Future<void> _selectReturnTime() async {
    final selected =
        await showTimePicker(
      context: context,
      initialTime:
          _parseTime(
                _bookingState?.returnTime,
              ) ??
              const TimeOfDay(
                hour: 10,
                minute: 0,
              ),
      builder: _timePickerBuilder,
    );

    if (selected == null) {
      return;
    }

    await _sendMessage(
      'My return time is ${_formatTime(selected)}.',
    );
  }

  // ============================================================
  // DATE PICKER THEME
  // ============================================================

  Widget _datePickerBuilder(
    BuildContext context,
    Widget? child,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: _primary,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: _primary,
        ),
        dialogTheme: const DialogThemeData(
          backgroundColor: Colors.white,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  // ============================================================
  // TIME PICKER THEME
  // ============================================================

  Widget _timePickerBuilder(
    BuildContext context,
    Widget? child,
  ) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: const ColorScheme.light(
          primary: _primary,
          onPrimary: Colors.white,
          surface: Colors.white,
          onSurface: _primary,
        ),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }

  // ============================================================
  // QUICK ACTION
  // ============================================================

  void _handleQuickAction(
    _AIQuickAction action,
  ) {
    _sendMessage(action.message);
  }

  // ============================================================
  // NEW CHAT
  // ============================================================

  Future<void> _startNewConversation() async {
    final shouldCreate =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(24),
          ),
          title: const Text(
            'Start a new chat?',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Your current conversation will remain saved. A new AI conversation will start.',
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              style: FilledButton.styleFrom(
                backgroundColor: _primary,
              ),
              child: const Text(
                'New chat',
              ),
            ),
          ],
        );
      },
    );

    if (shouldCreate != true) {
      return;
    }

    try {
      final id =
          await _conversationService
              .createConversation(
        tenantId: widget.tenantId,
      );

      if (!mounted) return;

      setState(() {
        _conversationId = id;
        _conversationState = {};
        _bookingState =
            _chatService
                .createEmptyBookingState();

        _messagesStream =
            _chatService.messagesStream(
          tenantId: widget.tenantId,
          conversationId: id,
          limit: 100,
        );

        _showSuggestions = true;
        _errorMessage = null;
      });

      _scrollToBottom(
        delayed: true,
      );
    } catch (_) {
      _showSnackBar(
        'Unable to start a new conversation.',
        isError: true,
      );
    }
  }

  // ============================================================
  // SHOW BOOKING CARD
  // ============================================================

  bool get _hasBookingProgress {
    final state = _bookingState;

    if (state == null) {
      return false;
    }

    return state.pickupDate != null ||
        state.returnDate != null ||
        state.pickupTime != null ||
        state.returnTime != null ||
        state.pickupBranchName != null ||
        state.returnBranchName != null ||
        state.selectedCarName != null ||
        state.finalAmount != null;
  }

  // ============================================================
  // BOOKING CARD
  // ============================================================

  Widget _buildBookingProgressCard() {
    final state = _bookingState;

    if (state == null ||
        !_hasBookingProgress) {
      return const SizedBox.shrink();
    }

    final steps = <_BookingStep>[
      _BookingStep(
        icon: Icons.calendar_today_rounded,
        title: 'Pickup',
        value: _combine(
          state.pickupDate,
          state.pickupTime,
        ),
        complete:
            state.pickupDate != null &&
                state.pickupTime != null,
        onTap: _selectPickupDate,
      ),
      _BookingStep(
        icon: Icons.event_available_rounded,
        title: 'Return',
        value: _combine(
          state.returnDate,
          state.returnTime,
        ),
        complete:
            state.returnDate != null &&
                state.returnTime != null,
        onTap: _selectReturnDate,
      ),
      _BookingStep(
        icon: Icons.location_on_rounded,
        title: 'Pickup branch',
        value:
            state.pickupBranchName ??
                'Not selected',
        complete:
            state.pickupBranchId != null ||
                state.pickupBranchName != null,
        onTap: () {
          _sendMessage(
            'Show me the available pickup branches.',
          );
        },
      ),
      _BookingStep(
        icon: Icons.directions_car_filled_rounded,
        title: 'Vehicle',
        value:
            state.selectedCarName ??
                state.requestedCarType ??
                'Not selected',
        complete:
            state.selectedCarId != null ||
                state.selectedCarName != null,
        onTap: () {
          _sendMessage(
            'Show me available cars for my selected dates.',
          );
        },
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        8,
      ),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(24),
        border: Border.all(
          color: _border,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            offset: const Offset(
              0,
              8,
            ),
            color:
                Colors.black.withOpacity(
              0.045,
            ),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                child: const Icon(
                  Icons.route_rounded,
                  size: 20,
                  color: _primary,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your rental plan',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight:
                            FontWeight.w800,
                        color: _primary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'We’ll build your booking step by step',
                      style: TextStyle(
                        fontSize: 12,
                        color: _secondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ...steps.map(
            (step) =>
                _buildBookingStep(step),
          ),
          if (state.finalAmount != null) ...[
            const SizedBox(height: 8),
            Container(
              padding:
                  const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius:
                    BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Estimated total',
                          style: TextStyle(
                            color:
                                Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Based on current booking details',
                          style: TextStyle(
                            color:
                                Colors.white,
                            fontWeight:
                                FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _formatMoney(
                      state.finalAmount,
                      state.currency,
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // BOOKING STEP
  // ============================================================

  Widget _buildBookingStep(
    _BookingStep step,
  ) {
    return InkWell(
      onTap: _isSending
          ? null
          : step.onTap,
      borderRadius:
          BorderRadius.circular(16),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          vertical: 7,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: step.complete
                    ? _primary
                    : _soft,
                shape: BoxShape.circle,
              ),
              child: Icon(
                step.complete
                    ? Icons.check_rounded
                    : step.icon,
                size: 18,
                color: step.complete
                    ? Colors.white
                    : _secondary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _secondary,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    step.value,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: step.complete
                          ? _primary
                          : _secondary,
                      fontWeight:
                          step.complete
                              ? FontWeight.w700
                              : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WELCOME
  // ============================================================

  Widget _buildWelcome() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        24,
        16,
        10,
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius:
                  BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color:
                      Colors.black.withOpacity(
                    0.12,
                  ),
                  blurRadius: 20,
                  offset:
                      const Offset(0, 8),
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 27,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Your personal\nrental assistant',
            style: TextStyle(
              fontSize: 29,
              height: 1.08,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.8,
              color: _primary,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Tell me what you need. I can help you find a car, check availability, understand pricing and prepare your booking.',
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: _secondary,
            ),
          ),
          const SizedBox(height: 20),
          _buildQuickActions(),
        ],
      ),
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 9,
      runSpacing: 9,
      children: _quickActions.map(
        (action) {
          return Material(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(16),
            child: InkWell(
              onTap: _isSending
                  ? null
                  : () => _handleQuickAction(
                        action,
                      ),
              borderRadius:
                  BorderRadius.circular(16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 13,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(16),
                  border: Border.all(
                    color: _border,
                  ),
                ),
                child: Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Icon(
                      action.icon,
                      size: 17,
                      color: _primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      action.title,
                      style:
                          const TextStyle(
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ).toList(),
    );
  }

  // ============================================================
  // MESSAGE BUBBLE
  // ============================================================

  Widget _buildMessageBubble(
    AIMessage message,
  ) {
    final isUser = message.isUser;

    return Padding(
      padding: EdgeInsets.only(
        left: isUser ? 48 : 16,
        right: isUser ? 16 : 48,
        top: 5,
        bottom: 5,
      ),
      child: Row(
        mainAxisAlignment:
            isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
        crossAxisAlignment:
            CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            _buildAIAvatar(),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding:
                  const EdgeInsets.fromLTRB(
                15,
                12,
                15,
                9,
              ),
              decoration: BoxDecoration(
                color: isUser
                    ? _userBubble
                    : _aiBubble,
                borderRadius:
                    BorderRadius.only(
                  topLeft:
                      const Radius.circular(
                    20,
                  ),
                  topRight:
                      const Radius.circular(
                    20,
                  ),
                  bottomLeft:
                      Radius.circular(
                    isUser ? 20 : 5,
                  ),
                  bottomRight:
                      Radius.circular(
                    isUser ? 5 : 20,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: isUser
                          ? Colors.white
                          : _primary,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 5),
                  if (message.createdAt != null)
                    Text(
                      _formatMessageTime(
                        message.createdAt!,
                      ),
                      style: TextStyle(
                        fontSize: 9.5,
                        color: isUser
                            ? Colors.white54
                            : _secondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUser)
            const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ============================================================
  // AI AVATAR
  // ============================================================

  Widget _buildAIAvatar() {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: _primary,
        borderRadius:
            BorderRadius.circular(11),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        size: 15,
        color: Colors.white,
      ),
    );
  }

  // ============================================================
  // TYPING INDICATOR
  // ============================================================

  Widget _buildTypingIndicator() {
    if (!_isSending) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        16,
        7,
        60,
        10,
      ),
      child: Row(
        children: [
          _buildAIAvatar(),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            decoration: BoxDecoration(
              color: _aiBubble,
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: AnimatedBuilder(
              animation: _typingAnimation,
              builder: (
                context,
                child,
              ) {
                return Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: List.generate(
                    3,
                    (index) {
                      final value =
                          (_typingAnimation
                                      .value +
                                  index * 0.18) %
                              1;

                      final opacity =
                          0.35 +
                              (value < 0.5
                                  ? value
                                  : 1 - value);

                      return Padding(
                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 2.5,
                        ),
                        child: Opacity(
                          opacity: opacity
                              .clamp(
                            0.35,
                            1.0,
                          ),
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration:
                                const BoxDecoration(
                              color: _secondary,
                              shape:
                                  BoxShape.circle,
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
        ],
      ),
    );
  }

  // ============================================================
  // STREAM CONTENT
  // ============================================================

  Widget _buildMessages() {
    final stream = _messagesStream;

    if (stream == null) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<List<AIMessage>>(
      stream: stream,
      builder: (
        context,
        snapshot,
      ) {
        if (snapshot.hasError) {
          return _buildConversationError();
        }

        final messages =
            snapshot.data ?? [];

        WidgetsBinding.instance
            .addPostFrameCallback(
          (_) {
            if (messages.isNotEmpty) {
              _scrollToBottom();
            }
          },
        );

        final isEmpty =
            messages.isEmpty;

        return CustomScrollView(
          controller: _scrollController,
          physics:
              const BouncingScrollPhysics(),
          slivers: [
            if (isEmpty)
              SliverToBoxAdapter(
                child: _buildWelcome(),
              ),

            if (!isEmpty &&
                _showBookingCard &&
                _hasBookingProgress)
              SliverToBoxAdapter(
                child:
                    _buildBookingProgressCard(),
              ),

            SliverList(
              delegate:
                  SliverChildBuilderDelegate(
                (
                  context,
                  index,
                ) {
                  return _buildMessageBubble(
                    messages[index],
                  );
                },
                childCount:
                    messages.length,
              ),
            ),

            SliverToBoxAdapter(
              child:
                  _buildTypingIndicator(),
            ),

            const SliverPadding(
              padding:
                  EdgeInsets.only(
                bottom: 16,
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // CONVERSATION ERROR
  // ============================================================

  Widget _buildConversationError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: _soft,
                borderRadius:
                    BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: _secondary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Conversation unavailable',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: _primary,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'We couldn’t load your conversation. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: _secondary,
              ),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed:
                  _retryInitialization,
              style:
                  FilledButton.styleFrom(
                backgroundColor: _primary,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
              ),
              child:
                  const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COMPOSER
  // ============================================================

  Widget _buildComposer() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        9,
        12,
        MediaQuery.of(context)
                .viewInsets
                .bottom >
            0
            ? 9
            : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: _border.withOpacity(
              0.85,
            ),
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.035,
            ),
            blurRadius: 18,
            offset:
                const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.end,
          children: [
            _buildComposerIcon(
              icon: Icons.add_rounded,
              onTap:
                  _showAttachmentOptions,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Container(
                constraints:
                    const BoxConstraints(
                  minHeight: 48,
                  maxHeight: 130,
                ),
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius:
                      BorderRadius.circular(
                    18,
                  ),
                ),
                child: TextField(
                  controller:
                      _messageController,
                  focusNode:
                      _messageFocusNode,
                  minLines: 1,
                  maxLines: 5,
                  textInputAction:
                      TextInputAction.newline,
                  textCapitalization:
                      TextCapitalization.sentences,
                  onChanged: (_) {
                    if (mounted) {
                      setState(() {});
                    }
                  },
                  onSubmitted: (_) {
                    if (!HardwareKeyboard
                        .instance
                        .isShiftPressed) {
                      _sendMessage();
                    }
                  },
                  decoration:
                      const InputDecoration(
                    hintText:
                        'Ask me anything...',
                    hintStyle:
                        TextStyle(
                      color: _secondary,
                      fontSize: 14,
                    ),
                    border:
                        InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 13,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            _buildSendButton(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // COMPOSER ICON
  // ============================================================

  Widget _buildComposerIcon({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: _soft,
      shape: const CircleBorder(),
      child: InkWell(
        onTap: _isSending
            ? null
            : onTap,
        customBorder:
            const CircleBorder(),
        child: const SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            Icons.add_rounded,
            size: 22,
            color: _primary,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SEND BUTTON
  // ============================================================

  Widget _buildSendButton() {
    final canSend =
        _messageController.text.trim().isNotEmpty &&
            !_isSending;

    return AnimatedContainer(
      duration:
          const Duration(milliseconds: 180),
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: canSend
            ? _primary
            : _soft,
        shape: BoxShape.circle,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: canSend
              ? _sendMessage
              : null,
          customBorder:
              const CircleBorder(),
          child: Icon(
            Icons.arrow_upward_rounded,
            size: 21,
            color: canSend
                ? Colors.white
                : const Color(
                    0xFF9CA3AF,
                  ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ATTACHMENTS
  // ============================================================

  void _showAttachmentOptions() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              24,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color:
                        const Color(
                      0xFFD1D5DB,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Align(
                  alignment:
                      Alignment.centerLeft,
                  child: Text(
                    'Booking shortcuts',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight:
                          FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildBottomAction(
                  icon: Icons
                      .calendar_month_rounded,
                  title:
                      'Choose pickup date',
                  subtitle:
                      'Select your rental start date',
                  onTap: () {
                    Navigator.pop(
                      context,
                    );
                    _selectPickupDate();
                  },
                ),
                _buildBottomAction(
                  icon: Icons
                      .schedule_rounded,
                  title:
                      'Choose pickup time',
                  subtitle:
                      'Select your pickup slot',
                  onTap: () {
                    Navigator.pop(
                      context,
                    );
                    _selectPickupTime();
                  },
                ),
                _buildBottomAction(
                  icon: Icons
                      .event_available_rounded,
                  title:
                      'Choose return date',
                  subtitle:
                      'Select your return date',
                  onTap: () {
                    Navigator.pop(
                      context,
                    );
                    _selectReturnDate();
                  },
                ),
                _buildBottomAction(
                  icon: Icons
                      .access_time_filled_rounded,
                  title:
                      'Choose return time',
                  subtitle:
                      'Select your return slot',
                  onTap: () {
                    Navigator.pop(
                      context,
                    );
                    _selectReturnTime();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // BOTTOM ACTION
  // ============================================================

  Widget _buildBottomAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 3,
      ),
      leading: Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: _soft,
          borderRadius:
              BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: _primary,
          size: 21,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: _primary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 12,
          color: _secondary,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: _secondary,
      ),
      onTap: onTap,
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        8,
        7,
        8,
        10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: _border.withOpacity(
              0.75,
            ),
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () {
                Navigator.maybePop(
                  context,
                );
              },
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                size: 19,
              ),
              color: _primary,
            ),
            const SizedBox(width: 2),
            _buildAIAvatar(),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rentocar AI',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight:
                          FontWeight.w800,
                      color: _primary,
                    ),
                  ),
                  SizedBox(height: 2),
                  Row(
                    children: [
                      _OnlineDot(),
                      SizedBox(width: 5),
                      Text(
                        'Always here to help',
                        style: TextStyle(
                          fontSize: 11,
                          color: _secondary,
                          fontWeight:
                              FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'New conversation',
              onPressed: _isInitializing
                  ? null
                  : _startNewConversation,
              icon: const Icon(
                Icons.add_comment_outlined,
                size: 21,
              ),
              color: _primary,
            ),
            IconButton(
              tooltip: 'Options',
              onPressed:
                  _showConversationMenu,
              icon: const Icon(
                Icons.more_horiz_rounded,
                size: 23,
              ),
              color: _primary,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CONVERSATION MENU
  // ============================================================

  void _showConversationMenu() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape:
          const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(
          top: Radius.circular(28),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              12,
              20,
              20,
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color:
                        const Color(
                      0xFFD1D5DB,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons
                        .calendar_month_rounded,
                    color: _primary,
                  ),
                  title: const Text(
                    'Booking details',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  subtitle: const Text(
                    'Show your current rental plan',
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                    );

                    setState(() {
                      _showBookingCard =
                          true;
                    });

                    _scrollToBottom(
                      delayed: true,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons
                        .restart_alt_rounded,
                    color: _primary,
                  ),
                  title: const Text(
                    'Start new conversation',
                    style: TextStyle(
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(
                      context,
                    );
                    _startNewConversation();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // INITIAL LOADING
  // ============================================================

  Widget _buildInitialLoading() {
    return Center(
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: _primary,
              borderRadius:
                  BorderRadius.circular(21),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Colors.white,
              size: 29,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Preparing your assistant',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: _primary,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Loading your conversation...',
            style: TextStyle(
              fontSize: 12,
              color: _secondary,
            ),
          ),
          const SizedBox(height: 18),
          const SizedBox(
            width: 24,
            height: 24,
            child:
                CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor:
                  AlwaysStoppedAnimation(
                _primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INITIAL ERROR
  // ============================================================

  Widget _buildInitialError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: _soft,
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: _secondary,
                size: 30,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'We couldn’t start the assistant',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _primary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Please check your connection and try again.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: _secondary,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed:
                  _retryInitialization,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
                  const Text('Try again'),
              style:
                  FilledButton.styleFrom(
                backgroundColor: _primary,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 13,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(
    String message, {
    bool isError = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons
                        .error_outline_rounded
                    : Icons
                        .check_circle_outline_rounded,
                color: Colors.white,
                size: 19,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(14),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
          backgroundColor:
              isError
                  ? const Color(
                      0xFFB42318,
                    )
                  : _primary,
        ),
      );
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  DateTime? _parseDate(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return null;
    }

    try {
      return DateTime.tryParse(
        value.trim(),
      );
    } catch (_) {
      return null;
    }
  }

  TimeOfDay? _parseTime(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return null;
    }

    final parts =
        value.trim().split(':');

    if (parts.length < 2) {
      return null;
    }

    final hour =
        int.tryParse(parts[0]);

    final minute =
        int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return null;
    }

    return TimeOfDay(
      hour: hour,
      minute: minute,
    );
  }

  String _formatDateForAI(
    DateTime date,
  ) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  String _formatTime(
    TimeOfDay time,
  ) {
    final hour =
        time.hourOfPeriod == 0
            ? 12
            : time.hourOfPeriod;

    final minute =
        time.minute.toString().padLeft(
              2,
              '0',
            );

    final period =
        time.period == DayPeriod.am
            ? 'AM'
            : 'PM';

    return '$hour:$minute $period';
  }

  String _formatMessageTime(
    DateTime dateTime,
  ) {
    final hour =
        dateTime.hour % 12 == 0
            ? 12
            : dateTime.hour % 12;

    final minute =
        dateTime.minute
            .toString()
            .padLeft(
              2,
              '0',
            );

    final period =
        dateTime.hour >= 12
            ? 'PM'
            : 'AM';

    return '$hour:$minute $period';
  }

  String _combine(
    String? date,
    String? time,
  ) {
    if (date == null &&
        time == null) {
      return 'Not selected';
    }

    if (date != null &&
        time != null) {
      return '$date • $time';
    }

    return date ?? time ?? 'Not selected';
  }

  String _formatMoney(
    double? amount,
    String? currency,
  ) {
    if (amount == null) {
      return '—';
    }

    final symbol =
        currency == null ||
                currency.isEmpty
            ? '₹'
            : currency == 'INR'
                ? '₹'
                : currency;

    return '$symbol${amount.toStringAsFixed(0)}';
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    _typingController.dispose();
    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor: _background,
      resizeToAvoidBottomInset: true,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isInitializing
                ? _buildInitialLoading()
                : _errorMessage != null &&
                        _conversationId == null
                    ? _buildInitialError()
                    : _buildMessages(),
          ),
          if (!_isInitializing &&
              _conversationId != null)
            _buildComposer(),
        ],
      ),
    );
  }
}

// ==================================================================
// QUICK ACTION MODEL
// ==================================================================

class _AIQuickAction {
  final IconData icon;
  final String title;
  final String message;

  const _AIQuickAction({
    required this.icon,
    required this.title,
    required this.message,
  });
}

// ==================================================================
// BOOKING STEP MODEL
// ==================================================================

class _BookingStep {
  final IconData icon;
  final String title;
  final String value;
  final bool complete;
  final VoidCallback onTap;

  const _BookingStep({
    required this.icon,
    required this.title,
    required this.value,
    required this.complete,
    required this.onTap,
  });
}

// ==================================================================
// ONLINE DOT
// ==================================================================

class _OnlineDot extends StatelessWidget {
  const _OnlineDot();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: 7,
      height: 7,
      decoration: const BoxDecoration(
        color: Color(0xFF16A34A),
        shape: BoxShape.circle,
      ),
    );
  }
}