import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:kongrepad/AppConstants.dart';
import 'package:http/http.dart' as http;
import 'package:kongrepad/Models/Debate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class DebateView extends StatefulWidget {
  const DebateView({super.key, required this.hallId});

  final int hallId;

  @override
  State<DebateView> createState() => _DebateViewState(hallId);
}

class _DebateViewState extends State<DebateView> {
  int? hallId;
  Debate? debate;
  bool _sending = false;
  bool _loading = true;

  _DebateViewState(this.hallId);

  Future<void> getData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Token: $token");

    try {
      final url = Uri.parse('http://app.kongrepad.com/api/v1/hall/$hallId/active-debate');
      print("Requesting data from: $url");
      final response = await http.get(
        url,
        headers: <String, String>{
          'Authorization': 'Bearer $token',
        },
      );

      print("Response status code: ${response.statusCode}");

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        print("Response data: $jsonData");
        final debateJson = DebateJSON.fromJson(jsonData);
        setState(() {
          debate = debateJson.data;
          _loading = false;
        });
        print("Debate data loaded successfully");
      } else {
        print("Error: ${response.body}");
      }
    } catch (e) {
      print('Error fetching data: $e');
    }
  }

  Future<void> _subscribeToPusher() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    print("Subscribing to Pusher with token: $token");

    if (token != null) {
      PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();
      await pusher.init(apiKey: "314fc649c9f65b8d7960", cluster: "eu");
      await pusher.connect();
      print("Connected to Pusher");

      final channelName = 'meeting-${widget.hallId}-attendee';
      print("Subscribing to channel: $channelName");
      await pusher.subscribe(channelName: channelName);

      pusher.onEvent = (PusherEvent event) {
        print('--- New Event Received ---');
        print('Event Name: ${event.eventName}');
        print('Event Data: ${event.data}');

        if (event.eventName!.startsWith('pusher:')) {
          print('Pusher system event: ${event.eventName} received and ignored.');
          return;
        }

        if (event.data == null || event.data!.isEmpty) {
          print('No data received in Pusher event.');
          return;
        }

        print('--- Processing Event Data ---');
        final eventName = event.eventName;
        print('Event name: $eventName');

        if (eventName == 'debate' || eventName == 'debate-activated') {
          try {
            final jsonData = jsonDecode(event.data!);
            print('Parsed event data: $jsonData');

            if (!jsonData.containsKey('hall_id')) {
              print('Error: No hall_id found in event data.');
              return;
            }

            final eventHallId = jsonData['hall_id'].toString();
            final widgetHallId = widget.hallId.toString();

            print('Event hall_id: $eventHallId');
            print('Widget hall_id: $widgetHallId');

            // Kontrol: hall_id'lerin eşleşmesi
            if (eventHallId == widgetHallId) {
              print('hall_id matched! Reloading debate data...');
              getData();  // Yeni debate verilerini yükle
            } else {
              print('Incorrect Hall ID: ${jsonData['hall_id']}');
            }
          } catch (e) {
            print('Error parsing event data: $e');
          }
        } else {
          print('Unhandled event type: $eventName');
        }

        print('--- Event Processing Completed ---');
      };
    }
  }

  @override
  void initState() {
    super.initState();
    print("DebateView initialized with hallId: $hallId");
    getData();
    _subscribeToPusher();
  }

  @override
  Widget build(BuildContext context) {
    print("Building DebateView");
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
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                ),
                child: SizedBox(
                  width: screenWidth,
                  child: const Text(
                    "Debate",
                    style: TextStyle(fontSize: 25, color: Colors.white),
                  ),
                ),
              ),
              const Text(
                "Lütfen aşağıdaki seçeneklerden birini seçin:",
                style: TextStyle(fontSize: 18, color: Colors.white),
                textAlign: TextAlign.center,
              ),
              SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: debate != null
                    ? Container(
                  height: screenHeight * 0.65,
                  width: screenWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: debate!.teams!.map((team) {
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
                              padding: MaterialStateProperty.all<EdgeInsetsGeometry>(
                                const EdgeInsets.all(12),
                              ),
                              shape: MaterialStateProperty.all<OutlinedBorder>(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            onPressed: () {
                              _sendAnswer(team.id!);
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                team.logoName != null
                                    ? Image.network(
                                  'https://app.kongrepad.com/storage/team-logos/${team.logoName}.${team.logoExtension}',
                                  width: 150,
                                  height: 150,
                                  fit: BoxFit.contain,
                                )
                                    : Text(team.title.toString()),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                )
                    : const Text(
                  'No active debate available.',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendAnswer(int answerId) async {
    setState(() {
      _sending = true;
    });
    final url = Uri.parse('https://app.kongrepad.com/api/v1/debate/${debate?.id!}/debate-vote');
    final body = jsonEncode({
      'option': answerId,
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${prefs.getString('token')}',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        if (jsonResponse['status']) {
          print("Vote submitted successfully.");
          Navigator.of(context).pop();
        } else {
          print("Failed to submit vote.");
        }
      } else {
        print("Error during vote submission: ${response.body}");
      }
    } catch (error) {
      print('Error sending vote: $error');
    } finally {
      setState(() {
        _sending = false;
      });
    }
  }
}
