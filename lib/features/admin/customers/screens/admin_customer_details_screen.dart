import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../../core/config/app_config.dart';
import '../../../customer/models/customer.dart';
import '../../../customer/models/customer_document.dart';
import '../../../customer/services/customer_service.dart';
import '../../../customer/services/document_service.dart';

class AdminCustomerDetailsScreen extends StatefulWidget {
  final Customer customer;

  const AdminCustomerDetailsScreen({
    super.key,
    required this.customer,
  });

  @override
  State<AdminCustomerDetailsScreen> createState() =>
      _AdminCustomerDetailsScreenState();
}

class _AdminCustomerDetailsScreenState
    extends State<AdminCustomerDetailsScreen> {
  // ============================================================
  // PREMIUM LIGHT PALETTE
  // ============================================================

  static const Color bg = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);

  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color softAccent = Color(0xFFE6FFFB);

  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  static const Color danger = Color(0xFFDC2626);
  static const Color warning = Color(0xFFCA8A04);

  // ============================================================
  // SERVICES
  // ============================================================

  final CustomerService _customerService =
      CustomerService.instance;

  final DocumentService _documentService =
      DocumentService();

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // ============================================================
  // STATE
  // ============================================================

  late Customer _customer;

  List<CustomerDocument> _documents = [];

  bool _loading = true;
  bool _documentsLoading = false;
  bool _processingDocument = false;
  bool _changingStatus = false;

  // ============================================================
  // TENANT
  // ============================================================

  String get _tenantId =>
      AppConfig.tenant.tenantId;

  // ============================================================
  // ADMIN UID
  // ============================================================

  String get _adminId =>
      _auth.currentUser?.uid ?? '';

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _customer = widget.customer;

    _loadDocuments();
  }

  // ============================================================
  // LOAD DOCUMENTS
  // ============================================================

  Future<void> _loadDocuments({
    bool showLoader = true,
  }) async {
    if (showLoader && mounted) {
      setState(() {
        _loading = true;
        _documentsLoading = true;
      });
    } else if (mounted) {
      setState(() {
        _documentsLoading = true;
      });
    }

    try {
      final documents =
          await _documentService.getDocuments(
        tenantId: _tenantId,
        customerId: _customer.customerId,
        admin: true,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _documents = documents;
        _loading = false;
        _documentsLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _documentsLoading = false;
      });

      _showError(
        'Unable to load customer documents.\n'
        '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    await _loadDocuments(
      showLoader: false,
    );

    await _refreshCustomer();
  }

  // ============================================================
  // REFRESH CUSTOMER
  // ============================================================

  Future<void> _refreshCustomer() async {
    try {
      final customer =
          await _customerService.getCustomer(
        tenantId: _tenantId,
        customerId: _customer.customerId,
      );

      if (!mounted || customer == null) {
        return;
      }

      setState(() {
        _customer = customer;
      });
    } catch (_) {
      // The main operation may already have succeeded.
      // Don't show a second error for a refresh failure.
    }
  }

  // ============================================================
  // ACTIVATE / DEACTIVATE
  // ============================================================

  Future<void> _toggleActive() async {
    if (_changingStatus) {
      return;
    }

    final nextStatus =
        !_customer.isActive;

    final confirmed =
        await _showConfirmation(
      title: nextStatus
          ? 'Activate customer?'
          : 'Deactivate customer?',
      message: nextStatus
          ? 'This customer will be able to use the rental application.'
          : 'This customer will no longer be able to use the rental account.',
      confirmText: nextStatus
          ? 'Activate'
          : 'Deactivate',
      destructive: !nextStatus,
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _changingStatus = true;
    });

    try {
      await _customerService.setCustomerActive(
        tenantId: _tenantId,
        customerId: _customer.customerId,
        isActive: nextStatus,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _customer = _customer.copyWith(
          isActive: nextStatus,
        );
        _changingStatus = false;
      });

      _showSuccess(
        nextStatus
            ? 'Customer activated successfully.'
            : 'Customer deactivated successfully.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _changingStatus = false;
      });

      _showError(
        'Unable to update customer.\n'
        '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // VERIFY DOCUMENT
  // ============================================================

  Future<void> _verifyDocument(
    CustomerDocument document,
  ) async {
    if (_processingDocument) {
      return;
    }

    if (_adminId.isEmpty) {
      _showError(
        'Admin authentication is not available.',
      );
      return;
    }

    final confirmed =
        await _showConfirmation(
      title: 'Verify document?',
      message:
          'This document will be marked as verified.',
      confirmText: 'Verify',
      destructive: false,
    );

    if (!confirmed) {
      return;
    }

    setState(() {
      _processingDocument = true;
    });

    try {
      await _documentService.verifyDocument(
        tenantId: _tenantId,
        customerId: _customer.customerId,
        documentId: document.documentId,
        adminId: _adminId,
      );

      await _loadDocuments(
        showLoader: false,
      );

      await _refreshCustomer();

      if (!mounted) {
        return;
      }

      setState(() {
        _processingDocument = false;
      });

      _showSuccess(
        '${document.typeLabel} verified successfully.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingDocument = false;
      });

      _showError(
        'Unable to verify document.\n'
        '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // REJECT DOCUMENT
  // ============================================================

  Future<void> _rejectDocument(
    CustomerDocument document,
  ) async {
    if (_processingDocument) {
      return;
    }

    if (_adminId.isEmpty) {
      _showError(
        'Admin authentication is not available.',
      );
      return;
    }

    final reason =
        await _showRejectDialog();

    if (reason == null ||
        reason.trim().isEmpty) {
      return;
    }

    setState(() {
      _processingDocument = true;
    });

    try {
      await _documentService.rejectDocument(
        tenantId: _tenantId,
        customerId: _customer.customerId,
        documentId: document.documentId,
        adminId: _adminId,
        reason: reason.trim(),
      );

      await _loadDocuments(
        showLoader: false,
      );

      await _refreshCustomer();

      if (!mounted) {
        return;
      }

      setState(() {
        _processingDocument = false;
      });

      _showSuccess(
        '${document.typeLabel} rejected.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _processingDocument = false;
      });

      _showError(
        'Unable to reject document.\n'
        '${_cleanError(e)}',
      );
    }
  }

  // ============================================================
  // FIND DOCUMENT
  // ============================================================

  CustomerDocument? _findDocument(
    CustomerDocumentType type,
  ) {
    for (final document in _documents) {
      if (document.type == type) {
        return document;
      }
    }

    return null;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: bg,
        surfaceTintColor: bg,
        elevation: 0,
        titleSpacing: 20,
        title: const Text(
          'Customer Details',
          style: TextStyle(
            color: heading,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading
                ? null
                : _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
              color: heading,
            ),
          ),
          IconButton(
            tooltip: _customer.isActive
                ? 'Deactivate'
                : 'Activate',
            onPressed:
                _changingStatus
                    ? null
                    : _toggleActive,
            icon: Icon(
              _customer.isActive
                  ? Icons.person_off_outlined
                  : Icons.person_outline_rounded,
              color: _customer.isActive
                  ? danger
                  : primary,
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: primary,
              ),
            )
          : RefreshIndicator(
              color: primary,
              backgroundColor: card,
              onRefresh: _refresh,
              child: ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  40,
                ),
                children: [
                  _profileHeader(),

                  const SizedBox(height: 14),

                  _accountStatusCard(),

                  const SizedBox(height: 14),

                  _section(
                    'Personal Information',
                    [
                      _row(
                        'Phone',
                        _customer.phone,
                      ),
                      _row(
                        'Email',
                        _customer.email,
                      ),
                      _row(
                        'Date of birth',
                        _customer.dateOfBirth,
                      ),
                      _row(
                        'Gender',
                        _formatValue(
                          _customer.gender,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _section(
                    'Address',
                    [
                      _row(
                        'Address',
                        _addressText(),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _section(
                    'Emergency Contact',
                    [
                      _row(
                        'Name',
                        _customer
                                .emergencyContact
                                ?.name ??
                            '',
                      ),
                      _row(
                        'Phone',
                        _customer
                                .emergencyContact
                                ?.phone ??
                            '',
                      ),
                      _row(
                        'Relationship',
                        _customer
                                .emergencyContact
                                ?.relationship ??
                            '',
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _documentsSection(),

                  const SizedBox(height: 12),

                  _section(
                    'Rental Summary',
                    [
                      _row(
                        'Total bookings',
                        '${_customer.totalBookings}',
                      ),
                      _row(
                        'Completed bookings',
                        '${_customer.completedBookings}',
                      ),
                      _row(
                        'Account',
                        _customer.isActive
                            ? 'Active'
                            : 'Inactive',
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _technicalSection(),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // PROFILE HEADER
  // ============================================================

  Widget _profileHeader() {
    final name =
        _customer.fullName.trim();

    final initials =
        _initials(name);

    final imageUrl =
        _customer.profileImageUrl.trim();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: border,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A17201F),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              if (imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(18),
                  child: Image.network(
                    imageUrl,
                    width: 68,
                    height: 68,
                    fit: BoxFit.cover,
                    errorBuilder:
                        (_, __, ___) =>
                            _initialAvatar(
                      initials,
                    ),
                  ),
                )
              else
                _initialAvatar(initials),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isEmpty
                          ? 'Unnamed customer'
                          : name,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: heading,
                        fontSize: 19,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      _customer.phone
                              .trim()
                              .isEmpty
                          ? 'No phone number'
                          : _customer.phone,
                      style: const TextStyle(
                        color: body,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 9),

                    Wrap(
                      spacing: 7,
                      runSpacing: 6,
                      children: [
                        _chip(
                          _customer.kycStatus,
                        ),
                        _chip(
                          _customer.isActive
                              ? 'active'
                              : 'inactive',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.fingerprint_rounded,
                  size: 16,
                  color: primary,
                ),
                const SizedBox(width: 7),
                const Text(
                  'Firebase UID',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    _customer.customerId,
                    maxLines: 1,
                    overflow:
                        TextOverflow.ellipsis,
                    textAlign:
                        TextAlign.end,
                    style: const TextStyle(
                      color: heading,
                      fontSize: 10.5,
                      fontWeight:
                          FontWeight.w700,
                    ),
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
  // INITIAL AVATAR
  // ============================================================

  Widget _initialAvatar(
    String initials,
  ) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius:
            BorderRadius.circular(18),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: primary,
            fontSize: 25,
            fontWeight:
                FontWeight.w800,
          ),
        ),
      ),
    );
  }

  // ============================================================
  // ACCOUNT STATUS
  // ============================================================

  Widget _accountStatusCard() {
    final active =
        _customer.isActive;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: active
                  ? softAccent
                  : const Color(0xFFFFF1F2),
              borderRadius:
                  BorderRadius.circular(13),
            ),
            child: Icon(
              active
                  ? Icons.check_circle_outline_rounded
                  : Icons.block_rounded,
              color:
                  active ? primary : danger,
              size: 21,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  active
                      ? 'Customer account is active'
                      : 'Customer account is inactive',
                  style: const TextStyle(
                    color: heading,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  active
                      ? 'The customer can use the rental application.'
                      : 'The customer cannot use the rental account.',
                  style: const TextStyle(
                    color: body,
                    fontSize: 11,
                    height: 1.35,
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
  // DOCUMENT SECTION
  // ============================================================

  Widget _documentsSection() {
    final license = _findDocument(
      CustomerDocumentType.drivingLicense,
    );

    final governmentId = _findDocument(
      CustomerDocumentType.governmentId,
    );

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'KYC & Documents',
                      style: TextStyle(
                        color: heading,
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Review and verify customer documents.',
                      style: TextStyle(
                        color: body,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              if (_documentsLoading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                    color: primary,
                  ),
                )
              else
                IconButton(
                  tooltip:
                      'Refresh documents',
                  onPressed:
                      _refresh,
                  icon:
                      const Icon(
                    Icons.refresh_rounded,
                    color: primary,
                    size: 20,
                  ),
                ),
            ],
          ),

          const SizedBox(height: 14),

          _documentCard(
            license,
            CustomerDocumentType.drivingLicense,
          ),

          const SizedBox(height: 10),

          _documentCard(
            governmentId,
            CustomerDocumentType.governmentId,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DOCUMENT CARD
  // ============================================================

  Widget _documentCard(
    CustomerDocument? document,
    CustomerDocumentType type,
  ) {
    final title =
        type ==
                CustomerDocumentType
                    .drivingLicense
            ? 'Driving License'
            : 'Government ID';

    if (document == null) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: bg,
          borderRadius:
              BorderRadius.circular(16),
          border: Border.all(
            color: border,
          ),
        ),
        child: Row(
          children: [
            _documentIcon(muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: heading,
                      fontSize: 13,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Not uploaded',
                    style: TextStyle(
                      color: muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            _chip('not_uploaded'),
          ],
        ),
      );
    }

    final status =
        document.status;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            BorderRadius.circular(16),
        border: Border.all(
          color: status ==
                  CustomerDocumentStatus
                      .verified
              ? const Color(0xFFB8E7DF)
              : border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _documentIcon(
                _documentStatusColor(
                  status,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: heading,
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      document.documentNumber
                              .trim()
                              .isEmpty
                          ? 'No document number'
                          : document.documentNumber,
                      maxLines: 1,
                      overflow:
                          TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: body,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _chip(
                _documentStatusKey(status),
              ),
            ],
          ),

          const SizedBox(height: 12),

          _documentImages(document),

          if (document.rejectionReason
              .trim()
              .isNotEmpty) ...[
            const SizedBox(height: 10),
            _rejectionReason(
              document.rejectionReason,
            ),
          ],

          if (status ==
                  CustomerDocumentStatus
                      .pending ||
              status ==
                  CustomerDocumentStatus
                      .rejected) ...[
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        _processingDocument
                            ? null
                            : () =>
                                _rejectDocument(
                              document,
                            ),
                    style:
                        OutlinedButton.styleFrom(
                      foregroundColor:
                          danger,
                      side:
                          const BorderSide(
                        color: danger,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          11,
                        ),
                      ),
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 17,
                    ),
                    label: const Text(
                      'Reject',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 9),

                Expanded(
                  child: ElevatedButton.icon(
                    onPressed:
                        _processingDocument
                            ? null
                            : () =>
                                _verifyDocument(
                              document,
                            ),
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          primary,
                      foregroundColor:
                          Colors.white,
                      disabledBackgroundColor:
                          primary.withValues(
                        alpha: 0.45,
                      ),
                      elevation: 0,
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(
                          11,
                        ),
                      ),
                    ),
                    icon: _processingDocument
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : const Icon(
                            Icons
                                .check_rounded,
                            size: 17,
                          ),
                    label: Text(
                      _processingDocument
                          ? 'Processing'
                          : 'Verify',
                      style:
                          const TextStyle(
                        fontSize: 11,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          if (status ==
              CustomerDocumentStatus
                  .verified) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(
                  Icons.verified_rounded,
                  color: primary,
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Document verified successfully',
                  style: TextStyle(
                    color: primary,
                    fontSize: 11,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // DOCUMENT IMAGES
  // ============================================================

  Widget _documentImages(
    CustomerDocument document,
  ) {
    return Row(
      children: [
        Expanded(
          child: _documentImage(
            label: 'Front',
            url: document.frontImageUrl,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _documentImage(
            label: 'Back',
            url: document.backImageUrl,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DOCUMENT IMAGE
  // ============================================================

  Widget _documentImage({
    required String label,
    required String url,
  }) {
    final hasImage =
        url.trim().isNotEmpty;

    return GestureDetector(
      onTap: hasImage
          ? () => _showImagePreview(
                label,
                url,
              )
          : null,
      child: Container(
        height: 105,
        clipBehavior:
            Clip.antiAlias,
        decoration: BoxDecoration(
          color:
              const Color(0xFFEFF4F2),
          borderRadius:
              BorderRadius.circular(13),
          border: Border.all(
            color: border,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (hasImage)
              Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) =>
                        _imageError(),
              )
            else
              _imageError(),

            Positioned(
              left: 8,
              bottom: 8,
              child: Container(
                padding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 8,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.black
                      .withValues(
                    alpha: 0.62,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    8,
                  ),
                ),
                child: Text(
                  label,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ),

            if (hasImage)
              const Positioned(
                right: 8,
                top: 8,
                child: DecoratedBox(
                  decoration:
                      BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: Padding(
                    padding:
                        EdgeInsets.all(5),
                    child: Icon(
                      Icons
                          .zoom_in_rounded,
                      color: Colors.white,
                      size: 15,
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
  // IMAGE ERROR
  // ============================================================

  Widget _imageError() {
    return const Center(
      child: Icon(
        Icons
            .image_not_supported_outlined,
        color: muted,
        size: 25,
      ),
    );
  }

  // ============================================================
  // IMAGE PREVIEW
  // ============================================================

  void _showImagePreview(
    String title,
    String url,
  ) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          backgroundColor:
              Colors.transparent,
          insetPadding:
              const EdgeInsets.all(16),
          child: Stack(
            children: [
              InteractiveViewer(
                minScale: 0.8,
                maxScale: 4,
                child: ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (_, __, ___) {
                      return Container(
                        height: 300,
                        color: Colors.white,
                        child:
                            const Center(
                          child: Text(
                            'Unable to load image',
                            style:
                                TextStyle(
                              color: heading,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape:
                      const CircleBorder(),
                  child: IconButton(
                    onPressed: () =>
                        Navigator.pop(
                      context,
                    ),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              Positioned(
                left: 10,
                bottom: 10,
                child: Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Colors.black54,
                    borderRadius:
                        BorderRadius.circular(
                      9,
                    ),
                  ),
                  child: Text(
                    title,
                    style:
                        const TextStyle(
                      color: Colors.white,
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // REJECTION REASON
  // ============================================================

  Widget _rejectionReason(
    String reason,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color:
            const Color(0xFFFFF1F2),
        borderRadius:
            BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: danger,
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Rejection reason: $reason',
              style: const TextStyle(
                color: danger,
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TECHNICAL INFORMATION
  // ============================================================

  Widget _technicalSection() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Account Information',
            style: TextStyle(
              color: heading,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          _row(
            'Customer ID',
            _customer.customerId,
          ),
          _row(
            'Tenant ID',
            _customer.tenantId,
          ),
          _row(
            'Profile',
            _customer.profileCompleted
                ? 'Completed'
                : 'Incomplete',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION
  // ============================================================

  Widget _section(
    String title,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: card,
        borderRadius:
            BorderRadius.circular(20),
        border: Border.all(
          color: border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: heading,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  // ============================================================
  // ROW
  // ============================================================

  Widget _row(
    String label,
    String value,
  ) {
    final display =
        value.trim().isEmpty
            ? '—'
            : value;

    return Padding(
      padding:
          const EdgeInsets.symmetric(
        vertical: 6,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                color: muted,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              display,
              style: const TextStyle(
                color: heading,
                fontSize: 12.5,
                fontWeight:
                    FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CHIP
  // ============================================================

  Widget _chip(
    String status,
  ) {
    final normalized =
        status.toLowerCase();

    final color =
        _statusColor(normalized);

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 5,
      ),
      decoration: BoxDecoration(
        color:
            color.withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(20),
      ),
      child: Text(
        _statusText(normalized),
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight:
              FontWeight.w800,
        ),
      ),
    );
  }

  // ============================================================
  // STATUS COLOR
  // ============================================================

  Color _statusColor(
    String status,
  ) {
    switch (status) {
      case 'verified':
      case 'active':
        return primary;

      case 'pending':
        return warning;

      case 'rejected':
      case 'inactive':
        return danger;

      default:
        return muted;
    }
  }

  // ============================================================
  // STATUS TEXT
  // ============================================================

  String _statusText(
    String status,
  ) {
    switch (status) {
      case 'verified':
        return 'VERIFIED';

      case 'active':
        return 'ACTIVE';

      case 'pending':
        return 'PENDING';

      case 'rejected':
        return 'REJECTED';

      case 'inactive':
        return 'INACTIVE';

      case 'not_started':
        return 'NOT STARTED';

      case 'not_uploaded':
        return 'NOT UPLOADED';

      default:
        return status
            .replaceAll('_', ' ')
            .toUpperCase();
    }
  }

  // ============================================================
  // DOCUMENT STATUS KEY
  // ============================================================

  String _documentStatusKey(
    CustomerDocumentStatus status,
  ) {
    switch (status) {
      case CustomerDocumentStatus.notUploaded:
        return 'not_uploaded';

      case CustomerDocumentStatus.pending:
        return 'pending';

      case CustomerDocumentStatus.verified:
        return 'verified';

      case CustomerDocumentStatus.rejected:
        return 'rejected';
    }
  }

  // ============================================================
  // DOCUMENT STATUS COLOR
  // ============================================================

  Color _documentStatusColor(
    CustomerDocumentStatus status,
  ) {
    switch (status) {
      case CustomerDocumentStatus.verified:
        return primary;

      case CustomerDocumentStatus.pending:
        return warning;

      case CustomerDocumentStatus.rejected:
        return danger;

      case CustomerDocumentStatus.notUploaded:
        return muted;
    }
  }

  // ============================================================
  // DOCUMENT ICON
  // ============================================================

  Widget _documentIcon(
    Color color,
  ) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color:
            color.withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(13),
      ),
      child: Icon(
        Icons.description_outlined,
        color: color,
        size: 20,
      ),
    );
  }

  // ============================================================
  // ADDRESS
  // ============================================================

  String _addressText() {
    final address =
        _customer.address;

    if (address == null) {
      return '';
    }

    return [
      address.addressLine1,
      address.addressLine2,
      address.city,
      address.state,
      address.postalCode,
      address.country,
    ]
        .where(
          (value) =>
              value.trim().isNotEmpty,
        )
        .join(', ');
  }

  // ============================================================
  // INITIALS
  // ============================================================

  String _initials(
    String name,
  ) {
    if (name.isEmpty) {
      return '?';
    }

    final parts =
        name.split(RegExp(r'\s+'));

    if (parts.length == 1) {
      return parts.first
          .substring(0, 1)
          .toUpperCase();
    }

    return (
      parts.first.substring(0, 1) +
          parts.last.substring(0, 1)
    ).toUpperCase();
  }

  // ============================================================
  // FORMAT VALUE
  // ============================================================

  String _formatValue(
    String value,
  ) {
    if (value.trim().isEmpty) {
      return '';
    }

    return value
        .replaceAll('_', ' ')
        .split(' ')
        .map(
          (word) => word.isEmpty
              ? ''
              : '${word[0].toUpperCase()}'
                  '${word.substring(1)}',
        )
        .join(' ');
  }

  // ============================================================
  // CONFIRMATION
  // ============================================================

  Future<bool> _showConfirmation({
    required String title,
    required String message,
    required String confirmText,
    required bool destructive,
  }) async {
    final result =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: card,
          surfaceTintColor: card,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: heading,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: body,
              height: 1.45,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                false,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: body,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pop(
                context,
                true,
              ),
              style:
                  ElevatedButton.styleFrom(
                backgroundColor:
                    destructive
                        ? danger
                        : primary,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              child: Text(
                confirmText,
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  // ============================================================
  // REJECT DIALOG
  // ============================================================

  Future<String?> _showRejectDialog() async {
    final controller =
        TextEditingController();

    final result =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: card,
          surfaceTintColor: card,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(20),
          ),
          title: const Text(
            'Reject document',
            style: TextStyle(
              color: heading,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize:
                MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Provide a reason so the customer knows what needs to be corrected.',
                style: TextStyle(
                  color: body,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: controller,
                maxLines: 4,
                autofocus: true,
                decoration:
                    InputDecoration(
                  hintText:
                      'Example: Document image is unclear.',
                  filled: true,
                  fillColor: bg,
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    borderSide:
                        const BorderSide(
                      color: border,
                    ),
                  ),
                  enabledBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    borderSide:
                        const BorderSide(
                      color: border,
                    ),
                  ),
                  focusedBorder:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                    borderSide:
                        const BorderSide(
                      color: danger,
                      width: 1.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.pop(
                context,
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: body,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final reason =
                    controller.text
                        .trim();

                if (reason.isEmpty) {
                  return;
                }

                Navigator.pop(
                  context,
                  reason,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                backgroundColor: danger,
                foregroundColor:
                    Colors.white,
                elevation: 0,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              child: const Text(
                'Reject',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );

    controller.dispose();

    return result;
  }

  // ============================================================
  // SUCCESS
  // ============================================================

  void _showSuccess(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(16),
          backgroundColor: primary,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
          content: Row(
            children: [
              const Icon(
                Icons
                    .check_circle_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(16),
          backgroundColor: danger,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
          content: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontWeight:
                        FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  // ============================================================
  // ERROR CLEANER
  // ============================================================

  String _cleanError(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }
}