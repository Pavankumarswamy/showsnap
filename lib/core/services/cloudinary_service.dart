import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/env.dart';

class CloudinaryService {
  static const String _baseUrl = 'https://api.cloudinary.com/v1_1';

  Future<String> uploadImage(File file, String folder) async {
    return _upload(file, folder, 'image');
  }

  Future<String> uploadImageBytes(Uint8List bytes, String filename, String folder) async {
    final url = Uri.parse(
        '$_baseUrl/${AppEnv.cloudinaryCloudName}/image/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = AppEnv.cloudinaryUploadPreset
      ..fields['folder'] = folder
      ..files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed: $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }

  Future<String> uploadVideo(File file, String folder) async {
    return _upload(file, folder, 'video');
  }

  Future<String> _upload(File file, String folder, String resourceType) async {
    final url = Uri.parse(
        '$_baseUrl/${AppEnv.cloudinaryCloudName}/$resourceType/upload');

    final request = http.MultipartRequest('POST', url)
      ..fields['upload_preset'] = AppEnv.cloudinaryUploadPreset
      ..fields['folder'] = folder
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final response = await request.send();
    final body = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('Cloudinary upload failed: $body');
    }

    final json = jsonDecode(body) as Map<String, dynamic>;
    return json['secure_url'] as String;
  }

  String transformUrl(
    String url, {
    int? width,
    int? height,
    String crop = 'fill',
    String quality = 'auto',
    String format = 'auto',
  }) {
    if (url.isEmpty) return url;
    final transforms = <String>[
      if (width != null) 'w_$width',
      if (height != null) 'h_$height',
      'c_$crop',
      'q_$quality',
      'f_$format',
    ].join(',');
    return url.replaceFirst('/upload/', '/upload/$transforms/');
  }

  String posterThumbnail(String url) =>
      transformUrl(url, width: 300, height: 450, crop: 'fill');

  String bannerImage(String url) =>
      transformUrl(url, width: 800, height: 400, crop: 'fill');
}

final cloudinaryServiceProvider =
    Provider<CloudinaryService>((ref) => CloudinaryService());
