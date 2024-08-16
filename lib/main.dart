import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:bitsdojo_window/bitsdojo_window.dart';

void main() {
  runApp(RekkuGenieApp());

  doWhenWindowReady(() {
    final initialSize = Size(400, 600);
    appWindow.minSize = initialSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.show();
  });
}

class RekkuGenieApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rekku Genie',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.transparent, // Make background transparent
      ),
      home: RekkuGenieHomePage(),
    );
  }
}

class RekkuGenieHomePage extends StatefulWidget {
  @override
  _RekkuGenieHomePageState createState() => _RekkuGenieHomePageState();
}

class _RekkuGenieHomePageState extends State<RekkuGenieHomePage> {
  String _response = "I'm Rekku! What would you like to know?";

  @override
  void initState() {
    super.initState();
    startOllama();
  }

  void startOllama() {
    Process.start('ollama', ['serve']).then((Process process) {
      stdout.addStream(process.stdout);
      stderr.addStream(process.stderr);
    }).catchError((error) {
      setState(() {
        _response = 'Failed to start Ollama: $error';
      });
    });
  }

  Future<String> fetchOllamaResponse(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:11434'), // Updated to correct address and port
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, String>{
          'prompt': prompt,
        }),
      );

      if (response.statusCode == 200) {
        return response.body;
      } else {
        throw Exception('Failed to load Ollama response');
      }
    } catch (e) {
      return 'Error fetching response: $e';
    }
  }

  void _getResponse() async {
    String response = await fetchOllamaResponse("Your prompt here");
    setState(() {
      _response = response;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent, // Transparent scaffold background
      body: WindowBorder(
        color: Colors.transparent,
        width: 0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 150,
              height: 150,
              color: Colors.transparent,
              child: Image.asset(
                'assets/rekku-genie.png', // Updated image name
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 20),
            Text(
              _response,
              style: TextStyle(fontSize: 24),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: _getResponse,
              child: Text('Ask Rekku!'),
            ),
          ],
        ),
      ),
    );
  }
}
