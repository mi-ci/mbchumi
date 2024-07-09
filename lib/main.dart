import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/cupertino.dart';
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  final InitializationSettings initializationSettings =
      InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  // Request notification permission for Android 13 and higher
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
  runApp(
      Home(flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin));
}

class Home extends StatelessWidget {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  Home({required this.flutterLocalNotificationsPlugin});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthApp(
          flutterLocalNotificationsPlugin: flutterLocalNotificationsPlugin),
    );
  }
}

class AuthApp extends StatefulWidget {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  AuthApp({required this.flutterLocalNotificationsPlugin});
  @override
  _AuthAppState createState() => _AuthAppState();
}

class _AuthAppState extends State<AuthApp> {
  TextEditingController _controller = TextEditingController();
  int a = 0;
  int pass = 0;
  String at = '';
  Timer? timer;

  @override
  void initState() {
    super.initState();
    _getPass();
  }

  Future<void> _getPass() async {
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref();
      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
        String lastValue = values['auth'].last.toString();

        setState(() {
          pass = int.parse(lastValue);
        });
      }
    } catch (e) {
      print('Error fetching data from Firebase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            SizedBox(height: 230),
            Center(
              child: Text(
                '가습기 관리자',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
            SizedBox(height: 10),
            Center(
              child: Image.asset('assets/logo.png'),
            ),
            SizedBox(height: 30),
            FractionallySizedBox(
              widthFactor: 0.5,
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  hintText: '관리자 암호를 입력하세요.', // Placeholder text
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(at),
            SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                a = int.parse(_controller.text);
                if (a == pass) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MyApp(
                          flutterLocalNotificationsPlugin:
                              widget.flutterLocalNotificationsPlugin),
                    ),
                  );
                } else {
                  setState(() {
                    at = '암호를 확인해주세요';
                    timer = Timer(Duration(seconds: 1), () {
                      setState(() {
                        at = '';
                      });
                    });
                  });
                }
              },
              child: Text('로그인'),
            ),
          ],
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin;

  MyApp({required this.flutterLocalNotificationsPlugin});
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int humiValue = 50;
  int? b;
  List<double> humidityData = [30.0, 40.0, 35.0, 45.0, 50.0, 55.0, 50.0];
  List<String> timeData = ['0', '0', '0', '0', '0', '0', '0'];
  late Timer timer;
  bool isHumidifierOn = false;
  int a = 0;
  double sv = 35;
  String mt = 'MBC천호 관제센터';

  @override
  void initState() {
    super.initState();
    getInitHumivalue();
    updateTimeData();
    getWebsiteData();
    _getLastHumiValue();
    timer = Timer.periodic(Duration(seconds: 15), (Timer t) {
      updateTimeData();
      getWebsiteData();
      _getLastHumiValue();
    });
  }

  @override
  void dispose() {
    timer.cancel(); // Cancel the timer
    super.dispose();
  }

  void updateTimeData() {
    DateTime now = DateTime.now();
    int currentMinute = now.minute;
    int currentHour = now.hour;
    print(currentMinute);
    print(currentHour);

    // Calculate the starting minute (rounding down to the nearest multiple of 5)
    int startMinute = (currentMinute ~/ 5) * 5;

    List<String> times = [];
    for (int i = 6; i >= 0; i--) {
      int minute = startMinute - (i * 5);
      int hour = currentHour;

      // Handle minute overflow
      if (minute < 0) {
        minute = 60 + startMinute - (i * 5);
        hour -= 1;
      }

      String time =
          '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      times.add(time);
    }
    setState(() {
      timeData = times;
    });
  }

  Future getWebsiteData() async {
    final url = Uri.parse('https://weather.com/weather/today/l/37.54,127.13');
    final response = await http.get(url);
    dom.Document html = parser.parse(response.body);
    final ex = html
            .querySelector(
                '#todayDetails > section > div > div.TodayDetailsCard--detailsContainer--2yLtL > div:nth-child(2) > div.WeatherDetailsListItem--wxData--kK35q > span')
            ?.text
            .replaceAll("%", "") ??
        '0';
    setState(() {
      b = int.parse(ex);
    });
  }

  Future getInitHumivalue() async {
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref();
      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
        String lastValue = values['humi'].last.toString().substring(0, 2);
        // String lastValue = values['humi'][values.length-1].toString();
        String lastValue2 = values['on'].last.toString();

        setState(() {
          humiValue = int.parse(lastValue);
          humidityData.add(humiValue.toDouble());
          if (humidityData.length > 7) {
            humidityData.removeAt(0);
          }
          humidityData.add(humiValue.toDouble());
          if (humidityData.length > 7) {
            humidityData.removeAt(0);
          }
          humidityData.add(humiValue.toDouble());
          if (humidityData.length > 7) {
            humidityData.removeAt(0);
          }
          humidityData.add(humiValue.toDouble());
          if (humidityData.length > 7) {
            humidityData.removeAt(0);
          }
          humidityData.add(humiValue.toDouble());
          if (humidityData.length > 7) {
            humidityData.removeAt(0);
          }
          humidityData.add(humiValue.toDouble());
          if (humidityData.length > 7) {
            humidityData.removeAt(0);
          }
          humidityData.add(humiValue.toDouble());
          if (humidityData.length > 7) {
            humidityData.removeAt(0);
          }
        });
      }
    } catch (e) {
      print('Error fetching data from Firebase: $e');
      setState(() {
        mt = e.toString();
      });
    }
  }

  Future<void> _getLastHumiValue() async {
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref();
      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
        String lastValue = values['humi'].last.toString().substring(0, 2);
        // String lastValue = values['humi'][values.length-1].toString();
        String lastValue2 = values['on'].last.toString();

        setState(() {
          humiValue = int.parse(lastValue);
          humidityData.add(humiValue.toDouble());
          if (humidityData.length > 7) {
            humidityData.removeAt(0);
          }
        });
        setState(() {
          a = int.parse(lastValue2);
        });

        if (humiValue < sv) {
          showNotification();
        }
      }
    } catch (e) {
      print('Error fetching data from Firebase: $e');
      setState(() {
        mt = e.toString();
      });
    }
  }

  Future<void> showNotification() async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails('your_channel_id', 'your_channel_name',
            channelDescription: 'your_channel_description',
            importance: Importance.max,
            priority: Priority.high,
            ticker: 'ticker');
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
    await widget.flutterLocalNotificationsPlugin.show(
        0, '습도 알림', '현재 강의실 습도가 $sv 이하입니다.', platformChannelSpecifics,
        payload: 'item x');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData(
          primaryColor: Colors.blue,
          scaffoldBackgroundColor: Colors.grey[200],
          buttonTheme: ButtonThemeData(
            buttonColor: Colors.blueAccent,
            textTheme: ButtonTextTheme.primary,
          ),
        ),
        home: Scaffold(
          appBar: AppBar(
            title: Text(mt),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  SizedBox(height: 10),
                  Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        HumidifierStatus(isOn: a == 1),
                        SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => StreamViewer(),
                              ),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons
                                    .camera_alt, // or any appropriate icon for CCTV
                                color: Colors.blue, // adjust color as needed
                                size: 24,
                              ),
                              SizedBox(width: 10),
                              Text(
                                'CCTV보기',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.blue[100], // background color
                            padding: EdgeInsets.symmetric(
                                vertical: 10, horizontal: 20),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ]),
                  SizedBox(height: 30),
                  _buildHumidityCard('외부 습도', b?.toDouble() ?? 0.0),
                  SizedBox(height: 20),
                  _buildHumidityCardWithChart('강의실 습도', humiValue.toDouble()),
                  SizedBox(height: 20),
                  Text(
                    '알림설정 : $sv 이하',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Slider(
                      value: sv,
                      max: 100,
                      divisions: 20,
                      activeColor: Colors.blue,
                      thumbColor: Colors.blueAccent,
                      label: sv.round().toString(),
                      onChanged: (double value) {
                        setState(() {
                          sv = value.truncateToDouble();
                        });
                      }),
                ],
              ),
            ),
          ),
        ));
  }

  Widget _buildHumidityCard(String title, double humidity) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '${humidity}%',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHumidityCardWithChart(String title, double humidity) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 10),
            Text(
              '${humidity.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
              ),
            ),
            SizedBox(height: 20),
            AspectRatio(
              aspectRatio: 2.0,
              child: LineChart(
                LineChartData(
                  lineBarsData: [
                    LineChartBarData(
                      spots: humidityData.asMap().entries.map((entry) {
                        return FlSpot(entry.key.toDouble(), entry.value);
                      }).toList(),
                      isCurved: true,
                      color: Colors.blue, // Set line colors here
                      barWidth: 2,
                      isStrokeCapRound: true,
                      belowBarData: BarAreaData(show: false),
                    ),
                  ],
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            timeData[value.toInt()],
                            style: const TextStyle(
                              color: Colors.blueGrey,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            '${value.toInt()}%',
                            style: const TextStyle(
                              color: Colors.blueGrey,
                              fontWeight: FontWeight.bold,
                              fontSize: 10,
                            ),
                          );
                        },
                        interval: 10,
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: false), // Hide top titles
                    ),
                    rightTitles: AxisTitles(
                      sideTitles:
                          SideTitles(showTitles: false), // Hide right titles
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.blueAccent, width: 1),
                  ),
                  minX: 0,
                  maxX: (humidityData.length - 1).toDouble(),
                  minY: 30,
                  maxY: 60,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class HumidifierStatus extends StatelessWidget {
  final bool isOn;

  HumidifierStatus({required this.isOn});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 10, horizontal: 20),
      decoration: BoxDecoration(
        color: isOn ? Colors.green[100] : Colors.red[100],
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOn ? Icons.check_circle : Icons.cancel,
            color: isOn ? Colors.green : Colors.red,
            size: 24,
          ),
          SizedBox(width: 10),
          Text(
            isOn ? '가습기 ON' : '가습기 OFF',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isOn ? Colors.green : Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

class StreamViewer extends StatefulWidget {
  @override
  _StreamViewerState createState() => _StreamViewerState();
}

class _StreamViewerState extends State<StreamViewer> {
  late Timer _timer;
  Uint8List? _currentImageData;
  Uint8List? _nextImageData;

  @override
  void initState() {
    super.initState();
    _startImageStream();
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  void _startImageStream() {
    _timer = Timer.periodic(
        Duration(milliseconds: 2000), (Timer t) => _fetchImage());
  }

  Future<void> _fetchImage() async {
    try {
      final response = await http
          .get(Uri.parse('http://172.104.100.179:5001/uploads/frame.jpg'));
      if (response.statusCode == 200) {
        setState(() {
          _nextImageData = response.bodyBytes;
          // Swap buffers
          _currentImageData = _nextImageData;
        });
      } else {
        print('Failed to load image');
      }
    } catch (e) {
      print('Error fetching image: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _currentImageData == null
          ? CircularProgressIndicator()
          : Image.memory(_currentImageData!),
    );
  }
}
