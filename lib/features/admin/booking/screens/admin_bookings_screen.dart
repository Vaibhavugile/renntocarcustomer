import 'dart:async';
import 'dart:developer' as developer;

import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/config/app_config.dart';
import '../../../booking/models/booking.dart';
import '../../../booking/services/booking_service.dart';
import 'admin_booking_details_screen.dart';

/// Admin Bookings Command Center
///
/// This screen intentionally focuses on the BOOKINGS LIST / OPERATIONS view.
/// Detailed booking information should be opened in a separate
/// BookingDetailsScreen later through [onOpenBookingDetails].
///
/// Included:
/// - Today pickup dashboard
/// - Today's returns
/// - Active rentals
/// - Pending approvals
/// - Upcoming rentals
/// - Payment outstanding
/// - Completed / cancelled / rejected / no-show counts
/// - Full status filters
/// - Payment filters
/// - Date scope filters
/// - Search by booking/customer/phone/vehicle
/// - Operational timeline
/// - Booking cards with pricing, payment and lifecycle information
/// - Responsive desktop/tablet/mobile layout
class AdminBookingsScreen extends StatefulWidget {
  const AdminBookingsScreen({
    super.key,
    this.onOpenBookingDetails,
    this.onCreateBooking,
  });

  /// Optional external hook. If supplied, it is called instead of the
  /// built-in Booking Details navigation.
  final ValueChanged<Booking>? onOpenBookingDetails;

  /// Connect this to your New Booking screen.
  final VoidCallback? onCreateBooking;

  @override
  State<AdminBookingsScreen> createState() => _AdminBookingsScreenState();
}

enum _BookingSearchField {
  all,
  bookingId,
  customerName,
  customerPhone,
  customerEmail,
  registrationNumber,
  carName,
  carId,
  pickupDate,
  returnDate,
  createdDate,
  branch,
  status,
  paymentStatus,
}

class _AdminBookingsScreenState extends State<AdminBookingsScreen> with WidgetsBindingObserver {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const int _pageSize = 100;

  List<Booking> _allBookings = <Booking>[];
  DocumentSnapshot<Map<String, dynamic>>? _lastDocument;
  bool _hasMoreBookings = true;
  bool _loading = true;
  bool _loadingMore = false;
  bool _refreshing = false;
  bool _searching = false;
  String? _error;
  Timer? _searchDebounce;
  Timer? _autoRefreshTimer;
  bool _suppressSearchListener = false;
  bool _refreshInFlight = false;
  int _loadGeneration = 0;
  DateTime? _lastRefreshedAt;

  // KPI values are loaded independently from the paginated list so the
  // dashboard remains accurate even when only the first 100 bookings are
  // currently in memory.
  int _kpiTodayPickupCount = 0;
  int _kpiTodayReturnCount = 0;
  int _kpiActiveCount = 0;
  int _kpiPickupPendingCount = 0;
  int _kpiReturnPendingCount = 0;
  int _kpiPendingCount = 0;
  int _kpiConfirmedCount = 0;
  int _kpiUpcomingCount = 0;
  int _kpiOutstandingCount = 0;
  int _kpiCompletedCount = 0;
  int _kpiCancelledCount = 0;
  int _kpiRejectedCount = 0;
  int _kpiNoShowCount = 0;
  double _kpiOutstandingAmount = 0;
  double _kpiTodayRevenue = 0;

  BookingStatus? _statusFilter;
  PaymentStatus? _paymentFilter;
  _BookingDateScope _dateScope = _BookingDateScope.all;
  _OperationFilter _operationFilter = _OperationFilter.all;

