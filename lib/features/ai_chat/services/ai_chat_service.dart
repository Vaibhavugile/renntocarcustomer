import 'package:cloud_functions/cloud_functions.dart';

import 'ai_booking_state_service.dart';
import 'ai_conversation_service.dart';

class AIChatService {
  AIChatService._();

  static final AIChatService instance = AIChatService._();

  static const String _functionName = 'aiCustomerChat';
  static const String _region = 'us-central1';

  late final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(
    region: _region,
  );

  final AIConversationService _conversationService =
      AIConversationService.instance;

  final AIBookingStateService _bookingStateService =
      AIBookingStateService.instance;

  // ============================================================
  // SEND MESSAGE
  // ============================================================

  Future<AIChatResponse> sendMessage({
    required String tenantId,
    required String message,
    String? conversationId,
    String? customerId,
    String? language,
    Map<String, dynamic>? conversationState,
    Map<String, dynamic>? metadata,
  }) async {
    final cleanTenantId = tenantId.trim();
    final cleanMessage = message.trim();

    if (cleanTenantId.isEmpty) {
      throw const AIChatException(
        'Tenant information is missing.',
        code: 'invalid-tenant',
      );
    }

    if (cleanMessage.isEmpty) {
      throw const AIChatException(
        'Please enter a message.',
        code: 'empty-message',
      );
    }

    if (cleanMessage.length > 4000) {
      throw const AIChatException(
        'Your message is too long. Please keep it under 4000 characters.',
        code: 'message-too-long',
      );
    }

    try {
      // ----------------------------------------------------------
      // 1. GET / CREATE CONVERSATION
      // ----------------------------------------------------------

      final activeConversationId =
          await _conversationService.getOrCreateConversation(
        tenantId: cleanTenantId,
        conversationId: conversationId,
      );

      // ----------------------------------------------------------
      // 2. LOAD EXISTING BOOKING STATE
      // ----------------------------------------------------------

      final storedState =
          await _conversationService.getConversationState(
        tenantId: cleanTenantId,
        conversationId: activeConversationId,
      );

      // ----------------------------------------------------------
      // 3. MERGE STATE PASSED BY UI
      // ----------------------------------------------------------

      Map<String, dynamic> activeState =
          Map<String, dynamic>.from(storedState);

      if (conversationState != null &&
          conversationState.isNotEmpty) {
        activeState.addAll(
          _removeNullValues(conversationState),
        );
      }

      // ----------------------------------------------------------
      // 4. SAVE CUSTOMER MESSAGE
      // ----------------------------------------------------------

      await _conversationService.saveUserMessage(
        tenantId: cleanTenantId,
        conversationId: activeConversationId,
        content: cleanMessage,
      );

      // ----------------------------------------------------------
      // 5. PREPARE CLOUD FUNCTION REQUEST
      // ----------------------------------------------------------

      final Map<String, dynamic> request = {
        'tenantId': cleanTenantId,
        'message': cleanMessage,
        'conversationId': activeConversationId,
        'conversationState': activeState,
      };

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

      if (metadata != null &&
          metadata.isNotEmpty) {
        request['metadata'] = metadata;
      }

      // ----------------------------------------------------------
      // 6. CALL AI CLOUD FUNCTION
      // ----------------------------------------------------------

      final callable = _functions.httpsCallable(
        _functionName,
        options: HttpsCallableOptions(
          timeout: const Duration(seconds: 60),
        ),
      );

      final result =
          await callable.call(request);

      // ----------------------------------------------------------
      // 7. PARSE RESPONSE
      // ----------------------------------------------------------

      final response =
          AIChatResponse.fromCallableResult(
        result,
      );

      // ----------------------------------------------------------
      // 8. SAVE AI MESSAGE
      // ----------------------------------------------------------

      final responseConversationId =
          response.conversationId ??
              activeConversationId;

      if (response.message.trim().isNotEmpty) {
        await _conversationService
            .saveAssistantMessage(
          tenantId: cleanTenantId,
          conversationId:
              responseConversationId,
          content: response.message,
        );
      }

      // ----------------------------------------------------------
      // 9. SAVE UPDATED BOOKING STATE
      // ----------------------------------------------------------

      if (response.conversationState.isNotEmpty) {
        await _conversationService
            .updateConversationState(
          tenantId: cleanTenantId,
          conversationId:
              responseConversationId,
          state: response.conversationState,
        );
      }

      return response;
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
  // SIMPLE ASK
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
  // CREATE CONVERSATION
  // ============================================================

  Future<String> createConversation({
    required String tenantId,
  }) {
    return _conversationService.createConversation(
      tenantId: tenantId,
    );
  }

  // ============================================================
  // GET / CREATE CONVERSATION
  // ============================================================

  Future<String> getOrCreateConversation({
    required String tenantId,
    String? conversationId,
  }) {
    return _conversationService
        .getOrCreateConversation(
      tenantId: tenantId,
      conversationId: conversationId,
    );
  }

  // ============================================================
  // GET CONVERSATION
  // ============================================================

  Future<AIConversation?> getConversation({
    required String tenantId,
    required String conversationId,
  }) {
    return _conversationService.getConversation(
      tenantId: tenantId,
      conversationId: conversationId,
    );
  }

  // ============================================================
  // GET CONVERSATION STATE
  // ============================================================

  Future<Map<String, dynamic>>
      getConversationState({
    required String tenantId,
    required String conversationId,
  }) {
    return _conversationService
        .getConversationState(
      tenantId: tenantId,
      conversationId: conversationId,
    );
  }

  // ============================================================
  // UPDATE CONVERSATION STATE
  // ============================================================

  Future<void> updateConversationState({
    required String tenantId,
    required String conversationId,
    required Map<String, dynamic> state,
  }) {
    return _conversationService
        .updateConversationState(
      tenantId: tenantId,
      conversationId: conversationId,
      state: state,
    );
  }

  // ============================================================
  // GET MESSAGES
  // ============================================================

  Future<List<AIMessage>> getMessages({
    required String tenantId,
    required String conversationId,
    int limit = 100,
  }) {
    return _conversationService.getMessages(
      tenantId: tenantId,
      conversationId: conversationId,
      limit: limit,
    );
  }

  // ============================================================
  // MESSAGE STREAM
  // ============================================================

  Stream<List<AIMessage>> messagesStream({
    required String tenantId,
    required String conversationId,
    int limit = 100,
  }) {
    return _conversationService.messagesStream(
      tenantId: tenantId,
      conversationId: conversationId,
      limit: limit,
    );
  }

  // ============================================================
  // DELETE CONVERSATION
  // ============================================================

  Future<void> deleteConversation({
    required String tenantId,
    required String conversationId,
  }) {
    return _conversationService.deleteConversation(
      tenantId: tenantId,
      conversationId: conversationId,
    );
  }

  // ============================================================
  // BOOKING STATE
  // ============================================================

  AIBookingState getBookingState(
    Map<String, dynamic>? state,
  ) {
    return _bookingStateService.fromMap(
      state,
    );
  }

  // ============================================================
  // EMPTY BOOKING STATE
  // ============================================================

  AIBookingState createEmptyBookingState() {
    return _bookingStateService.createEmpty();
  }

  // ============================================================
  // MERGE BOOKING STATE
  // ============================================================

  AIBookingState mergeBookingState({
    required AIBookingState current,
    required Map<String, dynamic> updates,
  }) {
    return _bookingStateService.merge(
      current,
      updates,
    );
  }

  // ============================================================
  // UPDATE ONE BOOKING FIELD
  // ============================================================

  AIBookingState updateBookingField({
    required AIBookingState current,
    required String field,
    required dynamic value,
  }) {
    return _bookingStateService.updateField(
      current: current,
      field: field,
      value: value,
    );
  }

  // ============================================================
  // CLEAR BOOKING FIELD
  // ============================================================

  AIBookingState clearBookingField({
    required AIBookingState current,
    required String field,
  }) {
    return _bookingStateService.clearField(
      current: current,
      field: field,
    );
  }

  // ============================================================
  // VALIDATE BOOKING
  // ============================================================

  AIBookingValidation validateBooking(
    AIBookingState state,
  ) {
    return _bookingStateService.validate(
      state,
    );
  }

  // ============================================================
  // VALIDATE FOR CAR SEARCH
  // ============================================================

  AIBookingValidation validateForCarSearch(
    AIBookingState state,
  ) {
    return _bookingStateService
        .validateForCarSearch(
      state,
    );
  }

  // ============================================================
  // VALIDATE FOR CONFIRMATION
  // ============================================================

  AIBookingValidation validateForConfirmation(
    AIBookingState state,
  ) {
    return _bookingStateService
        .validateForConfirmation(
      state,
    );
  }

  // ============================================================
  // BOOKING STATE → MAP
  // ============================================================

  Map<String, dynamic> bookingStateToMap(
    AIBookingState state,
  ) {
    return state.toMap();
  }

  // ============================================================
  // BOOKING STATE → FIRESTORE MAP
  // ============================================================

  Map<String, dynamic> bookingStateToFirestore(
    AIBookingState state,
  ) {
    return _bookingStateService
        .toFirestoreMap(state);
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

  // ============================================================
  // REMOVE NULL VALUES
  // ============================================================

  Map<String, dynamic> _removeNullValues(
    Map<String, dynamic> source,
  ) {
    final result =
        <String, dynamic>{};

    for (final entry in source.entries) {
      if (entry.value != null) {
        result[entry.key] = entry.value;
      }
    }

    return result;
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

  const AIChatResponse({
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
      throw const AIChatException(
        'Invalid response received from AI assistant.',
        code: 'invalid-response',
      );
    }

    final data =
        Map<String, dynamic>.from(
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

    if (messageData.isNotEmpty) {
      message =
          messageData['content']
                  ?.toString() ??
              messageData['text']
                  ?.toString() ??
              '';
    }

    if (message.isEmpty &&
        map['message'] is String) {
      message =
          map['message'].toString();
    }

    if (message.isEmpty &&
        map['response'] != null) {
      message =
          map['response'].toString();
    }

    if (message.isEmpty &&
        map['content'] != null) {
      message =
          map['content'].toString();
    }

    return AIChatResponse(
      success:
          map['success'] == true,

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

      metadata: metadata,

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
          customerName ??
              this.customerName,

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
  // MESSAGE HELPERS
  // ============================================================

  bool get hasMessage =>
      message.trim().isNotEmpty;

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

  dynamic get pickupBranchName =>
      conversationState['pickupBranchName'];

  dynamic get returnBranchId =>
      conversationState['returnBranchId'];

  dynamic get returnBranchName =>
      conversationState['returnBranchName'];

  dynamic get pickupLocation =>
      conversationState['pickupLocation'];

  dynamic get returnLocation =>
      conversationState['returnLocation'];

  dynamic get requestedCarType =>
      conversationState['requestedCarType'];

  dynamic get requestedTransmission =>
      conversationState[
          'requestedTransmission'];

  dynamic get requestedFuel =>
      conversationState['requestedFuel'];

  dynamic get requestedSeats =>
      conversationState['requestedSeats'];

  dynamic get selectedCarId =>
      conversationState['selectedCarId'];

  dynamic get selectedCarName =>
      conversationState['selectedCarName'];

  dynamic get selectedCarImage =>
      conversationState['selectedCarImage'];

  dynamic get selectedCarBranchIds =>
      conversationState[
          'selectedCarBranchIds'];

  dynamic get pricingProfileId =>
      conversationState[
          'pricingProfileId'];

  dynamic get selectedPackageId =>
      conversationState[
          'selectedPackageId'];

  dynamic get selectedPackageName =>
      conversationState[
          'selectedPackageName'];

  dynamic get selectedPackageType =>
      conversationState[
          'selectedPackageType'];

  dynamic get includedKm =>
      conversationState['includedKm'];

  dynamic get extraKmCharge =>
      conversationState['extraKmCharge'];

  dynamic get extraHourCharge =>
      conversationState['extraHourCharge'];

  dynamic get packagePrice =>
      conversationState['packagePrice'];

  dynamic get durationHours =>
      conversationState['durationHours'];

  dynamic get durationDays =>
      conversationState['durationDays'];

  dynamic get baseAmount =>
      conversationState['baseAmount'];

  dynamic get packageAmount =>
      conversationState['packageAmount'];

  dynamic get extraKmAmount =>
      conversationState['extraKmAmount'];

  dynamic get extraHourAmount =>
      conversationState['extraHourAmount'];

  dynamic get specialDateAdjustment =>
      conversationState[
          'specialDateAdjustment'];

  dynamic get weekendAdjustment =>
      conversationState[
          'weekendAdjustment'];

  dynamic get securityDeposit =>
      conversationState['securityDeposit'];

  dynamic get taxes =>
      conversationState['taxes'];

  dynamic get discount =>
      conversationState['discount'];

  dynamic get finalAmount =>
      conversationState['finalAmount'];

  dynamic get currency =>
      conversationState['currency'];

  dynamic get bookingId =>
      conversationState['bookingId'];

  dynamic get bookingStatus =>
      conversationState['bookingStatus'];
}

// ============================================================
// AI CHAT EXCEPTION
// ============================================================

class AIChatException implements Exception {
  final String message;

  final String? code;

  final dynamic details;

  const AIChatException(
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