import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/config/app_config.dart';

class AdminPushNotificationScreen extends StatefulWidget {
  const AdminPushNotificationScreen({
    super.key,
  });

  @override
  State<AdminPushNotificationScreen> createState() =>
      _AdminPushNotificationScreenState();
}

class _AdminPushNotificationScreenState
    extends State<AdminPushNotificationScreen> {
  // ============================================================
  // COLORS
  // ============================================================

  static const Color primary =
      Color(0xFF111827);

  static const Color softAccent =
      Color(0xFFF3F4F6);

  static const Color heading =
      Color(0xFF111827);

  static const Color bodyText =
      Color(0xFF4B5563);

  static const Color muted =
      Color(0xFF9CA3AF);

  static const Color border =
      Color(0xFFE5E7EB);

  static const Color background =
      Color(0xFFF8FAFC);

  static const Color success =
      Color(0xFF16A34A);

  static const Color danger =
      Color(0xFFDC2626);

  // ============================================================
  // CONTROLLERS
  // ============================================================

  final TextEditingController _titleController =
      TextEditingController();

  final TextEditingController _messageController =
      TextEditingController();

  final TextEditingController _bookingIdController =
      TextEditingController();

  final TextEditingController _carIdController =
      TextEditingController();

  final TextEditingController _offerIdController =
      TextEditingController();

  final TextEditingController _customerSearchController =
      TextEditingController();

  // ============================================================
  // SERVICES
  // ============================================================

  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  final FirebaseStorage _storage =
      FirebaseStorage.instance;

  final FirebaseFunctions _functions =
      FirebaseFunctions.instance;

  final ImagePicker _imagePicker =
      ImagePicker();

  // ============================================================
  // STATE
  // ============================================================

  File? _selectedImage;

  String? _uploadedImageUrl;

  bool _uploadingImage = false;

  bool _sending = false;

  String _notificationType =
      'general';

  String _action =
      'home';

  String _targetType =
      'all_customers';

  String? _selectedCustomerId;

  String? _selectedCustomerName;

  bool _showAdvanced =
      false;

  bool _showCustomerPicker =
      false;

  List<_CustomerItem> _customers = [];

  bool _loadingCustomers = false;

  String _customerSearch = '';

  // ============================================================
  // TENANT
  // ============================================================

  String get tenantId {
    return AppConfig.tenant.tenantId;
  }

  // ============================================================
  // LIFECYCLE
  // ============================================================

  @override
  void initState() {
    super.initState();

    _titleController.addListener(_refreshPreview);
    _messageController.addListener(_refreshPreview);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _messageController.dispose();
    _bookingIdController.dispose();
    _carIdController.dispose();
    _offerIdController.dispose();
    _customerSearchController.dispose();

    super.dispose();
  }

  void _refreshPreview() {
    if (mounted) {
      setState(() {});
    }
  }

  // ============================================================
  // PICK IMAGE
  // ============================================================

  Future<void> _pickImage() async {
    try {
      final XFile? picked =
          await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (picked == null) {
        return;
      }

      setState(() {
        _selectedImage =
            File(picked.path);

        _uploadedImageUrl =
            null;
      });
    } catch (e) {
      _showError(
        'Unable to select image.',
        e,
      );
    }
  }

  // ============================================================
  // REMOVE IMAGE
  // ============================================================

  void _removeImage() {
    setState(() {
      _selectedImage = null;
      _uploadedImageUrl = null;
    });
  }

  // ============================================================
  // UPLOAD IMAGE
  // ============================================================

  Future<String?> _uploadNotificationImage() async {
    if (_selectedImage == null) {
      return null;
    }

    setState(() {
      _uploadingImage = true;
    });

    try {
      final String fileName =
          'notification_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final Reference reference =
          _storage
              .ref()
              .child('tenants')
              .child(tenantId)
              .child('notifications')
              .child(fileName);

      final UploadTask uploadTask =
          reference.putFile(
        _selectedImage!,
        SettableMetadata(
          contentType: 'image/jpeg',
          customMetadata: {
            'tenantId': tenantId,
            'uploadedBy':
                _auth.currentUser?.uid ?? '',
            'purpose':
                'push_notification',
          },
        ),
      );

      final TaskSnapshot snapshot =
          await uploadTask;

      final String url =
          await snapshot.ref.getDownloadURL();

      if (mounted) {
        setState(() {
          _uploadedImageUrl =
              url;
        });
      }

      return url;
    } catch (e) {
      _showError(
        'Image upload failed.',
        e,
      );

      return null;
    } finally {
      if (mounted) {
        setState(() {
          _uploadingImage = false;
        });
      }
    }
  }

  // ============================================================
  // LOAD CUSTOMERS
  // ============================================================

  Future<void> _loadCustomers() async {
    if (_loadingCustomers) {
      return;
    }

    setState(() {
      _loadingCustomers = true;
    });

    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot =
          await _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('customers')
              .limit(500)
              .get();

      final List<_CustomerItem> result = [];

      for (final doc in snapshot.docs) {
        final Map<String, dynamic> data =
            doc.data();

        if (data['isAdmin'] == true) {
          continue;
        }

        final String firstName =
            _stringValue(
          data['firstName'],
        );

        final String lastName =
            _stringValue(
          data['lastName'],
        );

        final String fullName =
            _stringValue(
                  data['name'],
                ).isNotEmpty
                ? _stringValue(
                    data['name'],
                  )
                : [
                    firstName,
                    lastName,
                  ]
                    .where(
                      (e) => e.trim().isNotEmpty,
                    )
                    .join(' ');

        final String phone =
            _stringValue(
          data['phone'],
        );

        final String email =
            _stringValue(
          data['email'],
        );

        result.add(
          _CustomerItem(
            id: doc.id,
            name: fullName.isEmpty
                ? 'Customer'
                : fullName,
            phone: phone,
            email: email,
          ),
        );
      }

      result.sort(
        (a, b) => a.name
            .toLowerCase()
            .compareTo(
              b.name.toLowerCase(),
            ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _customers = result;
      });
    } catch (e) {
      _showError(
        'Unable to load customers.',
        e,
      );
    } finally {
      if (mounted) {
        setState(() {
          _loadingCustomers = false;
        });
      }
    }
  }

  // ============================================================
  // OPEN CUSTOMER PICKER
  // ============================================================

  Future<void> _openCustomerPicker() async {
    setState(() {
      _showCustomerPicker = true;
      _customerSearch = '';
      _customerSearchController.clear();
    });

    await _loadCustomers();

    if (!mounted) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (
            context,
            modalSetState,
          ) {
            final String search =
                _customerSearch
                    .trim()
                    .toLowerCase();

            final List<_CustomerItem>
                filtered =
                _customers.where(
              (customer) {
                if (search.isEmpty) {
                  return true;
                }

                return customer.name
                        .toLowerCase()
                        .contains(search) ||
                    customer.phone
                        .toLowerCase()
                        .contains(search) ||
                    customer.email
                        .toLowerCase()
                        .contains(search);
              },
            ).toList();

            return Container(
              height:
                  MediaQuery.of(context)
                          .size
                          .height *
                      .82,
              decoration:
                  const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(
                  top: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    Container(
                      width: 42,
                      height: 5,
                      decoration:
                          BoxDecoration(
                        color:
                            border,
                        borderRadius:
                            BorderRadius.circular(
                          20,
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    Padding(
                      padding:
                          const EdgeInsets.symmetric(
                        horizontal: 20,
                      ),
                      child: Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Select Customer',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight:
                                    FontWeight.w800,
                                color:
                                    heading,
                              ),
                            ),
                          ),

                          IconButton(
                            onPressed:
                                () {
                              Navigator.pop(
                                context,
                              );
                            },
                            icon:
                                const Icon(
                              Icons.close_rounded,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        20,
                        4,
                        20,
                        16,
                      ),
                      child:
                          TextField(
                        controller:
                            _customerSearchController,
                        onChanged:
                            (value) {
                          modalSetState(() {
                            _customerSearch =
                                value;
                          });
                        },
                        decoration:
                            InputDecoration(
                          hintText:
                              'Search customer...',
                          prefixIcon:
                              const Icon(
                            Icons.search_rounded,
                          ),
                          filled: true,
                          fillColor:
                              background,
                          border:
                              OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(
                              16,
                            ),
                            borderSide:
                                BorderSide.none,
                          ),
                        ),
                      ),
                    ),

                    Expanded(
                      child:
                          _loadingCustomers
                              ? const Center(
                                  child:
                                      CircularProgressIndicator(),
                                )
                              : filtered.isEmpty
                                  ? _buildEmptyCustomers()
                                  : ListView.separated(
                                      padding:
                                          const EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        24,
                                      ),
                                      itemCount:
                                          filtered.length,
                                      separatorBuilder:
                                          (_, __) =>
                                              const SizedBox(
                                        height: 8,
                                      ),
                                      itemBuilder:
                                          (
                                        context,
                                        index,
                                      ) {
                                        final customer =
                                            filtered[index];

                                        final bool
                                            selected =
                                            customer.id ==
                                                _selectedCustomerId;

                                        return InkWell(
                                          borderRadius:
                                              BorderRadius.circular(
                                            18,
                                          ),
                                          onTap:
                                              () {
                                            setState(() {
                                              _selectedCustomerId =
                                                  customer.id;

                                              _selectedCustomerName =
                                                  customer.name;

                                              _showCustomerPicker =
                                                  false;
                                            });

                                            Navigator.pop(
                                              context,
                                            );
                                          },
                                          child:
                                              Container(
                                            padding:
                                                const EdgeInsets.all(
                                              14,
                                            ),
                                            decoration:
                                                BoxDecoration(
                                              color: selected
                                                  ? softAccent
                                                  : Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(
                                                18,
                                              ),
                                              border:
                                                  Border.all(
                                                color:
                                                    selected
                                                        ? primary
                                                        : border,
                                              ),
                                            ),
                                            child:
                                                Row(
                                              children: [
                                                Container(
                                                  width:
                                                      48,
                                                  height:
                                                      48,
                                                  decoration:
                                                      BoxDecoration(
                                                    color:
                                                        softAccent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      15,
                                                    ),
                                                  ),
                                                  child:
                                                      const Icon(
                                                    Icons.person_rounded,
                                                    color:
                                                        primary,
                                                  ),
                                                ),

                                                const SizedBox(
                                                  width:
                                                      12,
                                                ),

                                                Expanded(
                                                  child:
                                                      Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.start,
                                                    children: [
                                                      Text(
                                                        customer.name,
                                                        maxLines:
                                                            1,
                                                        overflow:
                                                            TextOverflow.ellipsis,
                                                        style:
                                                            const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color:
                                                              heading,
                                                        ),
                                                      ),

                                                      if (customer.phone.isNotEmpty)
                                                        Padding(
                                                          padding:
                                                              const EdgeInsets.only(
                                                            top: 3,
                                                          ),
                                                          child:
                                                              Text(
                                                            customer.phone,
                                                            style:
                                                                const TextStyle(
                                                              color:
                                                                  muted,
                                                              fontSize:
                                                                  12,
                                                            ),
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),

                                                if (selected)
                                                  const Icon(
                                                    Icons
                                                        .check_circle_rounded,
                                                    color:
                                                        success,
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
              ),
            );
          },
        );
      },
    );

    if (mounted) {
      setState(() {
        _showCustomerPicker = false;
      });
    }
  }

  Widget _buildEmptyCustomers() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration:
                  BoxDecoration(
                color: softAccent,
                borderRadius:
                    BorderRadius.circular(
                  24,
                ),
              ),
              child: const Icon(
                Icons.people_outline_rounded,
                size: 34,
                color: muted,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No customers found',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: heading,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Try a different name, phone number or email.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: muted,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SEND NOTIFICATION
  // ============================================================

  Future<void> _sendNotification() async {
    FocusScope.of(context).unfocus();

    final String title =
        _titleController.text.trim();

    final String message =
        _messageController.text.trim();

    if (title.isEmpty) {
      _showError(
        'Please enter a notification title.',
      );
      return;
    }

    if (message.isEmpty) {
      _showError(
        'Please enter a notification message.',
      );
      return;
    }

    if (_targetType ==
            'specific_customer' &&
        (_selectedCustomerId == null ||
            _selectedCustomerId!.isEmpty)) {
      _showError(
        'Please select a customer.',
      );
      return;
    }

    if (tenantId.trim().isEmpty) {
      _showError(
        'Tenant information is not available.',
      );
      return;
    }

    final User? currentUser =
        _auth.currentUser;

    if (currentUser == null) {
      _showError(
        'Your admin session has expired. Please login again.',
      );
      return;
    }

    setState(() {
      _sending = true;
    });

    try {
      String? imageUrl =
          _uploadedImageUrl;

      if (_selectedImage != null &&
          imageUrl == null) {
        imageUrl =
            await _uploadNotificationImage();

        if (imageUrl == null) {
          if (mounted) {
            setState(() {
              _sending = false;
            });
          }

          return;
        }
      }

      final HttpsCallable callable =
          _functions.httpsCallable(
        'sendManualCustomerNotification',
      );

      final Map<String, dynamic>
          payload = {
        'tenantId': tenantId,
        'title': title,
        'body': message,
        'imageUrl':
            imageUrl ?? '',
        'type':
            _notificationType,
        'action':
            _action,
        'targetType':
            _targetType,
        'customerId':
            _targetType ==
                    'specific_customer'
                ? _selectedCustomerId
                : '',
        'bookingId':
            _bookingIdController.text
                .trim(),
        'carId':
            _carIdController.text
                .trim(),
        'offerId':
            _offerIdController.text
                .trim(),
      };

      final HttpsCallableResult
          result =
          await callable.call(
        payload,
      );

      final dynamic data =
          result.data;

      int recipientCount = 0;
      int successCount = 0;
      int failureCount = 0;

      if (data is Map) {
        recipientCount =
            _toInt(
          data['recipientCount'],
        );

        successCount =
            _toInt(
          data['successCount'],
        );

        failureCount =
            _toInt(
          data['failureCount'],
        );
      }

      if (!mounted) {
        return;
      }

      await _showSuccessDialog(
        recipientCount:
            recipientCount,
        successCount:
            successCount,
        failureCount:
            failureCount,
      );

      _clearForm();
    } on FirebaseFunctionsException catch (e) {
      _showError(
        e.message ??
            'Unable to send notification.',
      );
    } catch (e) {
      _showError(
        'Unable to send notification.',
        e,
      );
    } finally {
      if (mounted) {
        setState(() {
          _sending = false;
        });
      }
    }
  }

  // ============================================================
  // SUCCESS DIALOG
  // ============================================================

  Future<void> _showSuccessDialog({
    required int recipientCount,
    required int successCount,
    required int failureCount,
  }) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          backgroundColor:
              Colors.white,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(28),
          ),
          child: Padding(
            padding:
                const EdgeInsets.all(26),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration:
                      BoxDecoration(
                    color: success.withOpacity(
                      .10,
                    ),
                    shape:
                        BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons
                        .notifications_active_rounded,
                    size: 34,
                    color: success,
                  ),
                ),

                const SizedBox(height: 18),

                const Text(
                  'Notification Sent',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight:
                        FontWeight.w900,
                    color: heading,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Your customer notification has been processed.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color: bodyText,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 22),

                Row(
                  children: [
                    Expanded(
                      child:
                          _ResultCard(
                        label:
                            'Recipients',
                        value:
                            '$recipientCount',
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child:
                          _ResultCard(
                        label:
                            'Delivered',
                        value:
                            '$successCount',
                      ),
                    ),
                    const SizedBox(
                      width: 10,
                    ),
                    Expanded(
                      child:
                          _ResultCard(
                        label:
                            'Failed',
                        value:
                            '$failureCount',
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width:
                      double.infinity,
                  child:
                      ElevatedButton(
                    onPressed: () {
                      Navigator.pop(
                        context,
                      );
                    },
                    style:
                        ElevatedButton.styleFrom(
                      backgroundColor:
                          primary,
                      foregroundColor:
                          Colors.white,
                      minimumSize:
                          const Size(
                        double.infinity,
                        54,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                      elevation: 0,
                    ),
                    child:
                        const Text(
                      'Done',
                      style:
                          TextStyle(
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // CLEAR FORM
  // ============================================================

  void _clearForm() {
    _titleController.clear();
    _messageController.clear();

    _bookingIdController.clear();
    _carIdController.clear();
    _offerIdController.clear();

    setState(() {
      _selectedImage = null;
      _uploadedImageUrl = null;

      _notificationType =
          'general';

      _action =
          'home';

      _targetType =
          'all_customers';

      _selectedCustomerId =
          null;

      _selectedCustomerName =
          null;

      _showAdvanced =
          false;
    });
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _stringValue(
    dynamic value,
  ) {
    if (value == null) {
      return '';
    }

    return value
        .toString()
        .trim();
  }

  int _toInt(
    dynamic value,
  ) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value?.toString() ?? '',
        ) ??
        0;
  }

  void _showError(
    String message, [
    dynamic error,
  ]) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      SnackBar(
        behavior:
            SnackBarBehavior.floating,
        backgroundColor:
            Colors.white,
        elevation: 8,
        margin:
            const EdgeInsets.all(16),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(16),
        ),
        content:
            Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration:
                  BoxDecoration(
                color:
                    danger.withOpacity(.10),
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child:
                  const Icon(
                Icons.error_outline_rounded,
                color:
                    danger,
              ),
            ),

            const SizedBox(
              width: 12,
            ),

            Expanded(
              child:
                  Text(
                message,
                style:
                    const TextStyle(
                  color:
                      heading,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    debugPrint(
      'Push notification error: $error',
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          background,

      appBar:
          AppBar(
        backgroundColor:
            Colors.white,
        elevation: 0,
        surfaceTintColor:
            Colors.white,
        leading:
            IconButton(
          onPressed: () {
            Navigator.pop(
              context,
            );
          },
          icon:
              const Icon(
            Icons.arrow_back_rounded,
            color:
                heading,
          ),
        ),
        title:
            const Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              'Push Notifications',
              style: TextStyle(
                color:
                    heading,
                fontSize:
                    18,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Reach your customers instantly',
              style: TextStyle(
                color:
                    muted,
                fontSize:
                    11,
                fontWeight:
                    FontWeight.w500,
              ),
            ),
          ],
        ),
      ),

      body:
          SafeArea(
        child:
            LayoutBuilder(
          builder:
              (
            context,
            constraints,
          ) {
            final bool wide =
                constraints.maxWidth >=
                    900;

            return SingleChildScrollView(
              padding:
                  EdgeInsets.fromLTRB(
                wide ? 32 : 16,
                18,
                wide ? 32 : 16,
                40,
              ),
              child:
                  wide
                      ? Row(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex:
                                  6,
                              child:
                                  _buildComposer(),
                            ),
                            const SizedBox(
                              width:
                                  24,
                            ),
                            Expanded(
                              flex:
                                  4,
                              child:
                                  _buildPreviewPanel(),
                            ),
                          ],
                        )
                      : Column(
                          children: [
                            _buildPreviewPanel(),
                            const SizedBox(
                              height:
                                  18,
                            ),
                            _buildComposer(),
                          ],
                        ),
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // COMPOSER
  // ============================================================

  Widget _buildComposer() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildPageIntro(),

        const SizedBox(
          height: 18,
        ),

        _buildSectionCard(
          title:
              'Notification Content',
          icon:
              Icons.edit_note_rounded,
          child:
              Column(
            children: [
              _buildTextField(
                controller:
                    _titleController,
                label:
                    'Notification title',
                hint:
                    'Example: Your booking is confirmed 🚗',
                maxLength:
                    150,
              ),

              const SizedBox(
                height:
                    16,
              ),

              _buildTextField(
                controller:
                    _messageController,
                label:
                    'Message',
                hint:
                    'Write the message your customers should receive...',
                maxLines:
                    5,
                maxLength:
                    1000,
              ),
            ],
          ),
        ),

        const SizedBox(
          height:
              16,
        ),

        _buildSectionCard(
          title:
              'Notification Image',
          icon:
              Icons.image_outlined,
          child:
              _buildImagePicker(),
        ),

        const SizedBox(
          height:
              16,
        ),

        _buildSectionCard(
          title:
              'Notification Settings',
          icon:
              Icons.tune_rounded,
          child:
              Column(
            children: [
              _buildDropdownField(
                label:
                    'Notification type',
                value:
                    _notificationType,
                items:
                    const [
                  DropdownMenuItem(
                    value:
                        'general',
                    child:
                        Text(
                      'General',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'booking',
                    child:
                        Text(
                      'Booking',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'payment',
                    child:
                        Text(
                      'Payment',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'refund',
                    child:
                        Text(
                      'Refund',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'offer',
                    child:
                        Text(
                      'Offer / Promotion',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'reminder',
                    child:
                        Text(
                      'Reminder',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'system',
                    child:
                        Text(
                      'System',
                    ),
                  ),
                ],
                onChanged:
                    (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _notificationType =
                        value;
                  });
                },
              ),

              const SizedBox(
                height:
                    16,
              ),

              _buildDropdownField(
                label:
                    'Open when customer taps',
                value:
                    _action,
                items:
                    const [
                  DropdownMenuItem(
                    value:
                        'home',
                    child:
                        Text(
                      'Home',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'bookings',
                    child:
                        Text(
                      'My Bookings',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'booking_details',
                    child:
                        Text(
                      'Booking Details',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'payments',
                    child:
                        Text(
                      'Payments',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'transactions',
                    child:
                        Text(
                      'Transactions',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'cars',
                    child:
                        Text(
                      'Cars',
                    ),
                  ),
                  DropdownMenuItem(
                    value:
                        'offers',
                    child:
                        Text(
                      'Offers',
                    ),
                  ),
                ],
                onChanged:
                    (value) {
                  if (value == null) {
                    return;
                  }

                  setState(() {
                    _action =
                        value;
                  });
                },
              ),
            ],
          ),
        ),

        const SizedBox(
          height:
              16,
        ),

        _buildSectionCard(
          title:
              'Audience',
          icon:
              Icons.people_alt_outlined,
          child:
              Column(
            children: [
              _buildAudienceSelector(),

              if (_targetType ==
                  'specific_customer')
                Padding(
                  padding:
                      const EdgeInsets.only(
                    top:
                        14,
                  ),
                  child:
                      _buildSelectedCustomer(),
                ),
            ],
          ),
        ),

        const SizedBox(
          height:
              16,
        ),

        _buildAdvancedSection(),

        const SizedBox(
          height:
              20,
        ),

        _buildSendButton(),
      ],
    );
  }

  // ============================================================
  // PAGE INTRO
  // ============================================================

  Widget _buildPageIntro() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(22),
      decoration:
          BoxDecoration(
        color:
            primary,
        borderRadius:
            BorderRadius.circular(
          24,
        ),
      ),
      child:
          Row(
        children: [
          Container(
            width:
                54,
            height:
                54,
            decoration:
                BoxDecoration(
              color:
                  Colors.white.withOpacity(
                .12,
              ),
              borderRadius:
                  BorderRadius.circular(
                17,
              ),
            ),
            child:
                const Icon(
              Icons.notifications_active_rounded,
              color:
                  Colors.white,
              size:
                  28,
            ),
          ),

          const SizedBox(
            width:
                15,
          ),

          const Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Create customer notification',
                  style:
                      TextStyle(
                    color:
                        Colors.white,
                    fontSize:
                        18,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                SizedBox(
                  height:
                      5,
                ),
                Text(
                  'Send a custom push notification to customers of this tenant.',
                  style:
                      TextStyle(
                    color:
                        Colors.white70,
                    fontSize:
                        12,
                    height:
                        1.4,
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
  // IMAGE PICKER
  // ============================================================

  Widget _buildImagePicker() {
    if (_selectedImage != null) {
      return Column(
        children: [
          ClipRRect(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
            child:
                Image.file(
              _selectedImage!,
              width:
                  double.infinity,
              height:
                  190,
              fit:
                  BoxFit.cover,
            ),
          ),

          const SizedBox(
            height:
                12,
          ),

          Row(
            children: [
              Expanded(
                child:
                    OutlinedButton.icon(
                  onPressed:
                      _pickImage,
                  icon:
                      const Icon(
                    Icons.swap_horiz_rounded,
                  ),
                  label:
                      const Text(
                    'Change image',
                  ),
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        primary,
                    side:
                        const BorderSide(
                      color:
                          border,
                    ),
                    minimumSize:
                        const Size(
                      0,
                      48,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width:
                    10,
              ),

              IconButton(
                onPressed:
                    _removeImage,
                style:
                    IconButton.styleFrom(
                  backgroundColor:
                      danger.withOpacity(
                    .08,
                  ),
                ),
                icon:
                    const Icon(
                  Icons.delete_outline_rounded,
                  color:
                      danger,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return InkWell(
      onTap:
          _pickImage,
      borderRadius:
          BorderRadius.circular(
        20,
      ),
      child:
          Container(
        width:
            double.infinity,
        padding:
            const EdgeInsets.symmetric(
          vertical:
              30,
          horizontal:
              20,
        ),
        decoration:
            BoxDecoration(
          color:
              background,
          borderRadius:
              BorderRadius.circular(
            20,
          ),
          border:
              Border.all(
            color:
                border,
          ),
        ),
        child:
            Column(
          children: [
            Container(
              width:
                  58,
              height:
                  58,
              decoration:
                  BoxDecoration(
                color:
                    Colors.white,
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
              child:
                  const Icon(
                Icons.add_photo_alternate_outlined,
                color:
                    primary,
                size:
                    28,
              ),
            ),

            const SizedBox(
              height:
                  12,
            ),

            const Text(
              'Add notification image',
              style:
                  TextStyle(
                fontWeight:
                    FontWeight.w800,
                color:
                    heading,
              ),
            ),

            const SizedBox(
              height:
                  5,
            ),

            const Text(
              'Optional • JPG / PNG',
              style:
                  TextStyle(
                color:
                    muted,
                fontSize:
                    12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // AUDIENCE
  // ============================================================

  Widget _buildAudienceSelector() {
    return Column(
      children: [
        _AudienceOption(
          selected:
              _targetType ==
                  'all_customers',
          icon:
              Icons.groups_rounded,
          title:
              'All customers',
          subtitle:
              'Send to active customer devices belonging to this tenant.',
          onTap:
              () {
            setState(() {
              _targetType =
                  'all_customers';

              _selectedCustomerId =
                  null;

              _selectedCustomerName =
                  null;
            });
          },
        ),

        const SizedBox(
          height:
              10,
        ),

        _AudienceOption(
          selected:
              _targetType ==
                  'specific_customer',
          icon:
              Icons.person_search_rounded,
          title:
              'Specific customer',
          subtitle:
              'Choose one customer from this tenant.',
          onTap:
              () async {
            setState(() {
              _targetType =
                  'specific_customer';
            });

            await _openCustomerPicker();
          },
        ),
      ],
    );
  }

  Widget _buildSelectedCustomer() {
    if (_selectedCustomerId ==
        null) {
      return Container(
        padding:
            const EdgeInsets.all(
          15,
        ),
        decoration:
            BoxDecoration(
          color:
              background,
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          border:
              Border.all(
            color:
                border,
          ),
        ),
        child:
            Row(
          children: [
            const Icon(
              Icons.person_outline_rounded,
              color:
                  muted,
            ),
            const SizedBox(
              width:
                  10,
            ),
            const Expanded(
              child:
                  Text(
                'No customer selected',
                style:
                    TextStyle(
                  color:
                      muted,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed:
                  _openCustomerPicker,
              child:
                  const Text(
                'Select',
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration:
          BoxDecoration(
        color:
            success.withOpacity(
          .06,
        ),
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        border:
            Border.all(
          color:
              success.withOpacity(
            .18,
          ),
        ),
      ),
      child:
          Row(
        children: [
          Container(
            width:
                44,
            height:
                44,
            decoration:
                BoxDecoration(
              color:
                  Colors.white,
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),
            child:
                const Icon(
              Icons.person_rounded,
              color:
                  primary,
            ),
          ),

          const SizedBox(
            width:
                11,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCustomerName ??
                      'Customer',
                  style:
                      const TextStyle(
                    fontWeight:
                        FontWeight.w800,
                    color:
                        heading,
                  ),
                ),
                const SizedBox(
                  height:
                      3,
                ),
                Text(
                  'Customer ID: $_selectedCustomerId',
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        muted,
                    fontSize:
                        11,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            onPressed:
                _openCustomerPicker,
            icon:
                const Icon(
              Icons.edit_outlined,
              size:
                  20,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ADVANCED
  // ============================================================

  Widget _buildAdvancedSection() {
    return Container(
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border:
            Border.all(
          color:
              border,
        ),
      ),
      child:
          Column(
        children: [
          InkWell(
            borderRadius:
                BorderRadius.circular(
              22,
            ),
            onTap:
                () {
              setState(() {
                _showAdvanced =
                    !_showAdvanced;
              });
            },
            child:
                Padding(
              padding:
                  const EdgeInsets.all(
                18,
              ),
              child:
                  Row(
                children: [
                  Container(
                    width:
                        42,
                    height:
                        42,
                    decoration:
                        BoxDecoration(
                      color:
                          softAccent,
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons.data_object_rounded,
                      color:
                          primary,
                    ),
                  ),

                  const SizedBox(
                    width:
                        12,
                  ),

                  const Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Advanced data',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.w800,
                            color:
                                heading,
                          ),
                        ),
                        SizedBox(
                          height:
                              3,
                        ),
                        Text(
                          'Optional booking, car and offer references',
                          style:
                              TextStyle(
                            color:
                                muted,
                            fontSize:
                                12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  Icon(
                    _showAdvanced
                        ? Icons
                            .keyboard_arrow_up_rounded
                        : Icons
                            .keyboard_arrow_down_rounded,
                    color:
                        muted,
                  ),
                ],
              ),
            ),
          ),

          if (_showAdvanced)
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                0,
                18,
                18,
              ),
              child:
                  Column(
                children: [
                  const Divider(
                    color:
                        border,
                  ),

                  const SizedBox(
                    height:
                        16,
                  ),

                  _buildTextField(
                    controller:
                        _bookingIdController,
                    label:
                        'Booking ID',
                    hint:
                        'Optional',
                  ),

                  const SizedBox(
                    height:
                        14,
                  ),

                  _buildTextField(
                    controller:
                        _carIdController,
                    label:
                        'Car ID',
                    hint:
                        'Optional',
                  ),

                  const SizedBox(
                    height:
                        14,
                  ),

                  _buildTextField(
                    controller:
                        _offerIdController,
                    label:
                        'Offer ID',
                    hint:
                        'Optional',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // SEND BUTTON
  // ============================================================

  Widget _buildSendButton() {
    return SizedBox(
      width:
          double.infinity,
      child:
          ElevatedButton(
        onPressed:
            _sending
                ? null
                : _sendNotification,
        style:
            ElevatedButton.styleFrom(
          backgroundColor:
              primary,
          disabledBackgroundColor:
              muted,
          foregroundColor:
              Colors.white,
          minimumSize:
              const Size(
            double.infinity,
            58,
          ),
          elevation:
              0,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              18,
            ),
          ),
        ),
        child:
            _sending
                ? const SizedBox(
                    width:
                        24,
                    height:
                        24,
                    child:
                        CircularProgressIndicator(
                      strokeWidth:
                          2.5,
                      valueColor:
                          AlwaysStoppedAnimation<
                              Color>(
                        Colors.white,
                      ),
                    ),
                  )
                : const Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons
                            .send_rounded,
                        size:
                            20,
                      ),
                      SizedBox(
                        width:
                            10,
                      ),
                      Text(
                        'Send Notification',
                        style:
                            TextStyle(
                          fontSize:
                              15,
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  // ============================================================
  // PREVIEW
  // ============================================================

  Widget _buildPreviewPanel() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Padding(
          padding:
              EdgeInsets.only(
            left:
                4,
            bottom:
                10,
          ),
          child:
              Text(
            'Live Preview',
            style:
                TextStyle(
              fontSize:
                  17,
              fontWeight:
                  FontWeight.w900,
              color:
                  heading,
            ),
          ),
        ),

        Container(
          width:
              double.infinity,
          padding:
              const EdgeInsets.all(
            18,
          ),
          decoration:
              BoxDecoration(
            color:
                Colors.white,
            borderRadius:
                BorderRadius.circular(
              26,
            ),
            border:
                Border.all(
              color:
                  border,
            ),
          ),
          child:
              Column(
            children: [
              Row(
                children: [
                  Container(
                    width:
                        42,
                    height:
                        42,
                    decoration:
                        BoxDecoration(
                      color:
                          primary,
                      borderRadius:
                          BorderRadius.circular(
                        13,
                      ),
                    ),
                    child:
                        const Icon(
                      Icons
                          .directions_car_filled_rounded,
                      color:
                          Colors.white,
                      size:
                          22,
                    ),
                  ),

                  const SizedBox(
                    width:
                        10,
                  ),

                  const Expanded(
                    child:
                        Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Rentocar',
                          style:
                              TextStyle(
                            fontWeight:
                                FontWeight.w800,
                            color:
                                heading,
                          ),
                        ),
                        SizedBox(
                          height:
                              2,
                        ),
                        Text(
                          'Now',
                          style:
                              TextStyle(
                            fontSize:
                                11,
                            color:
                                muted,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Icon(
                    Icons
                        .more_horiz_rounded,
                    color:
                        muted,
                  ),
                ],
              ),

              const SizedBox(
                height:
                    15,
              ),

              if (_selectedImage != null)
                ClipRRect(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                  child:
                      Image.file(
                    _selectedImage!,
                    width:
                        double.infinity,
                    height:
                        170,
                    fit:
                        BoxFit.cover,
                  ),
                ),

              if (_selectedImage != null)
                const SizedBox(
                  height:
                      14,
                ),

              Align(
                alignment:
                    Alignment.centerLeft,
                child:
                    Text(
                  _titleController
                          .text
                          .trim()
                          .isEmpty
                      ? 'Your notification title'
                      : _titleController
                          .text
                          .trim(),
                  maxLines:
                      2,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize:
                        16,
                    fontWeight:
                        FontWeight.w900,
                    color:
                        heading,
                  ),
                ),
              ),

              const SizedBox(
                height:
                    6,
              ),

              Align(
                alignment:
                    Alignment.centerLeft,
                child:
                    Text(
                  _messageController
                          .text
                          .trim()
                          .isEmpty
                      ? 'Your notification message will appear here.'
                      : _messageController
                          .text
                          .trim(),
                  maxLines:
                      5,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize:
                        13,
                    color:
                        bodyText,
                    height:
                        1.45,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          height:
              14,
        ),

        _buildPreviewInfo(
          Icons.people_alt_outlined,
          _targetType ==
                  'all_customers'
              ? 'All customers'
              : _selectedCustomerName ??
                  'Specific customer',
        ),

        const SizedBox(
          height:
              8,
        ),

        _buildPreviewInfo(
          Icons
              .open_in_new_rounded,
          _actionLabel(
            _action,
          ),
        ),

        const SizedBox(
          height:
              8,
        ),

        _buildPreviewInfo(
          Icons.category_outlined,
          _notificationTypeLabel(
            _notificationType,
          ),
        ),
      ],
    );
  }

  Widget _buildPreviewInfo(
    IconData icon,
    String text,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            14,
        vertical:
            12,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        border:
            Border.all(
          color:
              border,
        ),
      ),
      child:
          Row(
        children: [
          Icon(
            icon,
            size:
                18,
            color:
                muted,
          ),
          const SizedBox(
            width:
                10,
          ),
          Expanded(
            child:
                Text(
              text,
              style:
                  const TextStyle(
                fontSize:
                    12,
                fontWeight:
                    FontWeight.w700,
                color:
                    bodyText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION CARD
  // ============================================================

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        18,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border:
            Border.all(
          color:
              border,
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width:
                    40,
                height:
                    40,
                decoration:
                    BoxDecoration(
                  color:
                      softAccent,
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child:
                    Icon(
                  icon,
                  color:
                      primary,
                  size:
                      21,
                ),
              ),

              const SizedBox(
                width:
                    11,
              ),

              Text(
                title,
                style:
                    const TextStyle(
                  fontSize:
                      15,
                  fontWeight:
                      FontWeight.w900,
                  color:
                      heading,
                ),
              ),
            ],
          ),

          const SizedBox(
            height:
                18,
          ),

          child,
        ],
      ),
    );
  }

  // ============================================================
  // TEXT FIELD
  // ============================================================

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              const TextStyle(
            fontSize:
                12,
            fontWeight:
                FontWeight.w800,
            color:
                heading,
          ),
        ),

        const SizedBox(
          height:
              8,
        ),

        TextField(
          controller:
              controller,
          maxLines:
              maxLines,
          maxLength:
              maxLength,
          textCapitalization:
              TextCapitalization.sentences,
          decoration:
              InputDecoration(
            hintText:
                hint,
            hintStyle:
                const TextStyle(
              color:
                  muted,
              fontSize:
                  13,
            ),
            counterText:
                '',
            filled:
                true,
            fillColor:
                background,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal:
                  15,
              vertical:
                  14,
            ),
            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              borderSide:
                  BorderSide.none,
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              borderSide:
                  const BorderSide(
                color:
                    border,
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              borderSide:
                  const BorderSide(
                color:
                    primary,
                width:
                    1.2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // DROPDOWN
  // ============================================================

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<DropdownMenuItem<String>>
        items,
    required ValueChanged<String?>
        onChanged,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style:
              const TextStyle(
            fontSize:
                12,
            fontWeight:
                FontWeight.w800,
            color:
                heading,
          ),
        ),

        const SizedBox(
          height:
              8,
        ),

        DropdownButtonFormField<
            String>(
          initialValue:
              value,
          items:
              items,
          onChanged:
              onChanged,
          icon:
              const Icon(
            Icons
                .keyboard_arrow_down_rounded,
          ),
          decoration:
              InputDecoration(
            filled:
                true,
            fillColor:
                background,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal:
                  15,
              vertical:
                  4,
            ),
            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              borderSide:
                  BorderSide.none,
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                16,
              ),
              borderSide:
                  const BorderSide(
                color:
                    border,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // LABEL HELPERS
  // ============================================================

  String _actionLabel(
    String action,
  ) {
    switch (action) {
      case 'bookings':
        return 'My Bookings';

      case 'booking_details':
        return 'Booking Details';

      case 'payments':
        return 'Payments';

      case 'transactions':
        return 'Transactions';

      case 'cars':
        return 'Cars';

      case 'offers':
        return 'Offers';

      default:
        return 'Home';
    }
  }

  String _notificationTypeLabel(
    String type,
  ) {
    switch (type) {
      case 'booking':
        return 'Booking';

      case 'payment':
        return 'Payment';

      case 'refund':
        return 'Refund';

      case 'offer':
        return 'Offer / Promotion';

      case 'reminder':
        return 'Reminder';

      case 'system':
        return 'System';

      default:
        return 'General';
    }
  }
}

// ============================================================
// CUSTOMER MODEL
// ============================================================

class _CustomerItem {
  final String id;
  final String name;
  final String phone;
  final String email;

  const _CustomerItem({
    required this.id,
    required this.name,
    required this.phone,
    required this.email,
  });
}

// ============================================================
// AUDIENCE OPTION
// ============================================================

class _AudienceOption
    extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AudienceOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return InkWell(
      onTap:
          onTap,
      borderRadius:
          BorderRadius.circular(
        18,
      ),
      child:
          AnimatedContainer(
        duration:
            const Duration(
          milliseconds:
              180,
        ),
        padding:
            const EdgeInsets.all(
          15,
        ),
        decoration:
            BoxDecoration(
          color:
              selected
                  ? const Color(
                      0xFFF3F4F6,
                    )
                  : Colors.white,
          borderRadius:
              BorderRadius.circular(
            18,
          ),
          border:
              Border.all(
            color:
                selected
                    ? const Color(
                        0xFF111827,
                      )
                    : const Color(
                        0xFFE5E7EB,
                      ),
            width:
                selected
                    ? 1.2
                    : 1,
          ),
        ),
        child:
            Row(
          children: [
            Container(
              width:
                  46,
              height:
                  46,
              decoration:
                  BoxDecoration(
                color:
                    selected
                        ? const Color(
                            0xFF111827,
                          )
                        : const Color(
                            0xFFF3F4F6,
                          ),
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
              ),
              child:
                  Icon(
                icon,
                color:
                    selected
                        ? Colors.white
                        : const Color(
                            0xFF111827,
                          ),
              ),
            ),

            const SizedBox(
              width:
                  12,
            ),

            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style:
                        const TextStyle(
                      fontWeight:
                          FontWeight.w800,
                      color:
                          Color(
                        0xFF111827,
                      ),
                    ),
                  ),
                  const SizedBox(
                    height:
                        4,
                  ),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFF9CA3AF,
                      ),
                      fontSize:
                          11,
                      height:
                          1.35,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(
              width:
                  10,
            ),

            AnimatedContainer(
              duration:
                  const Duration(
                milliseconds:
                    180,
              ),
              width:
                  23,
              height:
                  23,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                border:
                    Border.all(
                  color:
                      selected
                          ? const Color(
                              0xFF111827,
                            )
                          : const Color(
                              0xFFD1D5DB,
                            ),
                  width:
                      2,
                ),
              ),
              child:
                  selected
                      ? Container(
                          margin:
                              const EdgeInsets.all(
                            4,
                          ),
                          decoration:
                              const BoxDecoration(
                            color:
                                Color(
                              0xFF111827,
                            ),
                            shape:
                                BoxShape.circle,
                          ),
                        )
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// RESULT CARD
// ============================================================

class _ResultCard
    extends StatelessWidget {
  final String label;
  final String value;

  const _ResultCard({
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical:
            12,
        horizontal:
            7,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFF8FAFC,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFE5E7EB,
          ),
        ),
      ),
      child:
          Column(
        children: [
          Text(
            value,
            style:
                const TextStyle(
              fontSize:
                  17,
              fontWeight:
                  FontWeight.w900,
              color:
                  Color(
                0xFF111827,
              ),
            ),
          ),
          const SizedBox(
            height:
                3,
          ),
          Text(
            label,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              fontSize:
                  10,
              color:
                  Color(
                0xFF9CA3AF,
              ),
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}