  DateTimeRange? _customRange;
  _BookingSearchField _searchField = _BookingSearchField.all;
  DateTime? _searchDate;
  DocumentSnapshot<Map<String, dynamic>>? _searchLastDocument;
  bool _hasMoreSearchResults = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    developer.log(
      'INIT | tenant=$_tenantId',
      name: 'ADMIN_BOOKINGS',
    );

    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);

    // Wait until the first frame is mounted before starting Firestore work.
    // This prevents route/build timing issues from producing a blank screen.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      developer.log(
        'STARTING INITIAL BOOKINGS LOAD',
        name: 'ADMIN_BOOKINGS',
      );

      _loadBookings();
    });

    // Keep the operations dashboard fresh without forcing a full real-time
    // Firestore listener across every filtered/search query.
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted || _refreshInFlight) return;
      _refreshCurrentView(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;

    final last = _lastRefreshedAt;
    if (last == null || DateTime.now().difference(last) >= const Duration(seconds: 45)) {
      _refreshCurrentView(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoRefreshTimer?.cancel();
    _searchController
      ..removeListener(_onSearchChanged)
      ..dispose();
    _searchDebounce?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted || _suppressSearchListener) return;
    setState(() {});

    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      _runSearch();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loading || _loadingMore) {
      return;
    }

    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 900) {
      if (_searching) {
        _loadMoreSearchResults();
      } else {
        _loadMoreBookings();
      }
    }
  }


  String get _tenantId => AppConfig.tenant.tenantId;

  Future<void> _refreshCurrentView({bool silent = false}) async {
    if (!mounted) return;

    // A user-triggered refresh/filter/search change supersedes an older
    // request instead of getting stuck behind it.
    if (_refreshInFlight) {
      ++_loadGeneration;
      _refreshInFlight = false;
    }

    final hasActiveSearch = _searching &&
        (_searchFieldIsDate ? _searchDate != null : _searchController.text.trim().isNotEmpty);

    if (hasActiveSearch) {
      await _runSearch(silent: silent);
      return;
    }

    await _loadBookings(refresh: true, silent: silent);
  }

  Future<void> _loadBookings({bool refresh = false, bool silent = false}) async {
    if (!mounted || _refreshInFlight) return;
    final generation = ++_loadGeneration;
    _refreshInFlight = true;

    developer.log(
      'LOAD START | tenant=$_tenantId | refresh=$refresh | pageSize=$_pageSize',
      name: 'ADMIN_BOOKINGS',
    );

    if (!mounted) return;

    if (refresh) {
      if (!silent) {
        setState(() {
          _refreshing = true;
          _error = null;
        });
      }
    } else {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    if (_tenantId.isEmpty) {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
          _error = 'Tenant configuration is missing.';
        });
      }
      _refreshInFlight = false;
      return;
    }

    try {
      _lastDocument = null;
      _hasMoreBookings = true;

      if (mounted) {
        setState(() {
          _allBookings = <Booking>[];
        });
      }

      // KPI aggregation runs independently so the first 100 bookings can
      // render immediately instead of waiting for dashboard calculations.
      unawaited(_loadKpis());

      await _fetchBookingsPage(generation: generation);

      if (!mounted || generation != _loadGeneration) {
        _refreshInFlight = false;
        return;
      }
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = null;
        _lastRefreshedAt = DateTime.now();
      });
      _refreshInFlight = false;
    } catch (e, stackTrace) {
      developer.log(
        'LOAD ERROR',
        name: 'ADMIN_BOOKINGS',
        error: e,
        stackTrace: stackTrace,
      );

      if (!mounted || generation != _loadGeneration) {
        _refreshInFlight = false;
        return;
      }
      setState(() {
        _loading = false;
        _refreshing = false;
        _error = _cleanError(e);
      });
      _refreshInFlight = false;
    }
  }

  Future<void> _loadMoreBookings() async {
    if (_loading || _loadingMore || !_hasMoreBookings || _searching) return;
    await _fetchBookingsPage(generation: _loadGeneration);
  }

  String _statusFirestoreValue(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'pending';
      case BookingStatus.confirmed:
        return 'confirmed';
      case BookingStatus.pickupPending:
        return 'pickup_pending';
      case BookingStatus.active:
        return 'active';
      case BookingStatus.returnPending:
        return 'return_pending';
      case BookingStatus.completed:
        return 'completed';
      case BookingStatus.cancelled:
        return 'cancelled';
      case BookingStatus.rejected:
        return 'rejected';
      case BookingStatus.noShow:
        return 'no_show';
    }
  }

  String _paymentFirestoreValue(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.partiallyPaid:
        return 'partially_paid';
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.failed:
        return 'failed';
      case PaymentStatus.refunded:
        return 'refunded';
      case PaymentStatus.partiallyRefunded:
        return 'partially_refunded';
    }
  }

  Query<Map<String, dynamic>> _baseBookingsQuery() {
    Query<Map<String, dynamic>> query = _firestore
        .collection('tenants')
        .doc(_tenantId)
        .collection('bookings');

    // Server-side filters are used whenever Firestore can safely apply them.
    if (_statusFilter != null) {
      query = query.where(
        'status',
        isEqualTo: _statusFirestoreValue(_statusFilter!),
      );
    }

    if (_paymentFilter != null) {
      query = query.where(
        'paymentStatus',
        isEqualTo: _paymentFirestoreValue(_paymentFilter!),
      );
    }

    final now = DateTime.now();
    final todayStart = _startOfDay(now);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    switch (_operationFilter) {
      case _OperationFilter.pickupsToday:
        query = query
            .where('pickupDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('pickupDateTime', isLessThan: Timestamp.fromDate(tomorrowStart));
        break;
      case _OperationFilter.returnsToday:
        query = query
            .where('returnDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
            .where('returnDateTime', isLessThan: Timestamp.fromDate(tomorrowStart));
        break;
      case _OperationFilter.upcoming:
        query = query.where(
          'pickupDateTime',
          isGreaterThanOrEqualTo: Timestamp.fromDate(now),
        );
        break;
      case _OperationFilter.outstanding:
        query = query.where('balanceAmount', isGreaterThan: 0.009);
        break;
      case _OperationFilter.all:
      case _OperationFilter.active:
      case _OperationFilter.pickupPending:
      case _OperationFilter.returnPending:
      case _OperationFilter.pending:
        break;
    }

    return query;
  }

  String _pageOrderField() {
    if (_operationFilter == _OperationFilter.returnsToday) {
      return 'returnDateTime';
    }
    return 'pickupDateTime';
  }

  Future<void> _fetchBookingsPage({required int generation}) async {
    if (_loadingMore || !_hasMoreBookings || !mounted) return;

    setState(() => _loadingMore = true);

    try {
      Query<Map<String, dynamic>> query = _baseBookingsQuery();
      final orderField = _pageOrderField();

      final dateStart = _dateFilterStartForOrderField(orderField);
      final dateEnd = _dateFilterEnd();

      if (dateStart != null) {
        query = query.where(
          orderField,
          isGreaterThanOrEqualTo: Timestamp.fromDate(dateStart),
        );
      }
      if (dateEnd != null) {
        query = query.where(
          orderField,
          isLessThan: Timestamp.fromDate(dateEnd),
        );
      }

      query = query
          .orderBy(orderField, descending: true)
          .orderBy(FieldPath.documentId, descending: true)
          .limit(_pageSize);

      final cursor = _lastDocument;
      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }

      developer.log(
        'FETCH PAGE | order=$orderField | cursor=${cursor?.id} | pageSize=$_pageSize',
        name: 'ADMIN_BOOKINGS',
      );

      final snapshot = await query.get();
      if (!mounted || generation != _loadGeneration) return;

      final page = snapshot.docs
          .map((doc) => Booking.fromMap(doc.id, doc.data()))
          .where((booking) => booking.tenantId == _tenantId)
          .toList();

      _lastDocument = snapshot.docs.isEmpty ? _lastDocument : snapshot.docs.last;
      _hasMoreBookings = snapshot.docs.length == _pageSize;

      setState(() {
        final existingIds = _allBookings.map((b) => b.bookingId).toSet();
        _allBookings.addAll(
          page.where((booking) => !existingIds.contains(booking.bookingId)),
        );
        _loadingMore = false;
      });

      developer.log(
        'PAGE SUCCESS | fetched=${page.length} | totalLoaded=${_allBookings.length} | hasMore=$_hasMoreBookings',
        name: 'ADMIN_BOOKINGS',
      );
    } catch (e, stackTrace) {
      developer.log(
        'PAGE LOAD ERROR',
        name: 'ADMIN_BOOKINGS',
        error: e,
        stackTrace: stackTrace,
      );
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadingMore = false;
        if (_allBookings.isEmpty) {
          _error = _cleanError(e);
          _loading = false;
        }
      });
    }
  }

  DateTime? _dateFilterStartForOrderField(String orderField) {
    final now = DateTime.now();
    final todayStart = _startOfDay(now);

    if (_operationFilter == _OperationFilter.returnsToday) {
      return todayStart;
    }

    switch (_dateScope) {
      case _BookingDateScope.all:
        return null;
      case _BookingDateScope.today:
        return todayStart;
      case _BookingDateScope.tomorrow:
        return todayStart.add(const Duration(days: 1));
      case _BookingDateScope.next7Days:
        return todayStart;
      case _BookingDateScope.custom:
        return _customRange?.start;
    }
  }

  DateTime? _dateFilterEnd() {
    final now = DateTime.now();
    final todayStart = _startOfDay(now);

    if (_operationFilter == _OperationFilter.returnsToday) {
      return _endOfDay(now).add(const Duration(microseconds: 1));
    }

    switch (_dateScope) {
      case _BookingDateScope.all:
        return null;
      case _BookingDateScope.today:
        return _endOfDay(now).add(const Duration(microseconds: 1));
      case _BookingDateScope.tomorrow:
        final day = todayStart.add(const Duration(days: 1));
        return _endOfDay(day).add(const Duration(microseconds: 1));
      case _BookingDateScope.next7Days:
        return todayStart.add(const Duration(days: 8));
      case _BookingDateScope.custom:
        final range = _customRange;
        return range == null
            ? null
            : _endOfDay(range.end).add(const Duration(microseconds: 1));
    }
  }

  String _searchFieldLabel(_BookingSearchField field) {
    switch (field) {
      case _BookingSearchField.all:
        return 'All fields';
      case _BookingSearchField.bookingId:
        return 'Booking ID';
      case _BookingSearchField.customerName:
        return 'Customer Name';
      case _BookingSearchField.customerPhone:
        return 'Customer Phone';
      case _BookingSearchField.customerEmail:
        return 'Customer Email';
      case _BookingSearchField.registrationNumber:
        return 'Registration Number';
      case _BookingSearchField.carName:
        return 'Car Name';
      case _BookingSearchField.carId:
        return 'Car ID';
      case _BookingSearchField.pickupDate:
        return 'Pickup Date';
      case _BookingSearchField.returnDate:
        return 'Return Date';
      case _BookingSearchField.createdDate:
        return 'Created Date';
      case _BookingSearchField.branch:
        return 'Branch';
      case _BookingSearchField.status:
        return 'Booking Status';
      case _BookingSearchField.paymentStatus:
        return 'Payment Status';
    }
  }

  bool get _searchFieldIsDate =>
      _searchField == _BookingSearchField.pickupDate ||
      _searchField == _BookingSearchField.returnDate ||
      _searchField == _BookingSearchField.createdDate;

  String get _searchHint {
    switch (_searchField) {
      case _BookingSearchField.all:
        return 'Search all Firestore booking fields...';
      case _BookingSearchField.bookingId:
        return 'Enter booking ID';
      case _BookingSearchField.customerName:
        return 'Enter customer name';
      case _BookingSearchField.customerPhone:
        return 'Enter phone number';
      case _BookingSearchField.customerEmail:
        return 'Enter email';
      case _BookingSearchField.registrationNumber:
        return 'Enter vehicle registration number';
      case _BookingSearchField.carName:
        return 'Enter car name';
      case _BookingSearchField.carId:
        return 'Enter car ID';
      case _BookingSearchField.pickupDate:
        return 'Select pickup date';
      case _BookingSearchField.returnDate:
        return 'Select return date';
      case _BookingSearchField.createdDate:
        return 'Select created date';
      case _BookingSearchField.branch:
        return 'Enter branch name or city';
      case _BookingSearchField.status:
        return 'pending / confirmed / active...';
      case _BookingSearchField.paymentStatus:
        return 'pending / paid / partially_paid...';
    }
  }

  void _changeSearchField(_BookingSearchField? field) {
    if (field == null || field == _searchField) return;

    _searchDebounce?.cancel();
    _suppressSearchListener = true;
    _searchController.clear();

    setState(() {
      _searchField = field;
      _searchDate = null;
      _searchLastDocument = null;
      _hasMoreSearchResults = false;
      _searching = false;
      _allBookings = <Booking>[];
    });

    _suppressSearchListener = false;

    // Start a clean first page using the selected search field.
    if (!mounted) return;
    _refreshCurrentView();
  }

  Future<void> _pickSearchDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDate: _searchDate ?? now,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _BookingColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    final value = DateTime(picked.year, picked.month, picked.day);
    _searchDebounce?.cancel();
    _suppressSearchListener = true;
    _searchController.text =
        '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
    _suppressSearchListener = false;

    setState(() {
      _searchDate = value;

      // A field-specific date search is authoritative. Do not let an
      // older Date/Operation filter remove valid results afterwards.
      _dateScope = _BookingDateScope.all;
      _customRange = null;
      _operationFilter = _OperationFilter.all;
    });

    await _runSearch();
  }

  Query<Map<String, dynamic>> _searchBaseQuery() {
    Query<Map<String, dynamic>> query = _firestore
        .collection('tenants')
        .doc(_tenantId)
        .collection('bookings');

    if (_statusFilter != null) {
      query = query.where('status', isEqualTo: _statusFirestoreValue(_statusFilter!));
    }
    if (_paymentFilter != null) {
      query = query.where('paymentStatus', isEqualTo: _paymentFirestoreValue(_paymentFilter!));
    }
    return query;
  }

  Query<Map<String, dynamic>> _buildSpecificSearchQuery({
    required String value,
    DocumentSnapshot<Map<String, dynamic>>? cursor,
  }) {
    Query<Map<String, dynamic>> query = _searchBaseQuery();
    final normalized = value.trim();
    final lower = normalized.toLowerCase();
    final upper = normalized.toUpperCase();

    switch (_searchField) {
      case _BookingSearchField.all:
        // Handled separately with parallel field queries.
        query = query.where('bookingId', isGreaterThanOrEqualTo: normalized)
            .where('bookingId', isLessThanOrEqualTo: '$normalized\uf8ff')
            .orderBy('bookingId');
        break;
      case _BookingSearchField.bookingId:
        query = query.where('bookingId', isGreaterThanOrEqualTo: normalized)
            .where('bookingId', isLessThanOrEqualTo: '$normalized\uf8ff')
            .orderBy('bookingId');
        break;
      case _BookingSearchField.customerName:
        query = query.where('customerName', isGreaterThanOrEqualTo: normalized)
            .where('customerName', isLessThanOrEqualTo: '$normalized\uf8ff')
            .orderBy('customerName');
        break;
      case _BookingSearchField.customerPhone:
        query = query.where('customerPhone', isGreaterThanOrEqualTo: normalized)
            .where('customerPhone', isLessThanOrEqualTo: '$normalized\uf8ff')
            .orderBy('customerPhone');
        break;
      case _BookingSearchField.customerEmail:
        query = query.where('customerEmail', isGreaterThanOrEqualTo: lower)
            .where('customerEmail', isLessThanOrEqualTo: '$lower\uf8ff')
            .orderBy('customerEmail');
        break;
      case _BookingSearchField.registrationNumber:
        query = query.where('car.registrationNumber', isEqualTo: upper)
            .orderBy('car.registrationNumber');
        break;
      case _BookingSearchField.carName:
        query = query.where('car.name', isGreaterThanOrEqualTo: normalized)
            .where('car.name', isLessThanOrEqualTo: '$normalized\uf8ff')
            .orderBy('car.name');
        break;
      case _BookingSearchField.carId:
        query = query.where('carId', isEqualTo: normalized)
            .orderBy('carId');
        break;
      case _BookingSearchField.branch:
        query = query.where('pickupBranch.name', isGreaterThanOrEqualTo: normalized)
            .where('pickupBranch.name', isLessThanOrEqualTo: '$normalized\uf8ff')
            .orderBy('pickupBranch.name');
        break;
      case _BookingSearchField.status:
        query = query.where('status', isEqualTo: lower).orderBy('status');
        break;
      case _BookingSearchField.paymentStatus:
        query = query.where('paymentStatus', isEqualTo: lower).orderBy('paymentStatus');
        break;
      case _BookingSearchField.pickupDate:
        final date = _searchDate;
        if (date == null) return query.limit(0);
        final end = date.add(const Duration(days: 1));
        query = query.where('pickupDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(date))
            .where('pickupDateTime', isLessThan: Timestamp.fromDate(end))
            .orderBy('pickupDateTime');
        break;
      case _BookingSearchField.returnDate:
        final date = _searchDate;
        if (date == null) return query.limit(0);
        final end = date.add(const Duration(days: 1));
        query = query.where('returnDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(date))
            .where('returnDateTime', isLessThan: Timestamp.fromDate(end))
            .orderBy('returnDateTime');
        break;
      case _BookingSearchField.createdDate:
        final date = _searchDate;
        if (date == null) return query.limit(0);
        final end = date.add(const Duration(days: 1));
        query = query.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(date))
            .where('createdAt', isLessThan: Timestamp.fromDate(end))
            .orderBy('createdAt');
        break;
    }

    if (cursor != null) query = query.startAfterDocument(cursor);
    return query.limit(_pageSize);
  }

  Future<void> _runSearch({bool silent = false}) async {
    if (!mounted) return;
    final queryText = _searchController.text.trim();
    if (queryText.isEmpty && !_searchFieldIsDate) {
      if (!mounted) return;
      setState(() => _searching = false);
      await _loadBookings(refresh: true);
      return;
    }

    if (!_searchFieldIsDate && queryText.length < 2) return;
    if (_searchFieldIsDate && _searchDate == null) return;

    final generation = ++_loadGeneration;
    setState(() {
      _searching = true;
      _loadingMore = false;
      _error = null;
      _searchLastDocument = null;
      _hasMoreSearchResults = true;
      if (!silent) {
        _allBookings = <Booking>[];
      }
    });

    await _fetchSearchPage(generation: generation, replaceResults: true);
  }

  Future<void> _loadMoreSearchResults() async {
    if (!_searching || _loadingMore || !_hasMoreSearchResults) return;
    await _fetchSearchPage(generation: _loadGeneration, append: true);
  }

  Future<void> _fetchSearchPage({required int generation, bool append = false, bool replaceResults = false}) async {
    if (!mounted || generation != _loadGeneration) return;
    setState(() => _loadingMore = true);

    try {
      final value = _searchController.text.trim();

      // "All fields" is a convenience multi-query. It searches Firestore
      // directly across the most useful booking fields, then merges duplicates.
      // Specific-field search below is cursor-paginated for large result sets.
      if (_searchField == _BookingSearchField.all && _searchLastDocument == null) {
        final collection = _searchBaseQuery();
        final q = value.toLowerCase();
        final upper = value.toUpperCase();
        final queries = <Query<Map<String, dynamic>>>[
          collection.where('bookingId', isGreaterThanOrEqualTo: value).where('bookingId', isLessThanOrEqualTo: '$value\uf8ff').limit(_pageSize),
          collection.where('customerName', isGreaterThanOrEqualTo: value).where('customerName', isLessThanOrEqualTo: '$value\uf8ff').limit(_pageSize),
          collection.where('customerPhone', isGreaterThanOrEqualTo: value).where('customerPhone', isLessThanOrEqualTo: '$value\uf8ff').limit(_pageSize),
          collection.where('customerEmail', isGreaterThanOrEqualTo: q).where('customerEmail', isLessThanOrEqualTo: '$q\uf8ff').limit(_pageSize),
          collection.where('carId', isEqualTo: value).limit(_pageSize),
          collection.where('car.registrationNumber', isEqualTo: upper).limit(_pageSize),
          collection.where('car.name', isGreaterThanOrEqualTo: value).where('car.name', isLessThanOrEqualTo: '$value\uf8ff').limit(_pageSize),
          collection.where('pickupBranch.name', isGreaterThanOrEqualTo: value).where('pickupBranch.name', isLessThanOrEqualTo: '$value\uf8ff').limit(_pageSize),
        ];
        final snapshots = await Future.wait(queries.map((query) => query.get()));
        if (!mounted || generation != _loadGeneration) return;

        final byId = <String, Booking>{};
        for (final snapshot in snapshots) {
          for (final doc in snapshot.docs) {
            final booking = Booking.fromMap(doc.id, doc.data());
            if (booking.tenantId == _tenantId && _matchesCurrentNonSearchFilters(booking)) {
              byId[booking.bookingId] = booking;
            }
          }
        }
        final results = byId.values.toList()
          ..sort((a, b) => b.pickupDateTime.compareTo(a.pickupDateTime));

        setState(() {
          _allBookings = results;
          _hasMoreSearchResults = false;
          _loadingMore = false;
          _lastRefreshedAt = DateTime.now();
        });
        return;
      }

      final query = _buildSpecificSearchQuery(
        value: value,
        cursor: _searchLastDocument,
      );
      final snapshot = await query.get();
      if (!mounted || generation != _loadGeneration) return;

      final page = snapshot.docs
          .map((doc) => Booking.fromMap(doc.id, doc.data()))
          .where((b) => b.tenantId == _tenantId)
          .where(_matchesCurrentNonSearchFilters)
          .toList();

      final existing = _allBookings.map((b) => b.bookingId).toSet();
      final additions = page.where((b) => !existing.contains(b.bookingId)).toList();
      _searchLastDocument = snapshot.docs.isEmpty ? _searchLastDocument : snapshot.docs.last;
      _hasMoreSearchResults = snapshot.docs.length == _pageSize;

      setState(() {
        if (replaceResults) {
          _allBookings = page;
        } else {
          _allBookings.addAll(additions);
        }
        _loadingMore = false;
        _lastRefreshedAt = DateTime.now();
      });
    } catch (e, stackTrace) {
      developer.log('FIELD SEARCH ERROR', name: 'ADMIN_BOOKINGS', error: e, stackTrace: stackTrace);
      if (!mounted || generation != _loadGeneration) return;
      setState(() {
        _loadingMore = false;
        _searching = false;
        _error = _cleanError(e);
      });
    }
  }

  bool _matchesCurrentNonSearchFilters(Booking booking) {
    if (_statusFilter != null && booking.status != _statusFilter) return false;
    if (_paymentFilter != null && booking.paymentStatus != _paymentFilter) return false;

    switch (_operationFilter) {
      case _OperationFilter.all:
        break;
      case _OperationFilter.pickupsToday:
        if (!_isPickupToday(booking)) return false;
        break;
      case _OperationFilter.returnsToday:
        if (!_isReturnToday(booking)) return false;
        break;
      case _OperationFilter.active:
        if (!_isActiveRental(booking)) return false;
        break;
      case _OperationFilter.pickupPending:
        if (!_isPickupPending(booking)) return false;
        break;
      case _OperationFilter.returnPending:
        if (!_isReturnPending(booking)) return false;
        break;
      case _OperationFilter.upcoming:
        if (!_isUpcoming(booking)) return false;
        break;
      case _OperationFilter.pending:
        if (!_isPending(booking)) return false;
        break;
      case _OperationFilter.outstanding:
        if (!_isOutstanding(booking)) return false;
        break;
    }

    final start = _dateFilterStartForOrderField(_pageOrderField());
    final end = _dateFilterEnd();
    if (start != null && end != null) {
      final overlaps = booking.pickupDateTime.isBefore(end) &&
          booking.returnDateTime.isAfter(start);
      if (!overlaps) return false;
    }
    return true;
  }

  Future<void> _loadKpis() async {
    if (_tenantId.isEmpty) return;

    final collection = _firestore
        .collection('tenants')
        .doc(_tenantId)
        .collection('bookings');

    Future<int> countWhere(String field, Object value) async {
      final snapshot = await collection.where(field, isEqualTo: value).count().get();
      return snapshot.count ?? 0;
    }

    final now = DateTime.now();
    final todayStart = _startOfDay(now);
    final tomorrowStart = todayStart.add(const Duration(days: 1));

    try {
      final counts = await Future.wait<int>([
        countWhere('status', _statusFirestoreValue(BookingStatus.active)),
        countWhere('status', _statusFirestoreValue(BookingStatus.pickupPending)),
        countWhere('status', _statusFirestoreValue(BookingStatus.returnPending)),
        countWhere('status', _statusFirestoreValue(BookingStatus.pending)),
        countWhere('status', _statusFirestoreValue(BookingStatus.confirmed)),
        countWhere('status', _statusFirestoreValue(BookingStatus.completed)),
        countWhere('status', _statusFirestoreValue(BookingStatus.cancelled)),
        countWhere('status', _statusFirestoreValue(BookingStatus.rejected)),
        countWhere('status', _statusFirestoreValue(BookingStatus.noShow)),
      ]);

      final todayPickups = await collection
          .where('pickupDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('pickupDateTime', isLessThan: Timestamp.fromDate(tomorrowStart))
          .count()
          .get();

      final todayReturns = await collection
          .where('returnDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('returnDateTime', isLessThan: Timestamp.fromDate(tomorrowStart))
          .count()
          .get();

      final upcoming = await collection
          .where('pickupDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(tomorrowStart))
          .count()
          .get();

      final outstandingSnapshot = await collection
          .where('balanceAmount', isGreaterThan: 0.009)
          .get();

      double outstandingAmount = 0;
      int outstandingCount = 0;
      for (final doc in outstandingSnapshot.docs) {
        final booking = Booking.fromMap(doc.id, doc.data());
        if (_isOutstanding(booking)) {
          outstandingCount++;
          outstandingAmount += booking.balanceAmount;
        }
      }

      final todayRevenueSnapshot = await collection
          .where('pickupDateTime', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .where('pickupDateTime', isLessThan: Timestamp.fromDate(tomorrowStart))
          .get();

      double todayRevenue = 0;
      for (final doc in todayRevenueSnapshot.docs) {
        todayRevenue += Booking.fromMap(doc.id, doc.data()).totalAmount;
      }

      if (!mounted) return;
      setState(() {
        _kpiActiveCount = counts[0];
        _kpiPickupPendingCount = counts[1];
        _kpiReturnPendingCount = counts[2];
        _kpiPendingCount = counts[3];
        _kpiConfirmedCount = counts[4];
        _kpiCompletedCount = counts[5];
        _kpiCancelledCount = counts[6];
        _kpiRejectedCount = counts[7];
        _kpiNoShowCount = counts[8];
        _kpiTodayPickupCount = todayPickups.count ?? 0;
        _kpiTodayReturnCount = todayReturns.count ?? 0;
        _kpiUpcomingCount = upcoming.count ?? 0;
        _kpiOutstandingCount = outstandingCount;
        _kpiOutstandingAmount = outstandingAmount;
        _kpiTodayRevenue = todayRevenue;
      });
    } catch (e, stackTrace) {
      developer.log('KPI LOAD ERROR', name: 'ADMIN_BOOKINGS', error: e, stackTrace: stackTrace);
      // The paginated booking list remains usable if aggregation queries fail.
    }
  }

  String _cleanError(Object error) {
    final text = error.toString();
    if (text.startsWith('Exception: ')) {
      return text.substring(11);
    }
    return text;
  }

  DateTime _startOfDay(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  DateTime _endOfDay(DateTime value) {
    return DateTime(
      value.year,
      value.month,
      value.day,
      23,
      59,
      59,
      999,
    );
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year &&
        a.month == b.month &&
        a.day == b.day;
  }

  bool _isTerminal(Booking booking) {
    return booking.status == BookingStatus.completed ||
        booking.status == BookingStatus.cancelled ||
        booking.status == BookingStatus.rejected ||
        booking.status == BookingStatus.noShow;
  }

  bool _isPickupToday(Booking booking) {
    return _sameDay(booking.pickupDateTime, DateTime.now()) &&
        !_isTerminal(booking);
  }

  bool _isReturnToday(Booking booking) {
    return _sameDay(booking.returnDateTime, DateTime.now()) &&
        (booking.status == BookingStatus.active ||
            booking.status == BookingStatus.returnPending);
  }

  bool _isActiveRental(Booking booking) {
    return booking.status == BookingStatus.active;
  }

  bool _isPickupPending(Booking booking) {
    return booking.status == BookingStatus.pickupPending;
  }

  bool _isReturnPending(Booking booking) {
    return booking.status == BookingStatus.returnPending;
  }

  bool _isUpcoming(Booking booking) {
    return booking.pickupDateTime.isAfter(DateTime.now()) &&
        !_isTerminal(booking) &&
        booking.status != BookingStatus.active &&
        booking.status != BookingStatus.returnPending;
  }

  bool _isPending(Booking booking) {
    return booking.status == BookingStatus.pending;
  }

  bool _isOutstanding(Booking booking) {
    return booking.balanceAmount > 0.009 &&
        booking.status != BookingStatus.cancelled &&
        booking.status != BookingStatus.rejected &&
        booking.status != BookingStatus.noShow;
  }

  List<Booking> get _filteredBookings {
    final query = _searchController.text.trim().toLowerCase();

    Iterable<Booking> items = _allBookings;

    if (_statusFilter != null) {
      items = items.where((b) => b.status == _statusFilter);
    }

    if (_paymentFilter != null) {
      items = items.where((b) => b.paymentStatus == _paymentFilter);
    }

    // Search results already come from the Firestore search query.
    // Re-applying the normal operation/date filters or the raw search text
    // here can incorrectly turn valid search results into an empty state
    // (especially date searches, where the text is "YYYY-MM-DD").
    if (!_searching) {
      switch (_operationFilter) {
        case _OperationFilter.all:
          break;
        case _OperationFilter.pickupsToday:
          items = items.where(_isPickupToday);
          break;
        case _OperationFilter.returnsToday:
          items = items.where(_isReturnToday);
          break;
        case _OperationFilter.active:
          items = items.where(_isActiveRental);
          break;
        case _OperationFilter.pickupPending:
          items = items.where(_isPickupPending);
          break;
        case _OperationFilter.returnPending:
          items = items.where(_isReturnPending);
          break;
        case _OperationFilter.upcoming:
          items = items.where(_isUpcoming);
          break;
        case _OperationFilter.pending:
          items = items.where(_isPending);
          break;
        case _OperationFilter.outstanding:
          items = items.where(_isOutstanding);
          break;
      }

      final now = DateTime.now();
      final todayStart = _startOfDay(now);
      final todayEnd = _endOfDay(now);

      switch (_dateScope) {
        case _BookingDateScope.all:
          break;
        case _BookingDateScope.today:
          items = items.where(
            (b) =>
                b.pickupDateTime.isBefore(todayEnd) &&
                b.returnDateTime.isAfter(todayStart),
          );
          break;
        case _BookingDateScope.tomorrow:
          final start = todayStart.add(const Duration(days: 1));
          final end = _endOfDay(start);
          items = items.where(
            (b) =>
                b.pickupDateTime.isBefore(end) &&
                b.returnDateTime.isAfter(start),
          );
          break;
        case _BookingDateScope.next7Days:
          final end = todayStart.add(const Duration(days: 8));
          items = items.where(
            (b) =>
                b.pickupDateTime.isBefore(end) &&
                b.returnDateTime.isAfter(todayStart),
          );
          break;
        case _BookingDateScope.custom:
          final range = _customRange;
          if (range != null) {
            items = items.where(
              (b) =>
                  b.pickupDateTime.isBefore(
                    range.end.add(const Duration(days: 1)),
                  ) &&
                  b.returnDateTime.isAfter(range.start),
            );
          }
          break;
      }

      if (query.isNotEmpty) {
        items = items.where((b) {
          final values = <String>[
            b.bookingId,
            b.customerId,
            b.customerName,
            b.customerPhone,
            b.customerEmail,
            b.carId,
            b.car?.name ?? '',
            b.car?.type ?? '',
            b.car?.registrationNumber ?? '',
            b.pickupBranch?.name ?? '',
            b.returnBranch?.name ?? '',
            b.pickupBranch?.city ?? '',
            b.returnBranch?.city ?? '',
            _statusLabel(b.status),
            _paymentStatusLabel(b.paymentStatus),
          ].join(' ').toLowerCase();

          return values.contains(query);
        });
      }
    }

    final result = items.toList();

    result.sort((a, b) {
      // Operational items first, then by pickup time.
      final aPriority = _operationPriority(a);
      final bPriority = _operationPriority(b);

      if (aPriority != bPriority) {
        return aPriority.compareTo(bPriority);
      }

      return a.pickupDateTime.compareTo(b.pickupDateTime);
    });

    return result;
  }

  int _operationPriority(Booking booking) {
    if (_isReturnPending(booking)) return 0;
    if (_isPickupPending(booking)) return 1;
    if (_isReturnToday(booking)) return 2;
    if (_isPickupToday(booking)) return 3;
    if (booking.status == BookingStatus.pending) return 4;
    if (_isActiveRental(booking)) return 5;
    if (_isUpcoming(booking)) return 6;
    return 7;
  }

  int get _todayPickupCount => _kpiTodayPickupCount;

  int get _todayReturnCount => _kpiTodayReturnCount;

  int get _activeCount => _kpiActiveCount;

  int get _pickupPendingCount => _kpiPickupPendingCount;

  int get _returnPendingCount => _kpiReturnPendingCount;

  int get _pendingCount => _kpiPendingCount;

  int get _confirmedCount => _kpiConfirmedCount;

  int get _upcomingCount => _kpiUpcomingCount;

  int get _outstandingCount => _kpiOutstandingCount;

  int get _completedCount => _kpiCompletedCount;

  int get _cancelledCount => _kpiCancelledCount;

  int get _rejectedCount => _kpiRejectedCount;

  int get _noShowCount => _kpiNoShowCount;

  double get _todayRevenue => _kpiTodayRevenue;

  double get _outstandingAmount => _kpiOutstandingAmount;

  List<Booking> _operationItems(_OperationFilter filter) {
    return _allBookings.where((booking) {
      switch (filter) {
        case _OperationFilter.all:
          return true;
        case _OperationFilter.pickupsToday:
          return _isPickupToday(booking);
        case _OperationFilter.returnsToday:
          return _isReturnToday(booking);
        case _OperationFilter.active:
          return _isActiveRental(booking);
        case _OperationFilter.pickupPending:
          return _isPickupPending(booking);
        case _OperationFilter.returnPending:
          return _isReturnPending(booking);
        case _OperationFilter.upcoming:
          return _isUpcoming(booking);
        case _OperationFilter.pending:
          return _isPending(booking);
        case _OperationFilter.outstanding:
          return _isOutstanding(booking);
      }
    }).toList()
      ..sort((a, b) => a.pickupDateTime.compareTo(b.pickupDateTime));
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: _startOfDay(now),
            end: _startOfDay(now).add(const Duration(days: 7)),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _BookingColors.primary,
            ),
          ),
          child: child!,
        );
      },
    );

    if (range == null || !mounted) return;

    setState(() {
      _customRange = range;
      _dateScope = _BookingDateScope.custom;
    });
    _refreshCurrentView();
  }

  void _resetFilters() {
    _searchDebounce?.cancel();

    // Invalidate any in-flight search immediately so an old search response
    // cannot overwrite the freshly reset first page.
    ++_loadGeneration;

    _suppressSearchListener = true;
    _searchController.clear();
    _suppressSearchListener = false;

    setState(() {
      _statusFilter = null;
      _paymentFilter = null;
      _dateScope = _BookingDateScope.all;
      _customRange = null;
      _operationFilter = _OperationFilter.all;
      _searchField = _BookingSearchField.all;
      _searchDate = null;
      _searchLastDocument = null;
      _hasMoreSearchResults = false;
      _searching = false;
      _error = null;
    });

    _refreshCurrentView();
  }

  void _selectOperation(_OperationFilter filter) {
    setState(() {
      _operationFilter = filter;
      _statusFilter = null;
      _paymentFilter = null;
      _dateScope = _BookingDateScope.all;
      _customRange = null;
    });
    _refreshCurrentView();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          390,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _openBookingDetails(Booking booking) async {
    // Keep the callback available for parent-level routing if the caller
    // already owns navigation. Otherwise use the built-in details route.
    if (widget.onOpenBookingDetails != null) {
      widget.onOpenBookingDetails!(booking);
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminBookingDetailsScreen(
          booking: booking,
          onBookingChanged: (updatedBooking) {
            // Refresh the list after any lifecycle/payment action performed
            // inside Booking Details.
            if (!mounted) return;

            final index = _allBookings.indexWhere(
              (item) => item.bookingId == updatedBooking.bookingId,
            );

            if (index == -1) {
              _refreshCurrentView();
              return;
            }

            setState(() {
              _allBookings[index] = updatedBooking;
            });

            // Re-read from Firestore as the details screen may have changed
            // fields beyond the in-memory Booking object.
            _refreshCurrentView();
          },
        ),
      ),
    );

    if (!mounted) return;

    // Re-read when returning to the list so status/payment changes made
    // from the details page are reflected immediately.
    await _loadBookings(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 720;
    final isTablet = width >= 720 && width < 1100;

    return Scaffold(
      backgroundColor: _BookingColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: _BookingColors.primary,
          onRefresh: () => _refreshCurrentView(),
          child: CustomScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: _buildHeader(
                  isMobile: isMobile,
                  isTablet: isTablet,
                ),
              ),
              SliverToBoxAdapter(
                child: _buildKpiGrid(
                  isMobile: isMobile,
                  isTablet: isTablet,
                ),
              ),
              SliverToBoxAdapter(
                child: _buildOperationsStrip(
                  isMobile: isMobile,
                ),
              ),
              SliverToBoxAdapter(
                child: _buildFilters(
                  isMobile: isMobile,
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: CircularProgressIndicator(
                      color: _BookingColors.primary,
                    ),
                  ),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _buildErrorState(),
                )
              else ..._buildBookingSlivers(
                isMobile: isMobile,
                isTablet: isTablet,
              ),
              const SliverToBoxAdapter(
                child: SizedBox(height: 32),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String get _lastRefreshedLabel {
    if (_refreshing) return 'Refreshing…';
    final value = _lastRefreshedAt;
    if (value == null) return 'Waiting for first sync';
    final diff = DateTime.now().difference(value);
    if (diff.inSeconds < 10) return 'Live • just now';
    if (diff.inMinutes < 1) return 'Live • ${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return 'Live • ${diff.inMinutes}m ago';
    return 'Checked ${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')} ${_formatTime(value)}';
  }

  Widget _buildHeader({
    required bool isMobile,
    required bool isTablet,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        20,
        isMobile ? 16 : 28,
        10,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Bookings',
                  style: GoogleFonts.inter(
                    fontSize: isMobile ? 26 : 32,
                    fontWeight: FontWeight.w800,
                    color: _BookingColors.text,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Monitor pickups, rentals, returns, payments and booking lifecycle.',
                  maxLines: isMobile ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: _BookingColors.muted,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    _LiveStatusPill(
                      icon: _refreshing
                          ? Icons.sync_rounded
                          : Icons.verified_rounded,
                      text: _lastRefreshedLabel,
                      color: _refreshing
                          ? _BookingColors.orange
                          : _BookingColors.green,
                    ),
                    const _LiveStatusPill(
                      icon: Icons.autorenew_rounded,
                      text: 'Auto refresh 60s',
                      color: _BookingColors.primary,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (!isMobile)
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: _HeaderAction(
                icon: Icons.add_rounded,
                label: 'New Booking',
                onTap: widget.onCreateBooking,
              ),
            ),
          const SizedBox(width: 8),
          _IconButton(
            icon: _refreshing
                ? Icons.sync_rounded
                : Icons.refresh_rounded,
            onTap: _refreshing
                ? null
                : () => _refreshCurrentView(),
          ),
          if (isMobile) ...[
            const SizedBox(width: 8),
            _IconButton(
              icon: Icons.add_rounded,
              onTap: widget.onCreateBooking,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildKpiGrid({
    required bool isMobile,
    required bool isTablet,
  }) {
    final cards = <Widget>[
      _KpiCard(
        title: "Today's Pickups",
        value: '$_todayPickupCount',
        subtitle: 'Vehicles due for handover',
        icon: Icons.login_rounded,
        accent: _BookingColors.blue,
        onTap: () => _selectOperation(_OperationFilter.pickupsToday),
      ),
      _KpiCard(
        title: 'Pickup Pending',
        value: '$_pickupPendingCount',
        subtitle: 'Handover still pending',
        icon: Icons.directions_car_rounded,
        accent: _BookingColors.orange,
        onTap: () => _selectOperation(_OperationFilter.pickupPending),
      ),
      _KpiCard(
        title: "Today's Returns",
        value: '$_todayReturnCount',
        subtitle: 'Vehicles due back',
        icon: Icons.logout_rounded,
        accent: _BookingColors.orange,
        onTap: () => _selectOperation(_OperationFilter.returnsToday),
      ),
      _KpiCard(
        title: 'Return Pending',
        value: '$_returnPendingCount',
        subtitle: 'Inspection still pending',
        icon: Icons.assignment_return_rounded,
        accent: _BookingColors.orange,
        onTap: () => _selectOperation(_OperationFilter.returnPending),
      ),
      _KpiCard(
        title: 'Active Rentals',
        value: '$_activeCount',
        subtitle: 'Currently on rent',
        icon: Icons.directions_car_filled_rounded,
        accent: _BookingColors.green,
        onTap: () => _selectOperation(_OperationFilter.active),
      ),
      _KpiCard(
        title: 'Pending Approval',
        value: '$_pendingCount',
        subtitle: 'Need admin action',
        icon: Icons.pending_actions_rounded,
        accent: _BookingColors.purple,
        onTap: () => _selectOperation(_OperationFilter.pending),
      ),
      _KpiCard(
        title: 'Upcoming',
        value: '$_upcomingCount',
        subtitle: 'Future rentals',
        icon: Icons.event_available_rounded,
        accent: _BookingColors.teal,
        onTap: () => _selectOperation(_OperationFilter.upcoming),
      ),
      _KpiCard(
        title: 'Outstanding',
        value: '$_outstandingCount',
        subtitle: 'Bookings with balance',
        icon: Icons.account_balance_wallet_rounded,
        accent: _BookingColors.red,
        valueSuffix: _currency(_outstandingAmount),
        onTap: () => _selectOperation(_OperationFilter.outstanding),
      ),
      _KpiCard(
        title: "Today's Booking Value",
        value: _currency(_todayRevenue),
        subtitle: 'Pickup-date booking value',
        icon: Icons.payments_rounded,
        accent: _BookingColors.indigo,
        compactValue: true,
      ),
      _KpiCard(
        title: 'Completed',
        value: '$_completedCount',
        subtitle: 'Finished rentals',
        icon: Icons.check_circle_rounded,
        accent: _BookingColors.green,
        compactValue: false,
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        12,
        isMobile ? 16 : 28,
        10,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = isMobile ? 2 : (isTablet ? 3 : 4);
          final spacing = isMobile ? 10.0 : 14.0;
          final itemWidth =
              (constraints.maxWidth - (spacing * (columns - 1))) /
                  columns;

          return Wrap(
            spacing: spacing,
            runSpacing: spacing,
            children: cards
                .map(
                  (card) => SizedBox(
                    width: itemWidth,
                    child: card,
                  ),
                )
                .toList(),
          );
        },
      ),
    );
  }

  Widget _buildOperationsStrip({
    required bool isMobile,
  }) {
    final operations = <_OperationData>[
      _OperationData(
        filter: _OperationFilter.pickupsToday,
        label: 'Pickups',
        count: _todayPickupCount,
        icon: Icons.login_rounded,
        accent: _BookingColors.blue,
      ),
      _OperationData(
        filter: _OperationFilter.pickupPending,
        label: 'Pickup Pending',
        count: _pickupPendingCount,
        icon: Icons.directions_car_rounded,
        accent: _BookingColors.orange,
      ),
      _OperationData(
        filter: _OperationFilter.returnsToday,
        label: 'Returns',
        count: _todayReturnCount,
        icon: Icons.logout_rounded,
        accent: _BookingColors.orange,
      ),
      _OperationData(
        filter: _OperationFilter.active,
        label: 'On Rent',
        count: _activeCount,
        icon: Icons.directions_car_filled_rounded,
        accent: _BookingColors.green,
      ),
      _OperationData(
        filter: _OperationFilter.returnPending,
        label: 'Return Pending',
        count: _returnPendingCount,
        icon: Icons.assignment_return_rounded,
        accent: _BookingColors.orange,
      ),
      _OperationData(
        filter: _OperationFilter.pending,
        label: 'Pending',
        count: _pendingCount,
        icon: Icons.pending_actions_rounded,
        accent: _BookingColors.purple,
      ),
      _OperationData(
        filter: _OperationFilter.outstanding,
        label: 'Payment Due',
        count: _outstandingCount,
        icon: Icons.payments_rounded,
        accent: _BookingColors.red,
      ),
    ];

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        8,
        isMobile ? 16 : 28,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Today's Operations",
            style: GoogleFonts.inter(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: _BookingColors.text,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 82,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: operations.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, index) {
                final item = operations[index];
                final selected = _operationFilter == item.filter;

                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => _selectOperation(item.filter),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: isMobile ? 150 : 175,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: selected
                          ? item.accent.withOpacity(.09)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected
                            ? item.accent.withOpacity(.35)
                            : _BookingColors.border,
                      ),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x08000000),
                          blurRadius: 14,
                          offset: Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: item.accent.withOpacity(.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            item.icon,
                            size: 19,
                            color: item.accent,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _BookingColors.muted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${item.count}',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                  color: _BookingColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters({
    required bool isMobile,
  }) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 28,
        10,
        isMobile ? 16 : 28,
        14,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: _BookingColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    SizedBox(
                      width: isMobile ? 150 : 205,
                      child: DropdownButtonFormField<_BookingSearchField>(
                        value: _searchField,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Search by',
                          prefixIcon: const Icon(Icons.tune_rounded, size: 18),
                          filled: true,
                          fillColor: _BookingColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        items: _BookingSearchField.values.map((field) => DropdownMenuItem<_BookingSearchField>(
                          value: field,
                          child: Text(_searchFieldLabel(field), overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
                        )).toList(),
                        onChanged: _changeSearchField,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        readOnly: _searchFieldIsDate,
                        onTap: _searchFieldIsDate ? _pickSearchDate : null,
                        keyboardType: _searchField == _BookingSearchField.customerPhone ? TextInputType.phone : TextInputType.text,
                        decoration: InputDecoration(
                          hintText: _searchHint,
                          prefixIcon: Icon(_searchFieldIsDate ? Icons.calendar_month_rounded : Icons.search_rounded, size: 20),
                          suffixIcon: _searchFieldIsDate
                              ? IconButton(onPressed: _pickSearchDate, icon: const Icon(Icons.calendar_month_rounded, size: 18))
                              : (_searchController.text.isEmpty ? null : IconButton(onPressed: _searchController.clear, icon: const Icon(Icons.close_rounded, size: 18))),
                          filled: true,
                          fillColor: _BookingColors.background,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(13),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                    if (!isMobile) ...[
                      const SizedBox(width: 10),
                      _FilterButton(
                        icon: Icons.restart_alt_rounded,
                        label: 'Reset',
                        onTap: _resetFilters,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                if (isMobile)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: _filterRow(),
                  )
                else
                  _filterRow(),
              ],
            ),
          ),
          if (isMobile)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _resetFilters,
                icon: const Icon(Icons.restart_alt_rounded, size: 17),
                label: const Text('Reset filters'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterRow() {
    return Row(
      children: [
        _DropdownFilter<BookingStatus?>(
          value: _statusFilter,
          label: 'Status',
          items: [
            const DropdownMenuItem<BookingStatus?>(
              value: null,
              child: Text('All Statuses'),
            ),
            ...BookingStatus.values.map(
              (status) => DropdownMenuItem<BookingStatus?>(
                value: status,
                child: Text(_statusLabel(status)),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _statusFilter = value;
              _operationFilter = _OperationFilter.all;
            });
            _refreshCurrentView();
          },
        ),
        const SizedBox(width: 8),
        _DropdownFilter<PaymentStatus?>(
          value: _paymentFilter,
          label: 'Payment',
          items: [
            const DropdownMenuItem<PaymentStatus?>(
              value: null,
              child: Text('All Payments'),
            ),
            ...PaymentStatus.values.map(
              (status) => DropdownMenuItem<PaymentStatus?>(
                value: status,
                child: Text(_paymentStatusLabel(status)),
              ),
            ),
          ],
          onChanged: (value) {
            setState(() {
              _paymentFilter = value;
              _operationFilter = _OperationFilter.all;
            });
            _refreshCurrentView();
          },
        ),
        const SizedBox(width: 8),
        _DropdownFilter<_BookingDateScope>(
          value: _dateScope,
          label: 'Date',
          items: const [
            DropdownMenuItem(
              value: _BookingDateScope.all,
              child: Text('All Dates'),
            ),
            DropdownMenuItem(
              value: _BookingDateScope.today,
              child: Text('Today'),
            ),
            DropdownMenuItem(
              value: _BookingDateScope.tomorrow,
              child: Text('Tomorrow'),
            ),
            DropdownMenuItem(
              value: _BookingDateScope.next7Days,
              child: Text('Next 7 Days'),
            ),
            DropdownMenuItem(
              value: _BookingDateScope.custom,
              child: Text('Custom Range'),
            ),
          ],
          onChanged: (value) {
            if (value == _BookingDateScope.custom) {
              _pickCustomDateRange();
              return;
            }

            if (value == null) return;
            setState(() {
              _dateScope = value;
              _operationFilter = _OperationFilter.all;
            });
            _refreshCurrentView();
          },
        ),
        if (_dateScope == _BookingDateScope.custom &&
            _customRange != null) ...[
          const SizedBox(width: 8),
          _SmallFilterChip(
            label:
                '${_formatDate(_customRange!.start)} - ${_formatDate(_customRange!.end)}',
            onTap: _pickCustomDateRange,
          ),
        ],
      ],
    );
  }

  List<Widget> _buildBookingSlivers({
    required bool isMobile,
    required bool isTablet,
  }) {
    final bookings = _filteredBookings;
    final horizontal = isMobile ? 16.0 : 28.0;

    return <Widget>[
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 0),
        sliver: SliverToBoxAdapter(
          child: _buildListHeader(
            count: bookings.length,
            isMobile: isMobile,
          ),
        ),
      ),
      if (bookings.isEmpty)
        SliverPadding(
          padding: EdgeInsets.symmetric(horizontal: horizontal),
          sliver: SliverToBoxAdapter(child: _buildEmptyState()),
        )
      else
        SliverPadding(
          padding: EdgeInsets.fromLTRB(horizontal, 10, horizontal, 0),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final booking = bookings[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _BookingListCard(
                    booking: booking,
                    onTap: () => _openBookingDetails(booking),
                  ),
                );
              },
              childCount: bookings.length,
            ),
          ),
        ),
      if (_loadingMore)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: _BookingColors.primary,
                ),
              ),
            ),
          ),
        )
      else if (_hasMoreBookings && !_searching)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
                'Scroll to load the next 100 bookings',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: _BookingColors.muted,
                ),
              ),
            ),
          ),
        ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, 8, horizontal, 0),
        sliver: SliverToBoxAdapter(
          child: _buildLifecycleStrip(isMobile: isMobile),
        ),
      ),
      SliverPadding(
        padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, 0),
        sliver: SliverToBoxAdapter(
          child: _buildStatusSummary(isMobile: isMobile),
        ),
      ),
    ];
  }

  Widget _buildListHeader({
    required int count,
    required bool isMobile,
  }) {
    final activeLabel = _operationFilter == _OperationFilter.all
        ? 'All Bookings'
        : _operationLabel(_operationFilter);

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activeLabel,
                style: GoogleFonts.inter(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: _BookingColors.text,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _searching
                    ? 'Searching all matching bookings…'
                    : '$count booking${count == 1 ? '' : 's'} loaded${_hasMoreBookings ? ' • more available' : ''}',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: _BookingColors.muted,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (!isMobile)
          Text(
            'Tap a booking to open full details',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: _BookingColors.muted,
            ),
          ),
      ],
    );
  }

  Widget _buildLifecycleStrip({
    required bool isMobile,
  }) {
    final steps = <_LifecycleStep>[
      _LifecycleStep('Pending', _pendingCount, _BookingColors.purple),
      _LifecycleStep(
        'Confirmed',
        _confirmedCount,
        _BookingColors.blue,
      ),
      _LifecycleStep(
        'Pickup Pending',
        _pickupPendingCount,
        _BookingColors.orange,
      ),
      _LifecycleStep('Active', _activeCount, _BookingColors.green),
      _LifecycleStep(
        'Return Pending',
        _returnPendingCount,
        _BookingColors.orange,
      ),
      _LifecycleStep('Completed', _completedCount, _BookingColors.green),
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _BookingColors.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            for (int i = 0; i < steps.length; i++) ...[
              _LifecycleStepWidget(step: steps[i]),
              if (i != steps.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 15,
                    color: _BookingColors.muted.withOpacity(.45),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusSummary({
    required bool isMobile,
  }) {
    final data = <_StatusSummaryData>[
      _StatusSummaryData(
        label: 'Pending',
        count: _pendingCount,
        color: _statusColor(BookingStatus.pending),
      ),
      _StatusSummaryData(
        label: 'Confirmed',
        count: _confirmedCount,
        color: _statusColor(BookingStatus.confirmed),
      ),
      _StatusSummaryData(
        label: 'Pickup Pending',
        count: _pickupPendingCount,
        color: _statusColor(BookingStatus.pickupPending),
      ),
      _StatusSummaryData(
        label: 'Active',
        count: _activeCount,
        color: _statusColor(BookingStatus.active),
      ),
      _StatusSummaryData(
        label: 'Return Pending',
        count: _returnPendingCount,
        color: _statusColor(BookingStatus.returnPending),
      ),
      _StatusSummaryData(
        label: 'Completed',
        count: _completedCount,
        color: _statusColor(BookingStatus.completed),
      ),
      _StatusSummaryData(
        label: 'Cancelled',
        count: _cancelledCount,
        color: _statusColor(BookingStatus.cancelled),
      ),
      _StatusSummaryData(
        label: 'Rejected',
        count: _rejectedCount,
        color: _statusColor(BookingStatus.rejected),
      ),
      _StatusSummaryData(
        label: 'No Show',
        count: _noShowCount,
        color: _statusColor(BookingStatus.noShow),
      ),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _BookingColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Lifecycle Overview',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: _BookingColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: isMobile ? 8 : 18,
            runSpacing: 10,
            children: data.map((item) {
              return SizedBox(
                width: isMobile ? 145 : 155,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item.label,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _BookingColors.muted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      '${item.count}',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: _BookingColors.text,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _BookingColors.border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                size: 42,
                color: _BookingColors.red,
              ),
              const SizedBox(height: 12),
              Text(
                'Unable to load bookings',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _error ?? 'Something went wrong.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: _BookingColors.muted,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => _loadBookings(),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try Again'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 48,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _BookingColors.border),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: _BookingColors.primary.withOpacity(.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.event_busy_rounded,
              size: 30,
              color: _BookingColors.primary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'No bookings found',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try changing the filters or create a new booking.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: _BookingColors.muted,
            ),
          ),
          if (widget.onCreateBooking != null) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: widget.onCreateBooking,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Booking'),
            ),
          ],
        ],
      ),
    );
  }

  static String _currency(double value) {
    return '₹${value.toStringAsFixed(0)}';
  }

  static String _formatDate(DateTime date) {
    const months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  static String _formatTime(DateTime date) {
    final hour = date.hour == 0
        ? 12
        : date.hour > 12
            ? date.hour - 12
            : date.hour;
    final minute = date.minute.toString().padLeft(2, '0');
    final suffix = date.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  static String _statusLabel(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.confirmed:
        return 'Confirmed';
      case BookingStatus.pickupPending:
        return 'Pickup Pending';
      case BookingStatus.active:
        return 'Active';
      case BookingStatus.returnPending:
        return 'Return Pending';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.rejected:
        return 'Rejected';
      case BookingStatus.noShow:
        return 'No Show';
    }
  }

  static String _paymentStatusLabel(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.partiallyPaid:
        return 'Partially Paid';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
      case PaymentStatus.partiallyRefunded:
        return 'Partially Refunded';
    }
  }

  static Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return _BookingColors.purple;
      case BookingStatus.confirmed:
        return _BookingColors.blue;
      case BookingStatus.pickupPending:
        return _BookingColors.orange;
      case BookingStatus.active:
        return _BookingColors.green;
      case BookingStatus.returnPending:
        return _BookingColors.orange;
      case BookingStatus.completed:
        return _BookingColors.green;
      case BookingStatus.cancelled:
        return _BookingColors.red;
      case BookingStatus.rejected:
        return _BookingColors.red;
      case BookingStatus.noShow:
        return _BookingColors.red;
    }
  }

  static Color _paymentColor(PaymentStatus status) {
    switch (status) {
      case PaymentStatus.pending:
        return _BookingColors.orange;
      case PaymentStatus.partiallyPaid:
        return _BookingColors.orange;
      case PaymentStatus.paid:
        return _BookingColors.green;
      case PaymentStatus.failed:
        return _BookingColors.red;
      case PaymentStatus.refunded:
        return _BookingColors.blue;
      case PaymentStatus.partiallyRefunded:
        return _BookingColors.blue;
    }
  }

  static String _operationLabel(_OperationFilter filter) {
    switch (filter) {
      case _OperationFilter.all:
        return 'All Bookings';
      case _OperationFilter.pickupsToday:
        return "Today's Pickups";
      case _OperationFilter.returnsToday:
        return "Today's Returns";
      case _OperationFilter.active:
        return 'Active Rentals';
      case _OperationFilter.pickupPending:
        return 'Pickup Pending';
      case _OperationFilter.returnPending:
        return 'Return Pending';
      case _OperationFilter.upcoming:
        return 'Upcoming Rentals';
      case _OperationFilter.pending:
        return 'Pending Approval';
      case _OperationFilter.outstanding:
        return 'Outstanding Payments';
    }
  }
}

