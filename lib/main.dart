import 'dart:async';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;
import 'package:web_scraper/web_scraper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(Home());
}

class Home extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthApp(),
    );
  }
}

class AuthApp extends StatelessWidget {
  TextEditingController _controller = TextEditingController();
  int a = 0;
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
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                a = int.parse(_controller.text);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => MyApp(result: a),
                  ),
                );
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
  final int result;

  MyApp({required this.result});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  int humiValue = 50;
  int? b;
  int externalHumidity = 0; // External humidity (%)
  double internalHumidity = 0;
  List<double> humidityData = [30.0, 40.0, 35.0, 45.0, 50.0, 55.0, 50.0];
  late Timer timer;
  bool isHumidifierOn = false;
  int a = Random().nextInt(2);
  double sv = 35;

  @override
  void initState() {
    super.initState();
    b = widget.result;
    // Start a timer to update the humidity every 2 seconds
    timer = Timer.periodic(Duration(seconds: 5), (Timer t) {
      _getLastHumiValue();
    });
  }

  @override
  void dispose() {
    timer.cancel(); // Cancel the timer
    super.dispose();
  }

  Future<void> _getLastHumiValue() async {
    try {
      DatabaseReference ref = FirebaseDatabase.instance.ref("humi");
      DataSnapshot snapshot = await ref.get();

      if (snapshot.exists && snapshot.value != null) {
        Map<dynamic, dynamic> values = snapshot.value as Map<dynamic, dynamic>;
        String lastKey = values.keys.last.toString();
        String lastValue = values[lastKey].toString();

        setState(() {
          humiValue = int.parse(lastValue);
          humidityData.add(humiValue.toDouble());
          if (humidityData.length > 7) {
            humidityData.removeAt(0); // Keep only the last 7 values
          }
        });
      } else {
        setState(() {
          humiValue = 55;
          humidityData.add(humiValue.toDouble());
          if (humidityData.length > 7) {
            humidityData.removeAt(0); // Keep only the last 7 values
          }
        });
      }
    } catch (e) {
      print('Error fetching data from Firebase: $e');
    }
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
          title: Text('MBC천호 관제 센터'),
          centerTitle: true,
        ),
        body: Padding(
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
                      onPressed: () {},
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
                              color: Colors.white, // adjust color as needed
                            ),
                          ),
                        ],
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[100], // background color
                        padding:
                            EdgeInsets.symmetric(vertical: 10, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ]),
              SizedBox(height: 30),
              _buildHumidityCard('외부 습도', b?.toDouble() ?? 0.0),
              SizedBox(height: 20),
              _buildHumidityCardWithChart('현재 습도', humiValue.toDouble()),
              SizedBox(height: 20),
              Text(
                '습도 알람 설정 : $sv% 이하',
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
                      sv = value;
                    });
                  }),
            ],
          ),
        ),
      ),
    );
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
                            '${value.toInt()}',
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
