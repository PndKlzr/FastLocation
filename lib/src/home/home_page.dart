import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:hive/hive.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart'; // Para usar TextInputFormatter
import 'package:fastlocation/src/history/history_page.dart';

// Classe para formatar o CEP
class CepInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    String formattedCep = newValue.text.replaceAll(RegExp(r'\D'), ''); // Remove tudo que não é número

    if (formattedCep.length > 5) {
      formattedCep = '${formattedCep.substring(0, 5)}-${formattedCep.substring(5, formattedCep.length)}';
    }

    return TextEditingValue(
      text: formattedCep,
      selection: TextSelection.collapsed(offset: formattedCep.length),
    );
  }
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _cepController = TextEditingController();
  String _result = '';
  String? _address;
  bool _isLoading = false;

  void _openMap(String address) async {
    try {
      List<Location> locations = await locationFromAddress(address);
      var lat = locations.first.latitude;
      var lng = locations.first.longitude;

      var availableMaps = await MapLauncher.installedMaps;
      if (availableMaps.isNotEmpty) {
        await availableMaps.first.showMarker(
          coords: Coords(lat, lng),
          title: address,
        );
      }
    } catch (e) {
      print("Erro ao abrir o mapa: $e");
    }
  }

  void _searchCep() async {
    final cep = _cepController.text.trim().replaceAll('-', ''); // Remove o hífen para a validação

    if (cep.isEmpty || cep.length != 8 || !RegExp(r'^[0-9]+$').hasMatch(cep)) {
      setState(() {
        _result = 'CEP inválido. Insira um CEP válido com 8 dígitos.';
        _address = null;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _address = null;
    });

    try {
      var response = await Dio().get('https://viacep.com.br/ws/$cep/json/');
      if (response.data['erro'] == true) {
        setState(() {
          _result = 'CEP não encontrado.';
        });
      } else {
        final address = '${response.data['logradouro']}, ${response.data['bairro']}, '
            '${response.data['localidade']} - ${response.data['uf']}';

        setState(() {
          _result = address;
          _address = address;
        });

        var box = Hive.box('cep_history');
        box.add({
          'cep': cep,
          'address': address,
        });
      }
    } catch (e) {
      print('Erro: $e');
      setState(() {
        _result = 'Erro ao buscar o CEP. Verifique sua conexão com a internet.';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  // Função para limpar o histórico
  void _clearHistory() async {
    var box = Hive.box('cep_history');
    await box.clear(); // Limpa todos os registros da caixa
    setState(() {
      _result = 'Histórico limpo.';
      _address = null; // Limpa o endereço mostrado
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Center(child: Text('Fast Location')), // Título centralizado
        backgroundColor: Color(0xFF4CAF50), // Cor do AppBar
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            TextField(
              controller: _cepController,
              decoration: InputDecoration(
                labelText: 'Digite o CEP',
                labelStyle: TextStyle(color: Color(0xFF4CAF50)),
                border: OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF4CAF50)),
                ),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [CepInputFormatter()], // Formatter para o CEP
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _searchCep,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4CAF50), // Cor do botão
                padding: EdgeInsets.symmetric(vertical: 15.0),
                textStyle: TextStyle(fontSize: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Bordas arredondadas
                ),
              ),
              child: Text('Buscar Endereço'),
            ),
            SizedBox(height: 16.0),
            _isLoading
                ? CircularProgressIndicator()
                : _address != null
                ? Card(
              elevation: 4,
              shadowColor: Colors.grey.withOpacity(0.5),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Endereço Encontrado:',
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4CAF50), // Cor do texto
                      ),
                    ),
                    SizedBox(height: 8.0),
                    Text('Logradouro: ${_address!.split(',')[0]}'),
                    Text('Bairro: ${_address!.split(',')[1]}'),
                    Text('Cidade: ${_address!.split(',')[2].split('-')[0]}'),
                    Text('UF: ${_address!.split(',')[2].split('-')[1]}'),
                    SizedBox(height: 10.0),
                    ElevatedButton(
                      onPressed: () {
                        _openMap(_address!);
                      },
                      child: Text('Abrir no Google Maps'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFF4CAF50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30), // Bordas arredondadas
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
                : Text(
              _result,
              style: TextStyle(fontSize: 16.0),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => HistoryPage()),
                );
              },
              child: Text('Ver Histórico'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF4CAF50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Bordas arredondadas
                ),
              ),
            ),
            SizedBox(height: 16.0),
            ElevatedButton(
              onPressed: _clearHistory, // Função para limpar histórico
              child: Text('Limpar Histórico'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, // Cor do botão de limpar
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30), // Bordas arredondadas
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
