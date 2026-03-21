import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  static final OcrService instance = OcrService._();
  OcrService._();

  // Ekstrak semua teks dari gambar
  Future<String> extractText(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImage);

      // Gabungkan semua baris teks
      final StringBuffer buffer = StringBuffer();
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
      }

      final result = buffer.toString().trim();
      print('🔵 OCR selesai — ${result.length} karakter diekstrak');
      return result;
    } catch (e) {
      print('🔴 OCR error: $e');
      return '';
    } finally {
      textRecognizer.close();
    }
  }
}