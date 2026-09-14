import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/customer_document.dart';
import '../services/document_service.dart';

class KycScreen extends StatefulWidget {
  const KycScreen({
    super.key,
    this.tenantId = 'tenant_001',
  });

  final String tenantId;

  @override
  State<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends State<KycScreen> {
  final DocumentService _documentService = DocumentService();
  final ImagePicker _picker = ImagePicker();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final TextEditingController _licenseNumberController =
      TextEditingController();
  final TextEditingController _governmentIdController =
      TextEditingController();

  final Map<CustomerDocumentType, CustomerDocument?> _documents = {
    CustomerDocumentType.drivingLicense: null,
    CustomerDocumentType.governmentId: null,
  };

  final Map<CustomerDocumentType, File?> _frontFiles = {
    CustomerDocumentType.drivingLicense: null,
    CustomerDocumentType.governmentId: null,
  };

  final Map<CustomerDocumentType, File?> _backFiles = {
    CustomerDocumentType.drivingLicense: null,
    CustomerDocumentType.governmentId: null,
  };

  CustomerDocumentType _selectedType =
      CustomerDocumentType.drivingLicense;

  bool _loading = true;
  bool _saving = false;

  static const Color background = Color(0xFFF8FAF9);
  static const Color card = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF0F766E);
  static const Color accent = Color(0xFF14B8A6);
  static const Color softAccent = Color(0xFFE6FFFB);
  static const Color heading = Color(0xFF17201F);
  static const Color body = Color(0xFF66706E);
  static const Color muted = Color(0xFF94A09D);
  static const Color border = Color(0xFFE5EBE9);

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  @override
  void dispose() {
    _licenseNumberController.dispose();
    _governmentIdController.dispose();
    super.dispose();
  }

  Future<void> _loadDocuments() async {
    try {
      final user = _documentService;
      final authUser = await _getCurrentUserId();

      if (authUser == null) {
        throw Exception('Please login again.');
      }

      final documents = await user.getDocuments(
        tenantId: widget.tenantId,
        customerId: authUser,
      );

      for (final document in documents) {
        _documents[document.type] = document;

        if (document.type ==
            CustomerDocumentType.drivingLicense) {
          _licenseNumberController.text =
              document.documentNumber;
        } else {
          _governmentIdController.text =
              document.documentNumber;
        }
      }

      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _loading = false;
      });

