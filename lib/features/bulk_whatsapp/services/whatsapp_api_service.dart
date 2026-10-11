import 'package:flutter/foundation.dart';
import 'whatsapp_api_helper.dart';

class WhatsAppApiService {
  static const String _baseUrl = 'https://api.deropo.com/api/send';
  static const String _accessToken = '49fcad69d94676dde2f34259f870bb08';

  /// Formats the phone number to ensure it has '91' at the start and no '+'
  static String _formatPhoneNumber(String number) {
    String cleanNum = number.replaceAll(RegExp(r'[^0-9]'), '');
    
    if (cleanNum.length == 10) {
      return '91$cleanNum';
    } else if (cleanNum.startsWith('0') && cleanNum.length == 11) {
      return '91${cleanNum.substring(1)}';
    } else if (!cleanNum.startsWith('91') && cleanNum.length > 10) {
      // If it starts with some other country code, we leave it as is or try to handle.
      // But assuming mostly Indian numbers if they don't start with 91.
      return cleanNum;
    }
    
    return cleanNum;
  }

  static Future<bool> sendMessage({
    required String phoneNumber,
    String? message,
    String type = 'text',
    String? imageUrl,
    String? documentUrl,
    String? fileName,
    String? templateId,
    List<String>? variables,
    List<Map<String, dynamic>>? buttons,
    String? footerText,
  }) async {
    try {
      final formattedNumber = _formatPhoneNumber(phoneNumber);
      if (formattedNumber.isEmpty) return false;

      // Handle custom rich templates with POST request
      if (type == 'buttons' && buttons != null && buttons.isNotEmpty) {
        final uri = Uri.parse(_baseUrl);
        final Map<String, dynamic> body = {
          "number": formattedNumber,
          "type": "buttons",
          "message": message ?? "",
          "variables": <String, dynamic>{
            "buttons": buttons,
          }
        };

        if (footerText != null && footerText.isNotEmpty) {
          body["variables"]["footer"] = footerText;
        }

        // Include media if present in button templates
        if (imageUrl != null) {
          body["image_url"] = imageUrl;
        } else if (documentUrl != null) {
          body["document_url"] = documentUrl;
          if (fileName != null) body["file_name"] = fileName;
        }

        return await sendWhatsAppPostRequest(uri, body, _accessToken);
      }

      // Handle classic GET requests for text, media, or Deropo template_id
      final Map<String, String> params = {
        'number': formattedNumber,
        'type': type,
        'access_token': _accessToken,
      };

      if (message != null && message.isNotEmpty) {
        params['message'] = message;
      }

      if (type == 'image' && imageUrl != null) {
        params['image_url'] = imageUrl;
      } else if (type == 'document' && documentUrl != null) {
        params['document_url'] = documentUrl;
        if (fileName != null) params['file_name'] = fileName;
      } else if (type == 'template' && templateId != null) {
        params['template_id'] = templateId;
        if (variables != null) {
          for (int i = 0; i < variables.length; i++) {
            params['var${i + 1}'] = variables[i];
          }
        }
      }

      final uri = Uri.parse(_baseUrl).replace(queryParameters: params);
      return await sendWhatsAppGetRequest(uri);
    } catch (e) {
      debugPrint('Error sending WhatsApp message: $e');
      return false;
    }
  }
}
