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
  bool _showInputField = false;
  final TextEditingController _controller = TextEditingController();
  Process? _ollamaProcess;

  @override
  void initState() {
    super.initState();
    startOllama();
  }

  @override
  void dispose() {
    stopOllama();
    super.dispose();
  }

  void startOllama() {
    Process.start('ollama', ['serve']).then((Process process) {
      _ollamaProcess = process;
      stdout.addStream(process.stdout);
      stderr.addStream(process.stderr);
      print('Ollama server started successfully.');
    }).catchError((error) {
      setState(() {
        _response = 'Failed to start Ollama: $error';
      });
    });
  }

  void stopOllama() {
    _ollamaProcess?.kill();
  }

  Future<String> fetchOllamaResponse(String prompt) async {
    await Future.delayed(Duration(seconds: 2)); // Delay to ensure the server is ready
    try {
      final response = await http.post(
        Uri.parse('http://127.0.0.1:11434/v1/completions'),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'prompt': prompt,
          'model': 'gemma2:2b',
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body)['choices'][0]['text'];
      } else {
        print('Failed to load Ollama response. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to load Ollama response');
      }
    } catch (e) {
      print('Error fetching response: $e');
      return 'Error fetching response: $e';
    }
  }

  void _getResponse() async {
    String prompt = _controller.text;
    if (prompt.isNotEmpty) {
      String response = await fetchOllamaResponse(prompt);
      setState(() {
        _response = response;
        _showInputField = false; // Hide input field after sending
      });
    }
  }

@override
Widget build(BuildContext context) {
  return Scaffold(
    backgroundColor: Colors.transparent, // Transparent scaffold background
    body: WindowBorder(
      color: Colors.transparent,
      width: 0,
      child: SingleChildScrollView( // Wrap the content in a scrollable view
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 300, // Double the size (previously 150)
              height: 300, // Double the size (previously 150)
              color: Colors.transparent,
              child: Image.asset(
                'assets/rekku-genie.png', // Updated image name
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 20),
            Text(
              _response,
              style: TextStyle(fontSize: 24, color: Colors.purpleAccent), // Lighter purple color
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 20),
            if (_showInputField)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(color: Colors.purpleAccent), // Input text color matches response text
                        decoration: InputDecoration(
                          hintText: 'Type your prompt here...',
                          hintStyle: TextStyle(color: Colors.purpleAccent.withOpacity(0.5)), // Hint text color is a lighter purple
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: Colors.purpleAccent), // Send button in purple
                      onPressed: _getResponse, // Trigger the response when ">" is pressed
                    ),
                  ],
                ),
              ),
            if (!_showInputField)
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _showInputField = true; // Show the input field when "Talk" is pressed
                  });
                },
                child: Text('Talk'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purpleAccent, // Button color matches text color
                ),
              ),
          ],
        ),
      ),
    ),
  );
  }
}
