import 'dart:io';

import 'package:flutter/material.dart';
import 'package:token_script_generator/classes.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Token Script Generator',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Token Script Generator'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  String directoryPath = "";
  final _pathContent = <FileSystemEntity>[];
  late File _contractFile;
  late String _contractName;
  late File _xmlFile;
  final _functionList = <String>[];
  final _functionRegex = RegExp(r'(?!\/\/)function .*?\)');
  final _contractRegex = RegExp(r'contract .*?\{');
  final _selectedFunctions = <String>[];
  bool _renderGenerateButton = false;
  final _processedFunctions = <ProcessedFunction>[];

  void _listFunctions(String givenPath) {
    setState(() {
      _pathContent.clear();
      _functionList.clear();
    });
    try {
      directoryPath = givenPath;
      final directory = Directory(givenPath);
      _pathContent.addAll(directory.listSync());
      final solPath =
          _pathContent.firstWhere((e) => e.path.split('.').last == 'sol');
      _contractFile = File(solPath.path);
      final contractContent = _contractFile.readAsLinesSync();
      for (final line in contractContent) {
        final contractMatch = _contractRegex.firstMatch(line);
        final functionMatch = _functionRegex.firstMatch(line);
        if (functionMatch != null) {
          _functionList.add(functionMatch.group(0).toString());
        }
        if (contractMatch != null) {
          _contractName = contractMatch.group(0).toString().split(' ')[1];
        }
      }
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('The directory, or the neccessary files could not be found'),
        ),
      );
    }
  }

  void _addSelectedFunction(bool? isSelected, int index) {
    if (isSelected ?? false) {
      _selectedFunctions.add(_functionList[index]);
    } else {
      _selectedFunctions.removeWhere(
        (element) => element == _functionList[index],
      );
    }
    setState(() {
      _renderGenerateButton = _selectedFunctions.isNotEmpty;
    });
  }

  void _processFunctions() {
    _selectedFunctions.forEach((functionString) {
      final firstSplit = functionString.split('(');
      final functionName = firstSplit.first.split(' ').last;
      final functionParams = <InputParameter>[];
      final paramSplit = firstSplit.last.split(')').first.split(',');
      paramSplit.forEach((paramString) {
        final cleanParam = paramString.split(' ');
        functionParams.add(InputParameter(cleanParam.last, cleanParam.first));
      });
      _processedFunctions.add(ProcessedFunction(functionName, functionParams));
    });
  }

  void _generateScriptFiles() {
    _processedFunctions.forEach((processedFunction) {
      final filePath =
          "$directoryPath${processedFunction.functionName.toLowerCase()}.en.js";
      File(filePath).createSync(recursive: true);
      _writeFunctionSpecificJsFile(File(filePath), processedFunction);
    });
  }

  void _writeFunctionSpecificJsFile(File jsFile, ProcessedFunction function) {
    jsFile.writeAsStringSync(jsInterpolator(function).interpolate());
  }

  void _editXmlFile() {
    XmlEditor(directoryPath, _pathContent, _processedFunctions, _contractName)
        .edit();
  }

  void _generateTokenScript() {
    _processFunctions();
    _generateScriptFiles();
    _editXmlFile();
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.search),
            const SizedBox(width: 16),
            Expanded(
              child: TextField(
                style: TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Directory path',
                  hintStyle: TextStyle(color: Colors.white),
                ),
                onSubmitted: _listFunctions,
              ),
            ),
          ],
        ),
      ),
      body: Container(
        padding:
            const EdgeInsets.only(bottom: 80, top: 50, right: 50, left: 50),
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _functionList.length,
          itemBuilder: (context, index) {
            final item = _functionList[index];
            return _CheckboxListTile(
              title: item,
              onChanged: (value) {
                _addSelectedFunction(value, index);
              },
            );
          },
        ),
      ),
      floatingActionButton: _renderGenerateButton
          ? FloatingActionButton.extended(
              onPressed: _generateTokenScript,
              label: Text("Generálás"),
            )
          : null,
    );
  }
}

class _CheckboxListTile extends StatefulWidget {
  const _CheckboxListTile(
      {super.key, required this.onChanged, required this.title});
  final void Function(bool?) onChanged;
  final String title;
  @override
  State<_CheckboxListTile> createState() => __CheckboxListTileState();
}

class __CheckboxListTileState extends State<_CheckboxListTile> {
  bool value = false;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: (value) {
        setState(() {
          if (value != null) {
            this.value = value;
          }
        });
        widget.onChanged(value);
      },
      title: Text(widget.title),
    );
  }
}
