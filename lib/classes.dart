import 'dart:io';

class ProcessedFunction {
  var functionName = "";
  var functionParams = <InputParameter>[];

  ProcessedFunction(this.functionName, this.functionParams);
}

class InputParameter {
  var name = "";
  var type = "";

  InputParameter(this.name, this.type);
}

class jsInterpolator {
  ProcessedFunction _processedFunction;

  jsInterpolator(this._processedFunction);

  String determineInputType(String type) {
    switch (type) {
      case "bool":
        return "checkbox";
      default:
        return "text";
    }
  }

  String interpolate() {
    List<String> inputStringList = [];
    _processedFunction.functionParams.forEach((param) {
      inputStringList.add(
          "<input id=\"${param.name}\" type=\"${determineInputType(param.type)}\">");
    });
    String concatenatedInputString = "";
    inputStringList.forEach((element) {
      concatenatedInputString += "$element\n";
    });
    return '''
//<![CDATA[
class Token {

    constructor(tokenInstance) {
        this.props = tokenInstance;
    }

    render() {
        return`
        <div class="ui container">
          <div class="ui segment">
            <span><bold><h3>${_processedFunction.functionName}</h3></bold></span>
            $concatenatedInputString
          </div>
        </div>
        `;
    }
}

web3.tokens.dataChanged = (oldTokens, updatedTokens, tokenIdCard) => {
    const currentTokenInstance = web3.tokens.data.currentInstance;
    document.getElementById(tokenIdCard).innerHTML = new Token(currentTokenInstance).render();
};
//]]>''';
  }
}

class XmlEditor {
  final _doctypeRegex = RegExp(r'<!DOCTYPE token.*?\[');
  final _cardsRegex = RegExp(r'<ts:cards>');
  final String _directoryPath;
  final List<FileSystemEntity> _pathContent;
  final List<ProcessedFunction> _processedFunctions;
  final String _contractName;

  XmlEditor(this._directoryPath, this._pathContent, this._processedFunctions,
      this._contractName);

  void edit() {
    final xmlPath =
        _pathContent.firstWhere((e) => e.path.split('.').last == 'xml');
    final _xmlFile = File(xmlPath.path);
    final xmlContent = _xmlFile.readAsLinesSync();
    final filePath = "${_directoryPath}Generated.xml";
    File(filePath).createSync(recursive: true);
    final _newXmlFile = File(filePath);
    for (final line in xmlContent) {
      final doctypeMatch = _doctypeRegex.firstMatch(line);
      final cardsMatch = _cardsRegex.firstMatch(line);
      _newXmlFile.writeAsStringSync('$line\n', mode: FileMode.append);
      if (doctypeMatch != null) {
        _newXmlFile.writeAsStringSync(_generateFileDeclarations(),
            mode: FileMode.append);
      } else if (cardsMatch != null) {
        _newXmlFile.writeAsStringSync(_generateCards(), mode: FileMode.append);
      }
    }
  }

  String _generateFileDeclarations() {
    var declarationString = "";
    _processedFunctions.forEach((processedFunction) {
      declarationString +=
          "\t\t<!ENTITY ${processedFunction.functionName.toLowerCase()}.en SYSTEM \"${processedFunction.functionName.toLowerCase()}.en.js\">\n";
    });
    return declarationString;
  }

  String _typeToSyntax(String type) {
    switch (type) {
      case "address":
        return "1.3.6.1.4.1.1466.115.121.1.36";
      case "bool":
        return "1.3.6.1.4.1.1466.115.121.1.7";
      case "string":
        return "1.3.6.1.4.1.1466.115.121.1.26";
      case "uint":
        return "1.3.6.1.4.1.1466.115.121.1.27";
      default:
        return "1.3.6.1.4.1.1466.115.121.1.27";
    }
  }

  String _generateCards() {
    var cardsString = "";
    _processedFunctions.forEach((processedFunction) {
      var concatenatedAttributesString = "";
      var concatenatedDataString = "";
      processedFunction.functionParams.forEach((attribute) {
        concatenatedAttributesString +=
            '''<ts:attribute name="${attribute.name}">
                <ts:type>
                    <ts:syntax>${_typeToSyntax(attribute.type)}</ts:syntax>
                </ts:type>
                <ts:label>
                    <ts:string xml:lang="en">${attribute.name}</ts:string>
                </ts:label>
                <ts:origins>
                    <ts:user-entry as="${attribute.name}"/>
                </ts:origins>
            </ts:attribute>''';
        concatenatedDataString +=
            '''<ts:${attribute.type} ref="${attribute.name}"/>''';
      });

      cardsString += '''
    
    <ts:card type="action">
            <ts:label>
                <ts:string xml:lang="en">${processedFunction.functionName}</ts:string>
            </ts:label>
            $concatenatedAttributesString
            <ts:transaction>
                <ethereum:transaction function="${processedFunction.functionName}" contract="$_contractName" as="uint">
                    <ts:data>
                      $concatenatedDataString 
                    </ts:data>
                </ethereum:transaction>
            </ts:transaction>
            <ts:view
                xmlns="http://www.w3.org/1999/xhtml" xml:lang="en">
                <style type="text/css">&style;</style>
                <script type="text/javascript">&${processedFunction.functionName.toLowerCase()}.en;</script>
            </ts:view>
        </ts:card>''';
    });
    return cardsString;
  }
}
