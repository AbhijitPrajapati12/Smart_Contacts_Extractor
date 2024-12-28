import 'package:flutter/material.dart';
import 'package:smart_contacts_extractor/devicefiles.dart';
import 'package:smart_contacts_extractor/inputpage.dart';

class MyHome extends StatefulWidget {
  const MyHome({super.key});

  @override
  State<MyHome> createState() => _MyHomeState();
}

class _MyHomeState extends State<MyHome> {
  int currentPage = 0;

  List<Widget> pages = const [
    InputPage(),
    DeviceFilesPage(),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: currentPage,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: const Color.fromARGB(255, 173, 234, 175),
        selectedFontSize: 0, //done to get the fontsize of label to 0
        unselectedFontSize: 0, //done to get the fontsize of label to 0
        iconSize: 35,
        selectedItemColor: Colors.black,
        unselectedItemColor: Colors.white,
        onTap: (value) {
          setState(() {
            currentPage = value;
          });
        },
        currentIndex: currentPage,
        items: const [
          BottomNavigationBarItem(
            label: '',
            icon: Icon(Icons.home),
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder),
            label: '',
          ),
        ],
      ),
    );
  }
}