// ================================================================
// BOOKING LIST CARD
// ================================================================

class _BookingListCard extends StatelessWidget {
  const _BookingListCard({
    required this.booking,
    required this.onTap,
  });

  final Booking booking;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor =
        _AdminBookingsScreenState._statusColor(booking.status);
    final paymentColor =
        _AdminBookingsScreenState._paymentColor(booking.paymentStatus);

    final carName = booking.car?.name.trim().isNotEmpty == true
        ? booking.car!.name
        : 'Vehicle ${booking.carId}';

    final branchName =
        booking.pickupBranch?.name.trim().isNotEmpty == true
            ? booking.pickupBranch!.name
            : booking.pickupBranchId;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _BookingColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 16,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTop(statusColor, paymentColor, carName),
              const SizedBox(height: 15),
              const Divider(height: 1, color: _BookingColors.border),
              const SizedBox(height: 14),
              _buildTimeline(branchName),
              const SizedBox(height: 14),
              const Divider(height: 1, color: _BookingColors.border),
              const SizedBox(height: 14),
              _buildBottom(),
            ],
          ),
        ),
      ),
    );
  }
Widget _buildTop(
  Color statusColor,
  Color paymentColor,
  String carName,
) {
  final registrationNumber =
      booking.car?.registrationNumber.trim() ?? '';

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _VehicleThumb(
        image: booking.car?.image ?? '',
        fallbackIcon: Icons.directions_car_rounded,
      ),
      const SizedBox(width: 13),

      Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // VEHICLE NAME + STATUS
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    carName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _BookingColors.text,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: _StatusBadge(
                    label: _AdminBookingsScreenState._statusLabel(
                      booking.status,
                    ),
                    color: statusColor,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 5),

            // REGISTRATION NUMBER
            if (registrationNumber.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.confirmation_number_outlined,
                    size: 13,
                    color: _BookingColors.muted,
                  ),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      registrationNumber,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _BookingColors.text,
                      ),
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 5),

            // BOOKING ID
            Text(
              'Booking #${booking.bookingId}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: _BookingColors.muted,
                fontWeight: FontWeight.w500,
              ),
            ),

            const SizedBox(height: 8),

            // CUSTOMER / OPERATION / PAYMENT TAGS
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                if (booking.status == BookingStatus.pickupPending)
                  const _OperationalAlertTag(
                    icon: Icons.directions_car_rounded,
                    text: 'HANDOVER REQUIRED',
                  ),

                if (booking.status == BookingStatus.returnPending)
                  const _OperationalAlertTag(
                    icon: Icons.assignment_return_rounded,
                    text: 'RETURN INSPECTION REQUIRED',
                  ),

                _MiniTag(
                  icon: Icons.person_outline_rounded,
                  text: booking.customerName.isEmpty
                      ? 'Customer not available'
                      : booking.customerName,
                ),

                if (booking.customerPhone.isNotEmpty)
                  _MiniTag(
                    icon: Icons.phone_outlined,
                    text: booking.customerPhone,
                  ),

                _MiniTag(
                  icon: Icons.credit_card_rounded,
                  text: _AdminBookingsScreenState
                      ._paymentStatusLabel(
                    booking.paymentStatus,
                  ),
                  color: paymentColor,
                ),
              ],
            ),
          ],
        ),
      ),

      const SizedBox(width: 10),

      const Padding(
        padding: EdgeInsets.only(top: 4),
        child: Icon(
          Icons.chevron_right_rounded,
          color: _BookingColors.muted,
        ),
      ),
    ],
  );
}

  Widget _buildTimeline(String branchName) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 600;

        if (narrow) {
          return Column(
            children: [
              _TimelinePoint(
                icon: Icons.login_rounded,
                title: 'Pickup',
                date: booking.pickupDateTime,
                actual: booking.actualPickupDateTime,
                color: _BookingColors.blue,
                branch: branchName,
              ),
              const SizedBox(height: 10),
              _TimelinePoint(
                icon: Icons.logout_rounded,
                title: 'Return',
                date: booking.returnDateTime,
                actual: booking.actualReturnDateTime,
                color: _BookingColors.orange,
                branch:
                    booking.returnBranch?.name ??
                    booking.returnBranchId,
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              child: _TimelinePoint(
                icon: Icons.login_rounded,
                title: 'Pickup',
                date: booking.pickupDateTime,
                actual: booking.actualPickupDateTime,
                color: _BookingColors.blue,
                branch: branchName,
              ),
            ),
            Container(
              width: 42,
              height: 1,
              color: _BookingColors.border,
            ),
            Expanded(
              child: _TimelinePoint(
                icon: Icons.logout_rounded,
                title: 'Return',
                date: booking.returnDateTime,
                actual: booking.actualReturnDateTime,
                color: _BookingColors.orange,
                branch:
                    booking.returnBranch?.name ??
                    booking.returnBranchId,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildBottom() {
    final paid = booking.paidAmount;
    final total = booking.totalAmount;
    final balance = booking.balanceAmount;
    final progress = total <= 0
        ? 0.0
        : (paid / total).clamp(0.0, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 600;

        final payment = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Payment',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _BookingColors.muted,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                Text(
                  '₹${paid.toStringAsFixed(0)} / ₹${total.toStringAsFixed(0)}',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: _BookingColors.text,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: progress,
                backgroundColor: _BookingColors.background,
                valueColor: AlwaysStoppedAnimation<Color>(
                  balance > 0
                      ? _BookingColors.orange
                      : _BookingColors.green,
                ),
              ),
            ),
          ],
        );

        final amount = Column(
          crossAxisAlignment:
              narrow
                  ? CrossAxisAlignment.start
                  : CrossAxisAlignment.end,
          children: [
            Text(
              'Total',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: _BookingColors.muted,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '₹${total.toStringAsFixed(0)}',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: _BookingColors.text,
              ),
            ),
            if (balance > 0.009)
              Text(
                'Due ₹${balance.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _BookingColors.red,
                ),
              )
            else
              Text(
                'Paid',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _BookingColors.green,
                ),
              ),
          ],
        );

        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              payment,
              const SizedBox(height: 12),
              amount,
              const SizedBox(height: 10),
              _buildMetaRow(),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: payment),
            const SizedBox(width: 22),
            amount,
            const SizedBox(width: 22),
            _buildMetaRow(),
          ],
        );
      },
    );
  }

  Widget _buildMetaRow() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: WrapAlignment.end,
      children: [
        _MiniTag(
          icon: Icons.schedule_rounded,
          text: booking.rentalType == 'hourly'
              ? 'Hourly'
              : 'Daily',
        ),
        if (booking.kmPackageName?.isNotEmpty == true)
          _MiniTag(
            icon: Icons.speed_rounded,
            text: booking.kmPackageName!,
          ),
        if (booking.couponCode?.isNotEmpty == true)
          _MiniTag(
            icon: Icons.local_offer_outlined,
            text: booking.couponCode!,
          ),
      ],
    );
  }
}

