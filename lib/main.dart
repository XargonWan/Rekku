import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
        scaffoldBackgroundColor: Colors.transparent,
        textTheme: TextTheme(
          bodyMedium: TextStyle(
            fontFamily: 'Unifontexmono',
          ),
        ),
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
  String _response = ""; // Start with no text
  bool _showInputField = false;
  bool _isLoading = false;
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

  void startOllama() async {
    Process.start('ollama', ['serve']).then((Process process) {
      _ollamaProcess = process;
      stdout.addStream(process.stdout);
      stderr.addStream(process.stderr);
      print('Ollama server started successfully.');

      // Send the initial instruction prompt to the model, but do not expect a reply
      sendStartupInstruction();
    }).catchError((error) {
      setState(() {
        _response = 'Failed to start Ollama: $error';
      });
    });
  }

  void stopOllama() {
    _ollamaProcess?.kill();
  }

  Future<void> sendStartupInstruction() async {
    try {
      // Load the character prompt from the external file
      String prompt = await rootBundle.loadString('assets/character.txt');

      await Future.delayed(Duration(seconds: 2)); // Add a delay to ensure the server is ready

      // Retry logic
      int retryCount = 0;
      bool success = false;

      while (retryCount < 3 && !success) {
        try {
          // Send the prompt to the model
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
            success = true;
          } else {
            print('Failed to load Ollama response. Status code: ${response.statusCode}');
            print('Response body: ${response.body}');
            throw Exception('Failed to load Ollama response');
          }
        } catch (e) {
          retryCount++;
          if (retryCount == 3) {
            throw Exception('Failed to load character prompt after retries: $e');
          }
          await Future.delayed(Duration(seconds: 2)); // Wait before retrying
        }
      }

      // After the instruction is sent, greet the user
      _sendGreetMe();
    } catch (e) {
      print('Error loading character prompt: $e');
      setState(() {
        _response = 'Failed to load character prompt';
      });
    }
  }

  Future<String> fetchOllamaResponse(String userPrompt) async {
    try {
      // Load the character prompt from the external file
      String characterPrompt = await rootBundle.loadString('assets/character.txt');

      // Combine the character prompt with the user's query
      String combinedPrompt = "$characterPrompt\n\n$userPrompt";

      final response = await http.post(
        Uri.parse('http://127.0.0.1:11434/v1/completions'),
        headers: <String, String>{
          'Content-Type': 'application/json',
        },
        body: jsonEncode(<String, dynamic>{
          'prompt': combinedPrompt,
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

  void _sendGreetMe() async {
    String response = await fetchOllamaResponse("Greet me");
    setState(() {
      _response = response;
      _showInputField = true; // Show the input field after the first response
    });
  }

  void _getResponse() async {
    String prompt = _controller.text;
    if (prompt.isNotEmpty) {
      setState(() {
        _isLoading = true; // Show loading animation
        _showInputField = false; // Hide input field while loading
      });

      String response = await fetchOllamaResponse(prompt);

      setState(() {
        _response = response;
        _isLoading = false; // Stop loading animation
        _showInputField = true; // Show input field again after response
        _controller.clear(); // Clear the text field for the next input
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: WindowBorder(
        color: Colors.transparent,
        width: 0,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Container(
              width: 300, // Double the size (previously 150)
              height: 300, // Double the size (previously 150)
              color: Colors.transparent,
              child: Image.asset(
                'assets/rekku-genie.png',
                fit: BoxFit.contain,
              ),
            ),
            SizedBox(height: 20),
            if (_isLoading)
              CircularProgressIndicator() // Simple loading animation
            else
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Scrollbar(
                    thumbVisibility: true, // Ensure scrollbar is always visible
                    child: SingleChildScrollView(
                      child: Text(
                        _response,
                        style: TextStyle(
                          fontSize: 24,
                          color: Colors.purpleAccent,
                          fontFamily: 'Unifontexmono', // Use the custom font
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
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
                        style: TextStyle(color: Colors.purpleAccent),
                        decoration: InputDecoration(
                          hintText: 'Type your prompt here...',
                          hintStyle: TextStyle(color: Colors.purpleAccent.withOpacity(0.5)),
                          border: OutlineInputBorder(),
                        ),
                        onSubmitted: (_) => _getResponse(), // Trigger response on Enter
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.send, color: Colors.purpleAccent),
                      onPressed: _getResponse,
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
