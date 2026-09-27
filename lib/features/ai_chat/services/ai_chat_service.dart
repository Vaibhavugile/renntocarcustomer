import 'package:cloud_functions/cloud_functions.dart';

class AIChatService {
  AIChatService._();

  static final AIChatService instance = AIChatService._();

  static const String _functionName = 'aiCustomerChat';
  static const String _region = 'us-central1';

  late final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(
    region: _region,
  );

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<AIChatResponse> sendMessage({
    required String tenantId,
    required String message,
    String? conversationId,

    // Optional context that we will use as the chatbot grows.
    String? customerId,
    String? language,
    Map<String, dynamic>? conversationState,
    Map<String, dynamic>? metadata,
  }) async {
    final cleanTenantId = tenantId.trim();
    final cleanMessage = message.trim();

    if (cleanTenantId.isEmpty) {
      throw AIChatException(
        'Tenant information is missing.',
        code: 'invalid-tenant',
      );
    }

    if (cleanMessage.isEmpty) {
      throw AIChatException(
        'Please enter a message.',
        code: 'empty-message',
      );
    }

    if (cleanMessage.length > 4000) {
      throw AIChatException(
        'Your message is too long. Please keep it under 4000 characters.',
        code: 'message-too-long',
      );
    }

    try {
      final callable = _functions.httpsCallable(
        _functionName,
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );

      final Map<String, dynamic> request = {
        'tenantId': cleanTenantId,
        'message': cleanMessage,
      };

      // Only send conversationId when we actually have one.
      if (conversationId != null &&
          conversationId.trim().isNotEmpty) {
        request['conversationId'] =
            conversationId.trim();
      }

      if (customerId != null &&
          customerId.trim().isNotEmpty) {
        request['customerId'] =
            customerId.trim();
      }

      if (language != null &&
          language.trim().isNotEmpty) {
        request['language'] =
            language.trim();
      }

      if (conversationState != null) {
        request['conversationState'] =
            conversationState;
      }

      if (metadata != null) {
        request['metadata'] = metadata;
      }

      final result = await callable.call(request);

      return AIChatResponse.fromCallableResult(
        result,
      );
    } on FirebaseFunctionsException catch (e) {
      throw AIChatException(
        _friendlyFirebaseError(e),
        code: e.code,
        details: e.details,
      );
    } on AIChatException {
      rethrow;
    } catch (e) {
      throw AIChatException(
        'Unable to contact the AI assistant. Please try again.',
        code: 'unknown-error',
        details: e.toString(),
      );
    }
  }

  // ============================================================
  // SIMPLE MESSAGE METHOD
  // ============================================================

  Future<AIChatResponse> ask({
    required String tenantId,
    required String message,
    String? conversationId,
  }) {
    return sendMessage(
      tenantId: tenantId,
      message: message,
      conversationId: conversationId,
    );
  }

  // ============================================================
  // FRIENDLY FIREBASE ERROR
  // ============================================================

  String _friendlyFirebaseError(
    FirebaseFunctionsException error,
  ) {
    switch (error.code) {
      case 'unauthenticated':
        return 'Please login again to use the AI assistant.';

      case 'permission-denied':
        return 'You do not have permission to use this assistant.';

      case 'invalid-argument':
        return error.message ??
            'Some chatbot information is invalid.';

      case 'not-found':
        return 'The AI assistant service was not found.';

      case 'resource-exhausted':
        return 'The AI assistant is temporarily busy. Please try again shortly.';

      case 'deadline-exceeded':
        return 'The AI assistant took too long to respond. Please try again.';

      case 'unavailable':
        return 'The AI assistant is temporarily unavailable.';

      case 'failed-precondition':
        return error.message ??
            'The AI assistant is not ready yet.';

      case 'internal':
        return 'Something went wrong on the AI service. Please try again.';

      default:
        return error.message ??
            'Unable to contact the AI assistant.';
    }
  }
}

// ============================================================
// AI CHAT RESPONSE
// ============================================================

class AIChatResponse {
  final bool success;

  final String? conversationId;

  final String message;

  final String? customerId;

  final String? customerName;

  final bool aiEnabled;

  final String? model;

  final String? version;

  final Map<String, dynamic> metadata;

  final Map<String, dynamic> conversationState;

  final Map<String, dynamic> rawData;

  AIChatResponse({
    required this.success,
    required this.message,
    this.conversationId,
    this.customerId,
    this.customerName,
    this.aiEnabled = false,
    this.model,
    this.version,
    this.metadata = const {},
    this.conversationState = const {},
    this.rawData = const {},
  });

  // ============================================================
  // FROM CALLABLE RESULT
  // ============================================================

  factory AIChatResponse.fromCallableResult(
    HttpsCallableResult result,
  ) {
    if (result.data is! Map) {
      throw AIChatException(
        'Invalid response received from AI assistant.',
        code: 'invalid-response',
      );
    }

    final data = Map<String, dynamic>.from(
      result.data as Map,
    );

    return AIChatResponse.fromMap(
      data,
    );
  }

