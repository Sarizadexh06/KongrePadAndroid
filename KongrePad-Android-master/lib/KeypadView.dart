import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:kongrepad/AppConstants.dart';
import 'package:http/http.dart' as http;
import 'package:kongrepad/Models/Keypad.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KeypadView extends StatefulWidget {
  const KeypadView({super.key, required this.hallId});

  final int hallId;

  @override
  State<KeypadView> createState() => _KeypadViewState(hallId);
}

class _KeypadViewState extends State<KeypadView> {
  int? hallId;
  Keypad? keypad;
  bool _sending = false;
  bool _loading = true;

  _KeypadViewState(this.hallId);

  Future<void> getData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final url =
      Uri.parse('http://app.kongrepad.com/api/v1/hall/$hallId/active-keypad');
      final response = await http.get(
        url,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final keypadJson = KeypadJSON.fromJson(jsonData);
        setState(() {
          keypad = keypadJson.data;
          _loading = false;
        });
      }
    } catch (e) {
      print('Error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  @override
  Widget build(BuildContext context) {
    Size screenSize = MediaQuery.of(context).size;
    double screenWidth = screenSize.width;
    double screenHeight = screenSize.height;
    return SafeArea(
      child: Scaffold(
          body: _loading
              ? const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          )
              : Container(
            height: screenHeight,
            alignment: Alignment.center,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  height: screenHeight * 0.1,
                  decoration: const BoxDecoration(
                    color: AppConstants.backgroundBlue,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.white, // Border color
                        width: 2, // Border width
                      ),
                    ),
                  ),
                  child: Container(
                      width: screenWidth,
                      child: Text(
                        "Anketler",
                        style: TextStyle(fontSize: 25, color: Colors.white),
                      )),
                ),
                Text(
                  "Anketlerimizi doldurarak bize yardımcı olabilirsiniz",
                  style: TextStyle(fontSize: 25, color: Colors.white),
                  textAlign: TextAlign.center,
                ),
                SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: keypad! != null ? Container(
                    height: screenHeight * 0.65,
                    width: screenWidth,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: keypad!.options!.map((option) {
                        return Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: SizedBox(
                            width: screenWidth * 0.8,
                            child: ElevatedButton(
                                style: ButtonStyle(
                                  backgroundColor: MaterialStateProperty.all<Color>(
                                      AppConstants.buttonLightPurple),
                                  foregroundColor: MaterialStateProperty.all<Color>(
                                      Colors.white),
                                  padding:
                                  MaterialStateProperty.all<EdgeInsetsGeometry>(
                                    const EdgeInsets.all(12),
                                  ),
                                  shape: MaterialStateProperty.all<
                                      RoundedRectangleBorder>(
                                    RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                ),
                                onPressed: () {
                                  _sendAnswer(option.id!);
                                },
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      option.option.toString(),
                                      style: TextStyle(fontSize: 20),
                                    ),
                                  ],
                                )),
                          ),
                        );
                      }).toList(),
                    ),
                  ) : Container(),
                ),
              ],
            ),
          )),
    );
  }

  Future<void> _sendAnswer(int answerId) async {
    setState(() {
      _sending = true;
    });
    final url = Uri.parse(
        'https://app.kongrepad.com/api/v1/keypad/${keypad?.id!}/vote');
    final body = jsonEncode({
      'option': answerId,
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    http
        .post(
      url,
      headers: {
        'Authorization': 'Bearer ${prefs.getString('token')}',
        'Content-Type': 'application/json',
      },
      body: body,
    )
        .then((response) {
      final jsonResponse = jsonDecode(response.body);
      if (jsonResponse['status']) {
        //todo make alerts
        Navigator.of(context).pop();
      } else {
        //todo make alerts burayı diğer sayfalara da koy
      }
      setState(() {
        _sending = false;
      });
    }).catchError((error) {
      print(error);
      setState(() {
        _sending = false;
      });
    });
  }
}