import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../booking/services/booking_service.dart';
import 'customer_transaction_details_screen.dart';

class CustomerTransactionsScreen extends StatefulWidget {
  const CustomerTransactionsScreen({
    super.key,
    required this.tenantId,
  });

  final String tenantId;

  @override
  State<CustomerTransactionsScreen> createState() =>
      _CustomerTransactionsScreenState();
}

class _CustomerTransactionsScreenState
    extends State<CustomerTransactionsScreen> {
  final BookingService _bookingService = BookingService.instance;

  final ScrollController _scrollController = ScrollController();

  final List<CustomerTransactionItem> _transactions = [];

  CustomerTransactionFilter _filter = CustomerTransactionFilter.all;

  dynamic _cursor;

  bool _isInitialLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasError = false;

  String? _errorMessage;

  static const int _pageSize = 20;

  @override
  void initState() {
    super.initState();

    _scrollController.addListener(_onScroll);

    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();

    super.dispose();
  }

  // ============================================================
  // INITIAL LOAD
  // ============================================================

  Future<void> _loadInitial() async {
    if (!mounted) return;

    setState(() {
      _isInitialLoading = true;
      _hasError = false;
      _errorMessage = null;
      _transactions.clear();
      _cursor = null;
      _hasMore = true;
    });

    try {
      final page =
          await _bookingService.getCustomerTransactionHistory(
        tenantId: widget.tenantId,
        pageSize: _pageSize,
        filter: _filter,
      );

      if (!mounted) return;

      setState(() {
        _transactions.addAll(page.items);
        _cursor = page.nextBookingCursor;
        _hasMore = page.hasMore;
        _isInitialLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isInitialLoading = false;
        _hasError = true;
        _errorMessage = _friendlyError(e);
      });
    }
  }

  // ============================================================
  // LOAD MORE
  // ============================================================

  Future<void> _loadMore() async {
    if (_isLoadingMore ||
        !_hasMore ||
        _cursor == null ||
        _isInitialLoading) {
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final page =
          await _bookingService.getCustomerTransactionHistory(
        tenantId: widget.tenantId,
        pageSize: _pageSize,
        startAfterBooking: _cursor,
        filter: _filter,
      );

      if (!mounted) return;

      setState(() {
        _transactions.addAll(page.items);
        _cursor = page.nextBookingCursor;
        _hasMore = page.hasMore;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoadingMore = false;
      });

      _showError(_friendlyError(e));
    }
  }

  // ============================================================
  // SCROLL
  // ============================================================

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final position = _scrollController.position;

    if (position.pixels >= position.maxScrollExtent - 450) {
      _loadMore();
    }
  }

  // ============================================================
  // FILTER
  // ============================================================

  Future<void> _changeFilter(
    CustomerTransactionFilter filter,
  ) async {
    if (_filter == filter) return;

    setState(() {
      _filter = filter;
    });

    await _loadInitial();
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    await _loadInitial();
  }

  // ============================================================
  // ERROR
  // ============================================================

  String _friendlyError(Object error) {
    final value = error.toString().toLowerCase();

    if (value.contains('permission-denied')) {
      return 'You are not authorized to view these transactions.';
    }

    if (value.contains('network')) {
      return 'Please check your internet connection and try again.';
    }

    return 'Unable to load your transactions right now.';
  }

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================================
  // MONEY
  // ============================================================

  String _money(
    double amount,
    String currency,
  ) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: currency == 'INR' ? '₹' : currency,
      decimalDigits: 2,
    );

    return formatter.format(amount);
  }

  String _date(DateTime date) {
    return DateFormat(
      'dd MMM yyyy, hh:mm a',
    ).format(date.toLocal());
  }

  String _shortDate(DateTime date) {
    return DateFormat(
      'dd MMM, hh:mm a',
    ).format(date.toLocal());
  }

  // ============================================================
  // STATUS
  // ============================================================

  _TransactionVisual _visualFor(
    CustomerTransactionItem item,
  ) {
    final status = item.status
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    if (item.isRefund) {
      if (status.contains('failed')) {
        return const _TransactionVisual(
          icon: Icons.error_outline_rounded,
          label: 'Refund failed',
        );
      }

      if (status.contains('pending')) {
        return const _TransactionVisual(
          icon: Icons.hourglass_top_rounded,
          label: 'Refund pending',
        );
      }

      return const _TransactionVisual(
        icon: Icons.keyboard_return_rounded,
        label: 'Refund processed',
      );
    }

    if (item.isAttempt) {
      if (status.contains('failed')) {
        return const _TransactionVisual(
          icon: Icons.close_rounded,
          label: 'Payment failed',
        );
      }

      if (status.contains('cancel')) {
        return const _TransactionVisual(
          icon: Icons.block_rounded,
          label: 'Payment cancelled',
        );
      }

      if (status.contains('pending') ||
          status.contains('created') ||
          status.contains('processing') ||
          status.contains('initiated')) {
        return const _TransactionVisual(
          icon: Icons.schedule_rounded,
          label: 'Payment pending',
        );
      }

      if (status.contains('success') ||
          status.contains('paid') ||
          status.contains('captured')) {
        return const _TransactionVisual(
          icon: Icons.check_circle_outline_rounded,
          label: 'Payment successful',
        );
      }

      return const _TransactionVisual(
        icon: Icons.payment_rounded,
        label: 'Payment attempt',
      );
    }

    if (status.contains('failed')) {
      return const _TransactionVisual(
        icon: Icons.error_outline_rounded,
        label: 'Payment failed',
      );
    }

    if (status.contains('pending')) {
      return const _TransactionVisual(
        icon: Icons.schedule_rounded,
        label: 'Payment pending',
      );
    }

    return const _TransactionVisual(
      icon: Icons.check_circle_outline_rounded,
      label: 'Payment successful',
    );
  }

  Color _statusColor(
    CustomerTransactionItem item,
  ) {
    final status = item.status.toLowerCase();

    if (item.isRefund) {
      if (status.contains('failed')) {
        return Colors.red;
      }

      if (status.contains('pending')) {
        return Colors.orange;
      }

      return Colors.blue;
    }

    if (status.contains('failed') ||
        status.contains('cancel')) {
      return Colors.red;
    }

    if (status.contains('pending') ||
        status.contains('created') ||
        status.contains('processing')) {
      return Colors.orange;
    }

    return Colors.green;
  }

  bool _isFailed(CustomerTransactionItem item) {
    final status = item.status.toLowerCase();

    return status.contains('failed') ||
        status.contains('cancel');
  }

  bool _isSuccessfulAttempt(
    CustomerTransactionItem item,
  ) {
    final status = item.status.toLowerCase();

    return status.contains('success') ||
        status.contains('successful') ||
        status.contains('paid') ||
        status.contains('captured');
  }

  // ============================================================
  // OPEN TRANSACTION DETAILS
  // ============================================================

  void _openTransaction(
    CustomerTransactionItem item,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            CustomerTransactionDetailsScreen(
          transaction: item,
          tenantId: widget.tenantId,
        ),
      ),
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final primary =
        Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF101318),
        title: const Text(
          'Transactions',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSummary(),
          _buildFilters(primary),
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SUMMARY
  // ============================================================

  Widget _buildSummary() {
    final totalPayments = _transactions
        .where(
          (e) =>
              e.isPayment &&
              !e.isRefund &&
              !_isFailed(e),
        )
        .fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );

    final totalRefunds = _transactions
        .where(
          (e) =>
              e.isRefund &&
              !_isFailed(e),
        )
        .fold<double>(
          0,
          (sum, e) => sum + e.amount,
        );

    return Container(
      width: double.infinity,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(
        16,
        8,
        16,
        16,
      ),
      child: Row(
        children: [
          Expanded(
            child: _summaryCard(
              title: 'Payments',
              value: '₹${totalPayments.toStringAsFixed(0)}',
              icon: Icons.arrow_upward_rounded,
              color: Colors.green,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _summaryCard(
              title: 'Refunds',
              value: '₹${totalRefunds.toStringAsFixed(0)}',
              icon: Icons.keyboard_return_rounded,
              color: Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withOpacity(.10),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // FILTERS
  // ============================================================

  Widget _buildFilters(Color primary) {
    return Container(
      height: 68,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _filterChip(
            label: 'All',
            filter: CustomerTransactionFilter.all,
            primary: primary,
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: 'Payments',
            filter: CustomerTransactionFilter.payments,
            primary: primary,
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: 'Refunds',
            filter: CustomerTransactionFilter.refunds,
            primary: primary,
          ),
          const SizedBox(width: 8),
          _filterChip(
            label: 'Attempts',
            filter: CustomerTransactionFilter.attempts,
            primary: primary,
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required CustomerTransactionFilter filter,
    required Color primary,
  }) {
    final selected = _filter == filter;

    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected
              ? Colors.white
              : const Color(0xFF24272D),
          fontWeight: FontWeight.w700,
          fontSize: 13,
        ),
      ),
      selected: selected,
      onSelected: (_) => _changeFilter(filter),
      selectedColor: primary,
      backgroundColor: const Color(0xFFF1F2F4),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isInitialLoading) {
      return _buildLoading();
    }

    if (_hasError) {
      return _buildError();
    }

    if (_transactions.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          30,
        ),
        itemCount: _transactions.length +
            (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _transactions.length) {
            return _buildLoadingMore();
          }

          return _buildTransactionCard(
            _transactions[index],
          );
        },
      ),
    );
  }

  // ============================================================
  // TRANSACTION CARD
  // ============================================================

  Widget _buildTransactionCard(
    CustomerTransactionItem item,
  ) {
    final visual = _visualFor(item);
    final statusColor = _statusColor(item);

    final amountPrefix = item.isRefund
        ? '-'
        : item.isAttempt &&
                !_isSuccessfulAttempt(item)
            ? ''
            : '+';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE9EBEF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(.025),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _openTransaction(item),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ICON
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color:
                        statusColor.withOpacity(.09),
                    borderRadius:
                        BorderRadius.circular(15),
                  ),
                  child: Icon(
                    visual.icon,
                    color: statusColor,
                    size: 21,
                  ),
                ),

                const SizedBox(width: 13),

                // CONTENT
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              visual.label,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$amountPrefix${_money(item.amount, item.currency)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight:
                                  FontWeight.w900,
                              color: item.isRefund
                                  ? Colors
                                      .blue
                                      .shade700
                                  : statusColor,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 6),

                      Text(
                        'Booking #${item.bookingId}',
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13,
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),

                      const SizedBox(height: 6),

                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              item.paymentMethod
                                      .trim()
                                      .isEmpty
                                  ? 'Razorpay'
                                  : item.paymentMethod,
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Container(
                            width: 3,
                            height: 3,
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.grey.shade400,
                              shape:
                                  BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          Flexible(
                            child: Text(
                              _shortDate(item.date),
                              maxLines: 1,
                              overflow:
                                  TextOverflow.ellipsis,
                              style: TextStyle(
                                color:
                                    Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),

                      if (item.failureReason !=
                              null &&
                          item.failureReason!
                              .trim()
                              .isNotEmpty) ...[
                        const SizedBox(height: 7),
                        Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal: 8,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.red
                                .withOpacity(.06),
                            borderRadius:
                                BorderRadius.circular(
                              8,
                            ),
                          ),
                          child: Text(
                            item.failureReason!,
                            maxLines: 1,
                            overflow:
                                TextOverflow.ellipsis,
                            style: TextStyle(
                              color:
                                  Colors.red.shade600,
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 4),

                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.black26,
                  size: 22,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // LOADING
  // ============================================================

  Widget _buildLoading() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, index) {
        return Container(
          height: 94,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const SizedBox(width: 15),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: Color(0xFFEDEFF2),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 13,
                      width: 160,
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(0xFFEDEFF2),
                        borderRadius:
                            BorderRadius.circular(6),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Container(
                      height: 10,
                      width: 110,
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(0xFFF1F2F4),
                        borderRadius:
                            BorderRadius.circular(6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingMore() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // EMPTY
  // ============================================================

  Widget _buildEmpty() {
    String title = 'No transactions yet';
    String subtitle =
        'Your payment history will appear here.';

    if (_filter ==
        CustomerTransactionFilter.payments) {
      title = 'No payments yet';
      subtitle =
          'Successful payments will appear here.';
    } else if (_filter ==
        CustomerTransactionFilter.refunds) {
      title = 'No refunds yet';
      subtitle =
          'Your processed refunds will appear here.';
    } else if (_filter ==
        CustomerTransactionFilter.attempts) {
      title = 'No payment attempts';
      subtitle =
          'Your payment attempts will appear here.';
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: Color(0xFFEFF1F4),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                size: 38,
                color: Color(0xFF777D87),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _refresh,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 78,
              height: 78,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                color: Colors.red,
                size: 36,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Unable to load transactions',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage ??
                  'Something went wrong. Please try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _refresh,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionVisual {
  final IconData icon;
  final String label;

  const _TransactionVisual({
    required this.icon,
    required this.label,
  });
}
