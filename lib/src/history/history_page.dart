import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:map_launcher/map_launcher.dart';
import 'package:geocoding/geocoding.dart';

class HistoryPage extends StatelessWidget {
  void _openMap(String address) async {
    try {
      // Converte o endereço em coordenadas (latitude e longitude)
      List<Location> locations = await locationFromAddress(address);
      var lat = locations.first.latitude;
      var lng = locations.first.longitude;

      // Verifica quais aplicativos de mapas estão instalados
      var availableMaps = await MapLauncher.installedMaps;
      if (availableMaps.isNotEmpty) {
        // Abre o primeiro aplicativo de mapas disponível com o marcador do endereço
        await availableMaps.first.showMarker(
          coords: Coords(lat, lng),
          title: address,
        );
      } else {
        print("Nenhum aplicativo de mapas disponível");
      }
    } catch (e) {
      print("Erro ao abrir o mapa: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    var box = Hive.box('cep_history');
    return Scaffold(
      appBar: AppBar(
        title: Text('Histórico de Consultas'),
      ),
      body: ListView.builder(
        itemCount: box.length,
        itemBuilder: (context, index) {
          var item = box.getAt(box.length - 1 - index); // Inverte a ordem
          var address = item['address'];

          return ListTile(
            title: Text(address),
            subtitle: Text('CEP: ${item['cep']}'),
            trailing: IconButton(
              icon: Icon(Icons.map),
              onPressed: () {
                _openMap(address);  // Chama a função para abrir o mapa
              },
            ),
          );
        },
      ),
    );
  }
}