// ================================================================
// TIMELINE / VEHICLE / BADGES
// ================================================================

class _TimelinePoint extends StatelessWidget {
  const _TimelinePoint({
    required this.icon,
    required this.title,
    required this.date,
    required this.actual,
    required this.color,
    required this.branch,
  });

  final IconData icon;
  final String title;
  final DateTime date;
  final DateTime? actual;
  final Color color;
  final String branch;

  @override
  Widget build(BuildContext context) {
    final actualText = actual == null
        ? 'Not completed'
        : 'Actual ${_AdminBookingsScreenState._formatTime(actual!)}';

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(.09),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 19),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _BookingColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${_AdminBookingsScreenState._formatDate(date)} • ${_AdminBookingsScreenState._formatTime(date)}',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: _BookingColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                actual == null
                    ? branch.isEmpty
                        ? actualText
                        : branch
                    : '$actualText${branch.isEmpty ? '' : ' • $branch'}',
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: actual == null
                      ? _BookingColors.muted
                      : _BookingColors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _VehicleThumb extends StatelessWidget {
  const _VehicleThumb({
    required this.image,
    required this.fallbackIcon,
  });

  final String image;
  final IconData fallbackIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 62,
      height: 62,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _BookingColors.background,
        borderRadius: BorderRadius.circular(15),
      ),
      child: image.trim().isEmpty
          ? Icon(
              fallbackIcon,
              color: _BookingColors.muted,
              size: 28,
            )
          : Image.network(
              image,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Icon(
                fallbackIcon,
                color: _BookingColors.muted,
                size: 28,
              ),
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _BookingColors.primary,
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class _LiveStatusPill extends StatelessWidget {
  const _LiveStatusPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(.07),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withOpacity(.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
  });

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(.09),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}

class _OperationalAlertTag extends StatelessWidget {
  const _OperationalAlertTag({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: _BookingColors.orange.withOpacity(.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _BookingColors.orange.withOpacity(.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.priority_high_rounded,
            size: 12,
            color: _BookingColors.orange,
          ),
          const SizedBox(width: 3),
          Icon(
            icon,
            size: 12,
            color: _BookingColors.orange,
          ),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: _BookingColors.orange,
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({
    required this.icon,
    required this.text,
    this.color,
  });

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effective = color ?? _BookingColors.muted;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 8,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color: (color ?? _BookingColors.text).withOpacity(.035),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (color ?? _BookingColors.border).withOpacity(
            color == null ? 1 : .18,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: effective),
          const SizedBox(width: 4),
          Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: effective,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ================================================================
// KPI / FILTER WIDGETS
// ================================================================

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    this.valueSuffix,
    this.compactValue = false,
    this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final String? valueSuffix;
  final bool compactValue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 142),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _BookingColors.border),
            boxShadow: const [
              BoxShadow(
                color: Color(0x05000000),
                blurRadius: 15,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(.09),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: accent,
                      size: 19,
                    ),
                  ),
                  const Spacer(),
                  if (onTap != null)
                    Icon(
                      Icons.arrow_outward_rounded,
                      size: 15,
                      color: _BookingColors.muted.withOpacity(.65),
                    ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: _BookingColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: compactValue ? 19 : 25,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        color: _BookingColors.text,
                      ),
                    ),
                  ),
                  if (valueSuffix != null) ...[
                    const SizedBox(width: 5),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        valueSuffix!,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: _BookingColors.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderAction extends StatelessWidget {
  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: _BookingColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onTap,
  });

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: _BookingColors.border),
          ),
          child: Icon(
            icon,
            size: 19,
            color: onTap == null
                ? _BookingColors.muted.withOpacity(.45)
                : _BookingColors.text,
          ),
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: _BookingColors.text,
        side: const BorderSide(color: _BookingColors.border),
        padding: const EdgeInsets.symmetric(
          horizontal: 13,
          vertical: 12,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(13),
        ),
      ),
      icon: Icon(icon, size: 17),
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DropdownFilter<T> extends StatelessWidget {
  const _DropdownFilter({
    required this.value,
    required this.label,
    required this.items,
    required this.onChanged,
  });

  final T value;
  final String label;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 145),
      padding: const EdgeInsets.symmetric(horizontal: 11),
      decoration: BoxDecoration(
        color: _BookingColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _BookingColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
          ),
          hint: Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: _BookingColors.muted,
            ),
          ),
          style: GoogleFonts.inter(
            fontSize: 11,
            color: _BookingColors.text,
            fontWeight: FontWeight.w700,
          ),
          items: items,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _SmallFilterChip extends StatelessWidget {
  const _SmallFilterChip({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: _BookingColors.primary.withOpacity(.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _BookingColors.primary.withOpacity(.16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.date_range_rounded,
              size: 15,
              color: _BookingColors.primary,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                color: _BookingColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// DATA CLASSES
// ================================================================

enum _BookingDateScope {
  all,
  today,
  tomorrow,
  next7Days,
  custom,
}

enum _OperationFilter {
  all,
  pickupsToday,
  pickupPending,
  returnsToday,
  active,
  returnPending,
  upcoming,
  pending,
  outstanding,
}

class _OperationData {
  const _OperationData({
    required this.filter,
    required this.label,
    required this.count,
    required this.icon,
    required this.accent,
  });

  final _OperationFilter filter;
  final String label;
  final int count;
  final IconData icon;
  final Color accent;
}

class _LifecycleStep {
  const _LifecycleStep(this.label, this.count, this.color);

  final String label;
  final int count;
  final Color color;
}

class _LifecycleStepWidget extends StatelessWidget {
  const _LifecycleStepWidget({required this.step});

  final _LifecycleStep step;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 112),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: step.color.withOpacity(.055),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: step.color.withOpacity(.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step.label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: _BookingColors.muted,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${step.count}',
            style: GoogleFonts.inter(
              fontSize: 20,
              color: step.color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusSummaryData {
  const _StatusSummaryData({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;
}

// ================================================================
// COLORS
// ================================================================

class _BookingColors {
  static const Color background = Color(0xFFF6F8FB);
  static const Color text = Color(0xFF18212F);
  static const Color muted = Color(0xFF758195);
  static const Color border = Color(0xFFE7EBF1);

  static const Color primary = Color(0xFF315CF6);

  static const Color blue = Color(0xFF3B82F6);
  static const Color green = Color(0xFF16A34A);
  static const Color orange = Color(0xFFF59E0B);
  static const Color red = Color(0xFFEF4444);
  static const Color purple = Color(0xFF8B5CF6);
  static const Color teal = Color(0xFF0F9F9A);
  static const Color indigo = Color(0xFF6366F1);
}
