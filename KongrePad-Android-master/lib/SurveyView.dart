import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:kongrepad/AlertService.dart';
import 'package:kongrepad/AppConstants.dart';
import 'package:http/http.dart' as http;
import 'package:kongrepad/Models/Survey.dart';
import 'package:kongrepad/Models/SurveyQuestion.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SurveyView extends StatefulWidget {
  const SurveyView({super.key, required this.survey});

  final Survey survey;

  @override
  State<SurveyView> createState() => _SurveyViewState(survey);
}

class _SurveyViewState extends State<SurveyView> {
  Survey? survey;
  List<SurveyQuestion>? questions;
  Set<int> answers = {};
  bool _sending = false;
  bool _loading = true;

  _SurveyViewState(this.survey);

  Future<void> getData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    try {
      final url = Uri.parse(
          'https://app.kongrepad.com/api/v1/survey/${survey?.id}/question');
      final response = await http.get(
        url,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final questionsJson = SurveyQuestionsJSON.fromJson(jsonData);
        setState(() {
          questions = questionsJson.data;
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
    return Scaffold(
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : Container(
          color: AppConstants.backgroundBlue,
          height: screenHeight,
          alignment: Alignment.center,
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                height: screenHeight * 0.1,
                decoration:
                const BoxDecoration(color: AppConstants.backgroundBlue),
                child: Container(
                  width: screenWidth,
                  child: Stack(
                    alignment: Alignment.centerLeft,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pop(context);
                        },
                        child: Container(
                          height: screenHeight * 0.05,
                          width: screenHeight * 0.05,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white, // Circular background color
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SvgPicture.asset(
                              'assets/icon/chevron.left.svg',
                              color: AppConstants.backgroundBlue,
                              height: screenHeight * 0.03,
                            ),
                          ),
                        ),
                      ),
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text(
                          survey!.title.toString(),
                          style:
                          const TextStyle(fontSize: 25, color: Colors.white),
                        )
                      ]),
                    ],
                  ),
                ),
              ),
              SizedBox(
                height: screenHeight * 0.01,
              ),
              Container(
                alignment: Alignment.centerLeft,
                width: screenWidth,
                height: screenHeight * 0.763,
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                    ),
                    width: screenWidth,
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.start,
                        children: questions != null
                            ? questions!.map((question) {
                          return Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.start,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  question.question.toString(),
                                  textAlign: TextAlign.start,
                                  style: TextStyle(
                                      fontSize: 22,
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold),
                                ),
                                question.options?.length != 0
                                    ? Column(
                                    mainAxisAlignment:
                                    MainAxisAlignment.start,
                                    children:
                                    question.options!.map((option) {
                                      return CheckboxListTile(
                                        shape: const CircleBorder(),
                                        contentPadding: EdgeInsets.zero,
                                        title: Text(
                                          option.option.toString(),
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                              fontSize: 20,
                                              color: Colors.black),
                                        ),
                                        value: option.isSelected,
                                        onChanged: (value) {
                                          setState(() {
                                            question.options!
                                                .forEach((o) {
                                              if (o == option) {
                                                o.isSelected = value!;
                                                answers.add(o.id!);
                                              } else {
                                                o.isSelected = false;
                                                answers.remove(o.id);
                                              }
                                            });
                                          });
                                        },
                                        controlAffinity:
                                        ListTileControlAffinity
                                            .leading,
                                      );
                                    }).toList())
                                    : Container(),
                                Container(
                                  width: double.infinity,
                                  height: screenHeight * 0.001,
                                  color: Colors.grey,
                                )
                              ],
                            ),
                          );
                        }).toList()
                            : [],
                      ),
                    ),
                  ),
                ),
              ),
              Container(
                height: screenHeight * 0.1,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: AppConstants.backgroundBlue),
                child: Container(
                  height: screenHeight*0.07,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants. buttonGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12), // <-- Radius
                      ),
                    ),
                    onPressed: _sending
                        ? null
                        : () {
                      _sendAnswers();
                    },
                    child: _sending
                        ? CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    )
                        : Text(
                      'Cevapları Gönder',
                      style: TextStyle(fontSize: 20, color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ));
  }

  Future<void> _sendAnswers() async {
    setState(() {
      _sending = true;
    });
    if (answers.length != questions?.length) {

      AlertService().showAlertDialog(
        context,
        title: 'Uyarı',
        content: 'Tüm soruları cevaplamanız gerekiyor.',
      );
      setState(() {
        _sending = false;
      });
      return;
    }
    final url = Uri.parse(
        'https://app.kongrepad.com/api/v1/survey/${survey?.id!}/vote');
    final body = jsonEncode({
      'options': "[${answers.map((int e) => e.toString()).join(",")}]",
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
        AlertService().showAlertDialog(
          context,
          title: 'Başarılı',
          content: "Teşekkürler, ankete başarıyla katıldınız!",
        );
        Navigator.of(context).pop();
      } else {
        AlertService().showAlertDialog(
          context,
          title: 'Hata',
          content: 'Bir hata meydana geldi!',
        );
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