  // ============================================================
  // FROM MAP
  // ============================================================

  factory AIChatResponse.fromMap(
    Map<String, dynamic> map,
  ) {
    final messageData =
        _mapFromDynamic(
      map['message'],
    );

    final customerData =
        _mapFromDynamic(
      map['customer'],
    );

    final metadata =
        _mapFromDynamic(
      map['metadata'],
    );

    final conversationState =
        _mapFromDynamic(
      map['conversationState'],
    );

    String message = '';

    // Current backend format:
    //
    // message: {
    //   content: "..."
    // }
    //
    if (messageData.isNotEmpty) {
      message =
          messageData['content']?.toString() ??
          messageData['text']?.toString() ??
          '';
    }

    // Also support a future backend format:
    //
    // message: "Hello"
    //
    if (message.isEmpty &&
        map['message'] is String) {
      message =
          map['message'].toString();
    }

    // Also support:
    //
    // response: "Hello"
    //
    if (message.isEmpty &&
        map['response'] != null) {
      message =
          map['response'].toString();
    }

    // Also support:
    //
    // content: "Hello"
    //
    if (message.isEmpty &&
        map['content'] != null) {
      message =
          map['content'].toString();
    }

    return AIChatResponse(
      success: map['success'] == true,

      conversationId:
          _stringValue(
        map['conversationId'],
      ),

      message: message,

      customerId:
          _stringValue(
        customerData['id'] ??
            customerData['customerId'],
      ),

      customerName:
          _stringValue(
        customerData['name'] ??
            customerData['customerName'],
      ),

      aiEnabled:
          metadata['aiEnabled'] == true,

      model:
          _stringValue(
        metadata['model'] ??
            map['model'],
      ),

      version:
          _stringValue(
        metadata['version'] ??
            map['version'],
      ),

      metadata:
          metadata,

      conversationState:
          conversationState,

      rawData:
          Map<String, dynamic>.from(
        map,
      ),
    );
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  AIChatResponse copyWith({
    bool? success,
    String? conversationId,
    String? message,
    String? customerId,
    String? customerName,
    bool? aiEnabled,
    String? model,
    String? version,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? conversationState,
    Map<String, dynamic>? rawData,
  }) {
    return AIChatResponse(
      success:
          success ?? this.success,

      conversationId:
          conversationId ??
          this.conversationId,

      message:
          message ?? this.message,

      customerId:
          customerId ?? this.customerId,

      customerName:
          customerName ?? this.customerName,

      aiEnabled:
          aiEnabled ?? this.aiEnabled,

      model:
          model ?? this.model,

      version:
          version ?? this.version,

      metadata:
          metadata ?? this.metadata,

      conversationState:
          conversationState ??
          this.conversationState,

      rawData:
          rawData ?? this.rawData,
    );
  }

  // ============================================================
  // HAS MESSAGE
  // ============================================================

  bool get hasMessage =>
      message.trim().isNotEmpty;

  // ============================================================
  // DISPLAY MESSAGE
  // ============================================================

  String get displayMessage {
    if (message.trim().isNotEmpty) {
      return message.trim();
    }

    return 'I’m sorry, I could not generate a response.';
  }

  // ============================================================
  // BOOKING STATE HELPERS
  // ============================================================

  dynamic get pickupDate =>
      conversationState['pickupDate'];

  dynamic get pickupTime =>
      conversationState['pickupTime'];

  dynamic get returnDate =>
      conversationState['returnDate'];

  dynamic get returnTime =>
      conversationState['returnTime'];

  dynamic get pickupBranchId =>
      conversationState['pickupBranchId'];

  dynamic get returnBranchId =>
      conversationState['returnBranchId'];

  dynamic get selectedCarId =>
      conversationState['selectedCarId'];

  dynamic get selectedPackageId =>
      conversationState['selectedPackageId'];

  dynamic get estimatedAmount =>
      conversationState['estimatedAmount'];
}

// ============================================================
// AI CHAT EXCEPTION
// ============================================================

class AIChatException implements Exception {
  final String message;

  final String? code;

  final dynamic details;

  AIChatException(
    this.message, {
    this.code,
    this.details,
  });

  @override
  String toString() {
    if (code == null ||
        code!.trim().isEmpty) {
      return message;
    }

    return '$message [$code]';
  }
}

// ============================================================
// HELPERS
// ============================================================

Map<String, dynamic> _mapFromDynamic(
  dynamic value,
) {
  if (value is Map) {
    return Map<String, dynamic>.from(
      value,
    );
  }

  return <String, dynamic>{};
}

String? _stringValue(
  dynamic value,
) {
  if (value == null) {
    return null;
  }

  final stringValue =
      value.toString().trim();

  if (stringValue.isEmpty) {
    return null;
  }

  return stringValue;
}