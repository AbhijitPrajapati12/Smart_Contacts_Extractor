import 'dart:io';
import 'dart:typed_data';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:excel/excel.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';

// import 'package:tflite_flutter/tflite_flutter.dart';

// class ProfileIconDetector {
//   late Interpreter _interpreter;

//   Future<void> loadModel() async {
//     _interpreter =
//         await Interpreter.fromAsset('assets/model/Profileicons.tflite');
//   }

//   Future<List<Map<String, dynamic>>> detectIcons(Uint8List imageBytes) async {
//     // Preprocess the image and run inference.
//     // Add implementation for preprocessing and postprocessing.
//   }

//   void close() {
//     _interpreter.close();
//   }
// }

@pragma('vm:entry-point')
Future<void> onNotificationActionReceived(ReceivedAction receivedAction) async {
  final filePath = receivedAction.payload?['file_path'];
  if (filePath != null) {
    await handleNotificationTap(filePath);
  }
}

// Add this as a top-level function
Future<void> handleNotificationTap(String filePath) async {
  try {
    final file = File(filePath);
    if (await file.exists()) {
      final result = await OpenFile.open(filePath);
      if (result.type != ResultType.done) {
        print('Error opening file: ${result.message}');
      }
    } else {
      print('File does not exist: $filePath');
    }
  } catch (e) {
    print('Error handling notification tap: $e');
  }
}

class PhoneNumberService {
  Future<List<File>> pickMultipleImages() async {
    final picker = ImagePicker();
    final List<XFile> returnImages = await picker.pickMultiImage();
    return returnImages.map((xFile) => File(xFile.path)).toList();
  }

  Future<File?> pickImageFromCamera() async {
    final returnImage = await ImagePicker()
        .pickImage(source: ImageSource.camera, maxWidth: 350, maxHeight: 350);
    return returnImage != null ? File(returnImage.path) : null;
  }

  Future<List<Map<String, String>>> processAllImages(List<File> images) async {
    List<Map<String, String>> allNameNumberPairs = [];

    for (File image in images) {
      final pairs = await performTextDetectionWithNames(image);
      // Only add unique phone numbers
      for (var entry in pairs.entries) {
        if (!allNameNumberPairs.any((map) => map.containsKey(entry.key))) {
          allNameNumberPairs.add({entry.key: entry.value});
        }
      }
    }

    return allNameNumberPairs;
  }

  Future<Map<String, String>> performTextDetectionWithNames(
      File selectedImage) async {
    final textRecognizer = TextRecognizer();
    final inputImage = InputImage.fromFile(selectedImage);
    final recognizedText = await textRecognizer.processImage(inputImage);

    final phoneRegex = RegExp(
      r'(?:(?:\+|0{0,2})91[-\s]*)?[6789]\d{9}|(\d{5})[-\s]?(\d{5})',
      multiLine: true,
    );

    final invalidNameRegex = RegExp(
      r'^(?:'
      r'\d+\s*people|' // "27 people"
      r'Name|' // "Name"
      r'Phone\s*Number|' // "Phone Number"
      r'Search(?:\s+members)?|' // "Search" or "Search members"
      r'Blocked\s*Numbers?|' // "Blocked Numbers" or "Blocked Number"
      r'Cancel|' // "Cancel" button text
      r'Admin|' // "Admin" label
      r'Members?|' // "Member" or "Members"
      r'Contacts?|' // "Contact" or "Contacts"
      r'Search|' // standalone "Search"
      r'Group\s*Info|' // "Group Info"
      r'Settings?' // "Setting" or "Settings"
      r')$',
      caseSensitive: false,
    );

    Map<String, String> nameNumberPairs = {};
    String? currentName;

    for (var block in recognizedText.blocks) {
      for (var line in block.lines) {
        final lineText = line.text.trim();
        final phoneMatch = phoneRegex.firstMatch(lineText);

        if (phoneMatch != null) {
          String phoneNumber;
          if (phoneMatch.group(1) != null && phoneMatch.group(2) != null) {
            phoneNumber = '${phoneMatch.group(1)}${phoneMatch.group(2)}';
          } else {
            phoneNumber = phoneMatch.group(0)!.replaceAll(RegExp(r'[^\d]'), '');
            if (phoneNumber.length > 10 && phoneNumber.startsWith('91')) {
              phoneNumber = phoneNumber.substring(2);
            }
          }

          if (phoneNumber.length == 10) {
            currentName =
                currentName?.replaceAll(RegExp(r'[^\w\s]'), '').trim();
            if (currentName == null ||
                currentName.isEmpty ||
                invalidNameRegex.hasMatch(currentName)) {
              currentName = "Unknown";
            }

            if (!nameNumberPairs.containsKey(phoneNumber)) {
              nameNumberPairs[phoneNumber] = currentName;
            }
            currentName = null;
          }
        } else {
          if (!invalidNameRegex.hasMatch(lineText)) {
            currentName = lineText.replaceAll(RegExp(r'[^\w\s]'), '').trim();
          }
        }
      }
    }

    return nameNumberPairs;
  }

  Future<String> writeToExcel(
      List<Map<String, String>> nameNumberPairs, String fileName) async {
    var excel = Excel.createExcel();
    Sheet sheetObject = excel.sheets[excel.getDefaultSheet()]!;

    // Add headers
    sheetObject
        .appendRow([TextCellValue('Name'), TextCellValue('Phone Number')]);

    // Add data rows
    for (var pair in nameNumberPairs) {
      pair.forEach((phoneNumber, name) {
        sheetObject
            .appendRow([TextCellValue(name), TextCellValue(phoneNumber)]);
      });
    }

    String finalFileName = '$fileName.xlsx';
    Directory? directory = Directory('/storage/emulated/0/Download');
    String filePath;

    if (await directory.exists()) {
      filePath = '${directory.path}/$finalFileName';
    } else {
      final appDir = await getExternalStorageDirectory();
      if (appDir == null) {
        throw Exception('Could not access storage directory');
      }
      filePath = '${appDir.path}/$finalFileName';
    }

    final file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsBytes(excel.encode()!);
    await createExcelNotification(filePath, nameNumberPairs.length);
    return filePath;
  }

  Future<void> createExcelNotification(String filePath, int numberCount) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
          channelKey: 'basic_channel', // Using the basic channel we created
          title: 'Excel Export Complete',
          body: '$numberCount phone numbers exported successfully',
          payload: {'file_path': filePath},
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Status,
        ),
      );
    } catch (e) {
      print('Notification error: $e');
      // Handle the error appropriately
      rethrow;
    }
  }
}
