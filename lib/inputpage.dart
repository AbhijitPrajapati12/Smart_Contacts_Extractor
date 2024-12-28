import 'dart:io';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:smart_contacts_extractor/excelcreation.dart';

class InputPage extends StatefulWidget {
  const InputPage({super.key});

  @override
  State<InputPage> createState() => _InputPageState();
}

class _InputPageState extends State<InputPage> {
  TextEditingController fileNameController = TextEditingController();
  List<File> selectedImages = [];
  List<Map<String, String>> nameNumberPairs = [];
  late PhoneNumberService phoneNumberService;
  bool isLoading = false;

  @override
  void dispose() {
    fileNameController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    AwesomeNotifications().requestPermissionToSendNotifications().then(
      (isAllowed) {
        if (!isAllowed) {
          AwesomeNotifications().requestPermissionToSendNotifications();
        }
      },
    );

    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onNotificationActionReceived,
    );
    super.initState();
    phoneNumberService = PhoneNumberService();
  }

  Future<void> pickMultipleImages() async {
    final images = await phoneNumberService.pickMultipleImages();
    setState(() {
      selectedImages.addAll(images);
    });
  }

  Future<void> pickImageFromCamera() async {
    final image = await phoneNumberService.pickImageFromCamera();
    if (image != null) {
      setState(() {
        selectedImages.add(image);
      });
    }
  }

  void removeImage(int index) {
    setState(() {
      selectedImages.removeAt(index);
    });
  }

  Future<void> performTextDetection() async {
    if (selectedImages.isEmpty) {
      showError("No images selected! Please select at least one image.");
      return;
    }

    if (fileNameController.text.isEmpty) {
      showError("Please enter a file name");
      return;
    }
    setState(() {
      isLoading = true;
    });
    try {
      nameNumberPairs =
          await phoneNumberService.processAllImages(selectedImages);

      if (nameNumberPairs.isEmpty) {
        showError("No valid phone numbers found in any of the images.");
        return;
      }

      await phoneNumberService.writeToExcel(
        nameNumberPairs,
        fileNameController.text,
      );

      setState(() {
        isLoading = false;
      });
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Success"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  "${nameNumberPairs.length} unique phone numbers exported successfully!"),
              const SizedBox(height: 8),
              const Text("File Location:",
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text("Downloads/${fileNameController.text}.xlsx",
                  style: const TextStyle(color: Colors.blue)),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                fileNameController.clear();
              },
              child: const Text("OK"),
            ),
          ],
        ),
      );

      setState(() {});
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      showError("An error occurred while processing the images: $e");
    }
  }

  void showError(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Error"),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          backgroundColor: const Color.fromARGB(255, 173, 234, 175),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 50),
                if (selectedImages.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 40,
                      vertical: 20,
                    ),
                    child: Container(
                      height: 350,
                      decoration: const BoxDecoration(
                        color: Colors.pink,
                      ),
                      child: const Center(
                        child: Text(
                          "Please select Images",
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 350,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: selectedImages.length,
                      itemBuilder: (context, index) {
                        return Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(10.0),
                              child: Image.file(
                                selectedImages[index],
                                height: 350,
                                width: 150,
                              ),
                            ),
                            Positioned(
                              top: 0,
                              right: 0,
                              child: IconButton(
                                icon: const Icon(
                                  Icons.cancel,
                                  color: Colors.red,
                                  size: 30,
                                ),
                                onPressed: () => removeImage(index),
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onLongPress: () {
                        pickImageFromCamera();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 74, 156, 218),
                      ),
                      onPressed: () {
                        pickMultipleImages();
                      },
                      child: const Text(
                        "Pick images",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            const Color.fromARGB(255, 74, 156, 218),
                      ),
                      onPressed: () {
                        setState(() {
                          selectedImages.clear();
                        });
                      },
                      child: const Text(
                        'Clear all',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 30, vertical: 0),
                  child: TextField(
                    controller: fileNameController,
                    decoration: InputDecoration(
                      enabled: true,
                      focusedBorder: OutlineInputBorder(
                        borderSide: const BorderSide(
                          width: 0,
                          color: Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      suffixText: '.xlsx',
                      fillColor: Colors.white,
                      filled: true,
                      hintText: 'Please enter the file name',
                      hintStyle: const TextStyle(color: Colors.black),
                      border: OutlineInputBorder(
                        borderSide: const BorderSide(
                          width: 0,
                          color: Colors.white,
                        ),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 241, 26, 11),
                  ),
                  onPressed: isLoading ? null : performTextDetection,
                  child: const Text(
                    "Generate",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (isLoading)
          const Center(
            child: CircularProgressIndicator(
              backgroundColor: Colors.black,
            ),
          ),
      ],
    );
  }
}
