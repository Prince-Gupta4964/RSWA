import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class YouTubeUploadService {
  static const String channelId = "UCgBIyCmjX1Ze03Y3rxZUQiA";
  static const String apiKey = "AIzaSyAHymBrB2rvUX0UI99zayAtDp8tuZu2TY4";
  
  // 🚀 Master OAuth Credentials (replace with your credentials)
  static const String defaultClientId = "YOUR_CLIENT_ID.apps.googleusercontent.com";
  static const String defaultClientSecret = "YOUR_CLIENT_SECRET";
  static const String defaultRefreshToken = "YOUR_REFRESH_TOKEN";

  static Future<String?> _getAccessToken(GoogleSignInAccount? googleUser) async {
    debugPrint('YOUTUBE: Starting access token resolution...');
    
    // 1. Try provided googleUser
    if (googleUser != null) {
      try {
        debugPrint('YOUTUBE: Attempting authorization via provided googleUser...');
        final clientAuth = await googleUser.authorizationClient.authorizeScopes([
          'https://www.googleapis.com/auth/youtube.upload',
          'https://www.googleapis.com/auth/youtube',
        ]);
        if (clientAuth.accessToken.isNotEmpty) {
          debugPrint('YOUTUBE: Got access token from googleUser successfully.');
          return clientAuth.accessToken;
        }
      } catch (e) {
        debugPrint('YOUTUBE ERROR getting token from googleUser: $e');
      }
    }

    // 2. Try fetching master refresh token from Firestore (settings/youtube), fallback to hardcoded master credentials
    String? refreshToken = defaultRefreshToken;
    String? clientId = defaultClientId;
    String? clientSecret = defaultClientSecret;

    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('youtube').get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        refreshToken = data['refresh_token']?.toString() ?? defaultRefreshToken;
        clientId = data['client_id']?.toString() ?? defaultClientId;
        clientSecret = data['client_secret']?.toString() ?? defaultClientSecret;
        debugPrint('YOUTUBE: Loaded settings from Firestore settings/youtube.');
      }
    } catch (e) {
      debugPrint('YOUTUBE ERROR fetching youtube settings from Firestore: $e');
    }

    try {
      if (refreshToken != null && clientId != null && clientSecret != null) {
        debugPrint('YOUTUBE: Exchanging refresh token for access token at https://oauth2.googleapis.com/token...');
        final response = await http.post(
          Uri.parse('https://oauth2.googleapis.com/token'),
          body: {
            'client_id': clientId,
            'client_secret': clientSecret,
            'refresh_token': refreshToken,
            'grant_type': 'refresh_token',
          },
        );

        debugPrint('YOUTUBE Token Exchange Response (${response.statusCode}): ${response.body}');

        if (response.statusCode == 200) {
          final tokenData = jsonDecode(response.body);
          final accessToken = tokenData['access_token']?.toString();
          if (accessToken != null && accessToken.isNotEmpty) {
            debugPrint('YOUTUBE: Got access token from refresh token successfully.');
            return accessToken;
          }
        } else {
          debugPrint('YOUTUBE ERROR: OAuth token exchange failed (${response.statusCode}): ${response.body}');
        }
      }
    } catch (e) {
      debugPrint('YOUTUBE EXCEPTION exchanging refresh token: $e');
    }

    debugPrint('YOUTUBE ERROR: All access token resolution methods failed.');
    return null;
  }

  /// Uploads a video file (bytes) to YouTube Data API v3 targeting channelId
  static Future<String?> uploadVideoBytes({
    required Uint8List videoBytes,
    required String title,
    required String description,
    GoogleSignInAccount? googleUser,
  }) async {
    try {
      final accessToken = await _getAccessToken(googleUser);

      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('YOUTUBE UPLOAD ERROR: Google Access Token is missing or expired.');
        return null;
      }

      const url = 'https://www.googleapis.com/upload/youtube/v3/videos?uploadType=multipart&part=snippet,status&key=$apiKey';
      
      final snippet = jsonEncode({
        "snippet": {
          "title": title.isNotEmpty ? title : "Property+ Project Video",
          "description": description,
          "categoryId": "22", // People & Blogs
          "channelId": channelId,
        },
        "status": {
          "privacyStatus": "unlisted",
          "selfDeclaredMadeForKids": false
        }
      });

      // Multipart body construction
      const boundary = '-------314159265358979323846';
      final header = "\r\n--$boundary\r\nContent-Type: application/json; charset=UTF-8\r\n\r\n$snippet\r\n--$boundary\r\nContent-Type: video/*\r\n\r\n";
      final footer = "\r\n--$boundary--";

      final bodyBytes = Uint8List.fromList([
        ...utf8.encode(header),
        ...videoBytes,
        ...utf8.encode(footer),
      ]);

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer $accessToken',
          'Content-Type': 'multipart/related; boundary="$boundary"',
          'Content-Length': bodyBytes.length.toString(),
        },
        body: bodyBytes,
      );

      debugPrint('YOUTUBE UPLOAD Response (${response.statusCode}): ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final videoId = data['id']?.toString();
        if (videoId != null && videoId.isNotEmpty) {
          final watchUrl = 'https://www.youtube.com/watch?v=$videoId';
          debugPrint('YOUTUBE UPLOAD SUCCESS: $watchUrl');
          return watchUrl;
        }
      }
      return null;
    } catch (e) {
      debugPrint('YOUTUBE UPLOAD EXCEPTION: $e');
      return null;
    }
  }
}