      _showMessage(
        _friendlyError(e),
        error: true,
      );
    }
  }

  Future<String?> _getCurrentUserId() async {
    return _auth.currentUser?.uid;
  }

  Future<void> _pickImage(
    CustomerDocumentType type,
    bool front,
  ) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(24),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Add ${front ? 'front' : 'back'} side',
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 14),
                _sourceTile(
                  icon: Icons.camera_alt_rounded,
                  title: 'Take photo',
                  subtitle: 'Use your camera',
                  source: ImageSource.camera,
                ),
                const SizedBox(height: 10),
                _sourceTile(
                  icon: Icons.photo_library_rounded,
                  title: 'Choose from gallery',
                  subtitle: 'Select an existing image',
                  source: ImageSource.gallery,
                ),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    try {
      final image = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (image == null) return;

      setState(() {
        if (front) {
          _frontFiles[type] = File(image.path);
        } else {
          _backFiles[type] = File(image.path);
        }
      });
    } catch (e) {
      _showMessage(
        'Unable to select image. Please try again.',
        error: true,
      );
    }
  }

  Widget _sourceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required ImageSource source,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, source),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: softAccent,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(
                icon,
                color: primary,
                size: 21,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: heading,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: muted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: muted,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    final front = _frontFiles[_selectedType];
    final back = _backFiles[_selectedType];

    final document = _documents[_selectedType];

    final numberController =
        _selectedType == CustomerDocumentType.drivingLicense
            ? _licenseNumberController
            : _governmentIdController;

    final number = numberController.text.trim();

    if (number.isEmpty) {
      _showMessage(
        'Enter your ${_selectedType == CustomerDocumentType.drivingLicense ? 'driving license' : 'government ID'} number.',
        error: true,
      );
      return;
    }

    if (front == null && document?.hasFront != true) {
      _showMessage(
        'Please add the front side of the document.',
        error: true,
      );
      return;
    }

    if (back == null && document?.hasBack != true) {
      _showMessage(
        'Please add the back side of the document.',
        error: true,
      );
      return;
    }

    if (front == null || back == null) {
      _showMessage(
        'For a replacement upload, please select both front and back images.',
        error: true,
      );
      return;
    }

    try {
      setState(() {
        _saving = true;
      });

      final uid = _auth.currentUser?.uid;

      if (uid == null || uid.isEmpty) {
        throw Exception('Please login again.');
      }

      final saved = await _documentService.saveDocument(
        tenantId: widget.tenantId,
        customerId: uid,
        type: _selectedType,
        documentNumber: number,
        frontFile: front,
        backFile: back,
      );

      if (!mounted) return;

      setState(() {
        _documents[_selectedType] = saved;
        _frontFiles[_selectedType] = null;
        _backFiles[_selectedType] = null;
        _saving = false;
      });

      _showMessage(
        'Documents uploaded successfully. Verification is now pending.',
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _saving = false;
      });

      _showMessage(
        _friendlyError(e),
        error: true,
      );
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString().replaceFirst('Exception: ', '');
    return message.isEmpty
        ? 'Something went wrong. Please try again.'
        : message;
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? heading : primary,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: background,
      appBar: AppBar(
        backgroundColor: background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: heading,
          ),
        ),
        title: Text(
          'Verification',
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: heading,
          ),
        ),
        centerTitle: false,
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                color: primary,
                strokeWidth: 2.5,
              ),
            )
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final selectedDocument = _documents[_selectedType];

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIntro(),
          const SizedBox(height: 22),
          _buildDocumentSelector(),
          const SizedBox(height: 18),
          _buildStatusCard(selectedDocument),
          const SizedBox(height: 20),
          _buildNumberField(),
          const SizedBox(height: 18),
          _buildUploadSection(),
          const SizedBox(height: 22),
          _buildSaveButton(),
          const SizedBox(height: 18),
          _buildSecurityNote(),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: softAccent,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: accent.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(15),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Complete your verification',
                  style: GoogleFonts.manrope(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your documents are reviewed before vehicle pickup.',
                  style: GoogleFonts.manrope(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: body,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentSelector() {
    return Row(
      children: [
        Expanded(
          child: _documentTypeButton(
            type: CustomerDocumentType.drivingLicense,
            title: 'Driving License',
            icon: Icons.badge_outlined,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _documentTypeButton(
            type: CustomerDocumentType.governmentId,
            title: 'Government ID',
            icon: Icons.credit_card_outlined,
          ),
        ),
      ],
    );
  }

  Widget _documentTypeButton({
    required CustomerDocumentType type,
    required String title,
    required IconData icon,
  }) {
    final selected = _selectedType == type;

    return InkWell(
      onTap: () {
        setState(() {
          _selectedType = type;
        });
      },
      borderRadius: BorderRadius.circular(17),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? softAccent : card,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(
            color: selected ? primary : border,
            width: selected ? 1.3 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 21,
              color: selected ? primary : muted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 2,
                style: GoogleFonts.manrope(
                  fontSize: 10.5,
                  fontWeight: selected
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: selected ? heading : body,
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(CustomerDocument? document) {
    final status =
        document?.status ?? CustomerDocumentStatus.notUploaded;

    final config = _statusConfig(status);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: config.background,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(
              config.icon,
              color: config.foreground,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  config.title,
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: heading,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  document?.rejectionReason.isNotEmpty == true
                      ? document!.rejectionReason
                      : config.subtitle,
                  style: GoogleFonts.manrope(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: body,
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

  _StatusConfig _statusConfig(CustomerDocumentStatus status) {
    switch (status) {
      case CustomerDocumentStatus.pending:
        return const _StatusConfig(
          title: 'Verification pending',
          subtitle: 'Your document has been submitted for review.',
          icon: Icons.hourglass_top_rounded,
          foreground: primary,
          background: softAccent,
        );
      case CustomerDocumentStatus.verified:
        return const _StatusConfig(
          title: 'Verified',
          subtitle: 'This document has been approved.',
          icon: Icons.verified_rounded,
          foreground: primary,
          background: softAccent,
        );
      case CustomerDocumentStatus.rejected:
        return const _StatusConfig(
          title: 'Action required',
          subtitle: 'Please review the rejection reason and upload again.',
          icon: Icons.error_outline_rounded,
          foreground: heading,
          background: Color(0xFFF2F4F3),
        );
      case CustomerDocumentStatus.notUploaded:
        return const _StatusConfig(
          title: 'Not uploaded',
          subtitle: 'Add both sides of this document to submit it.',
          icon: Icons.upload_file_rounded,
          foreground: primary,
          background: softAccent,
        );
    }
  }

  Widget _buildNumberField() {
    final controller =
        _selectedType == CustomerDocumentType.drivingLicense
            ? _licenseNumberController
            : _governmentIdController;

    final label =
        _selectedType == CustomerDocumentType.drivingLicense
            ? 'Driving License Number'
            : 'Government ID Number';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Document details'),
        const SizedBox(height: 10),
        TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          style: GoogleFonts.manrope(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: heading,
          ),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: GoogleFonts.manrope(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: muted,
            ),
            filled: true,
            fillColor: card,
            prefixIcon: const Icon(
              Icons.numbers_rounded,
              color: muted,
              size: 20,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: const BorderSide(
                color: primary,
                width: 1.4,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUploadSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Document photos'),
        const SizedBox(height: 5),
        Text(
          'Upload clear, readable photos. Avoid glare and cropped edges.',
          style: GoogleFonts.manrope(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: muted,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _uploadCard(
                title: 'Front side',
                file: _frontFiles[_selectedType],
                existingUrl:
                    _documents[_selectedType]?.frontImageUrl ?? '',
                onTap: () => _pickImage(
                  _selectedType,
                  true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _uploadCard(
                title: 'Back side',
                file: _backFiles[_selectedType],
                existingUrl:
                    _documents[_selectedType]?.backImageUrl ?? '',
                onTap: () => _pickImage(
                  _selectedType,
                  false,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _uploadCard({
    required String title,
    required File? file,
    required String existingUrl,
    required VoidCallback onTap,
  }) {
    final hasFile = file != null;
    final hasExisting = existingUrl.isNotEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: hasFile ? primary : border,
            width: hasFile ? 1.3 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            if (hasFile)
              Positioned.fill(
                child: Image.file(
                  file,
                  fit: BoxFit.cover,
                ),
              )
            else if (hasExisting)
              Positioned.fill(
                child: Image.network(
                  existingUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return _emptyUploadContent(title);
                  },
                ),
              )
            else
              _emptyUploadContent(title),
            if (hasFile || hasExisting)
              Positioned(
                top: 9,
                right: 9,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: heading.withValues(alpha: 0.72),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.edit_rounded,
                    color: Colors.white,
                    size: 15,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _emptyUploadContent(String title) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: softAccent,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.add_a_photo_outlined,
                color: primary,
                size: 22,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: heading,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Tap to upload',
              style: GoogleFonts.manrope(
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          disabledBackgroundColor: muted.withValues(alpha: 0.45),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
        ),
        child: _saving
            ? const SizedBox(
                width: 21,
                height: 21,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.cloud_upload_rounded,
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Submit for verification',
                    style: GoogleFonts.manrope(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSecurityNote() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.lock_outline_rounded,
          color: muted,
          size: 17,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Your documents are stored under your tenant and customer account and are used for rental verification.',
            style: GoogleFonts.manrope(
              fontSize: 9.5,
              fontWeight: FontWeight.w500,
              color: muted,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w800,
        color: heading,
      ),
    );
  }
}

class _StatusConfig {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color foreground;
  final Color background;

  const _StatusConfig({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.foreground,
    required this.background,
  });
}
