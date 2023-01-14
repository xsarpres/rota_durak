// ignore_for_file: prefer_interpolation_to_compose_strings

import 'dart:async';
import 'dart:convert';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:multi_select_flutter/multi_select_flutter.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Burulaş',
      theme: ThemeData(
        primarySwatch: Colors.purple,
      ),
      home: const Harita(),
    );
  }
}

class Harita extends StatefulWidget {
  const Harita({super.key});

  @override
  State<Harita> createState() => _HaritaState();
}

class _HaritaState extends State<Harita> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  CameraPosition baslangicKonumu = const CameraPosition(
    target: LatLng(40.185856, 29.063775),
    zoom: 10,
  );

  int haritaTuru = 0;
  MapType mapType = MapType.normal;

  final Location location = Location();

  late bool serviceEnabled;
  late PermissionStatus permissionGranted;
  late LocationData locationData;
  List<Marker> duraklarListesi = [];
  List<Polyline> rotalarListesi = [];
  BitmapDescriptor? durakIcon;
  List<MultiSelectItem> varyantlarListesi = [];
  List<dynamic> secilenVaryantlar = [];
  List<MultiSelectItem> tumDuraklarListesi = [];
  List<dynamic> secilenDuraklar = [];

  @override
  void initState() {
    super.initState();
    lokasyonIzinleri();
    _createMarkerImageFromAsset();
    varyantlarListesiniGetir();
    duraklarlarListesiniGetir();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Padding(
        padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
        child: Column(
          children: [
            Expanded(
              child: GoogleMap(
                mapType: mapType,
                initialCameraPosition: baslangicKonumu,
                onMapCreated: (GoogleMapController controller) {
                  _controller.complete(controller);
                },
                myLocationEnabled: true,
                zoomControlsEnabled: false,
                markers: Set<Marker>.of(duraklarListesi),
                polylines: Set<Polyline>.of(rotalarListesi),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: ExpandableFab(
        childrenOffset: const Offset(30, 4),
        type: ExpandableFabType.fan,
        distance: 130,
        children: [
          _buton(
            harita,
            const Icon(Icons.map),
          ),
          _buton(
            ortala,
            const Icon(Icons.center_focus_strong),
          ),
          _buton(
            rotalar,
            const Icon(Icons.route),
          ),
          _buton(
            duraklar,
            const Icon(Icons.place),
          ),
        ],
      ),
      floatingActionButtonLocation: ExpandableFab.location,
    );
  }

  Widget _buton(function, Icon icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: FloatingActionButton(
        onPressed: function,
        backgroundColor: Theme.of(context).primaryColor,
        heroTag: null,
        child: icon,
      ),
    );
  }

  Future<void> lokasyon() async {
    locationData = await location.getLocation();

    CameraPosition konum = CameraPosition(
      target: LatLng(locationData.latitude!, locationData.longitude!),
      zoom: 18,
    );

    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(konum));
  }

  void harita() {
    haritaTuru++;

    if (haritaTuru == 0) {
      mapType = MapType.normal;
    } else if (haritaTuru == 1) {
      mapType = MapType.satellite;
    } else {
      if (haritaTuru == 2) {
        haritaTuru = -1;
      }
      mapType = MapType.hybrid;
    }

    setState(() {
      mapType;
    });
  }

  Future<void> ortala() async {
    final GoogleMapController controller = await _controller.future;
    controller.animateCamera(CameraUpdate.newCameraPosition(baslangicKonumu));
  }

  Future<void> rotalar() async {
    await showDialog(
      context: context,
      builder: (context) {
        return RefreshIndicator(
          onRefresh: _varyantListesiniYenile,
          child: MultiSelectDialog(
            itemsTextStyle: const TextStyle(fontSize: 15),
            title: const Text("Rotalar"),
            cancelText: const Text("Çıkış"),
            confirmText: const Text("Tamam"),
            searchable: true,
            searchHint: "Rota Ara...",
            selectedColor: Theme.of(context).primaryColor,
            separateSelectedItems: true,
            items: varyantlarListesi,
            initialValue: secilenVaryantlar,
            onConfirm: (values) {
              secilenVaryantlar = values;
              rotaGoster();
            },
          ),
        );
      },
    );
  }

  Future<void> duraklar() async {
    await showDialog(
      context: context,
      builder: (context) {
        return RefreshIndicator(
          onRefresh: _durakListesiniYenile,
          child: MultiSelectDialog(
            itemsTextStyle: const TextStyle(fontSize: 14),
            title: const Text("Duraklar"),
            cancelText: const Text(
              "Çıkış",
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            confirmText: const Text(
              "Tamam",
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
            searchable: true,
            searchHint: "Durak Ara...",
            selectedColor: Theme.of(context).primaryColor,
            separateSelectedItems: true,
            items: tumDuraklarListesi,
            initialValue: secilenDuraklar,
            onConfirm: (values) {
              secilenDuraklar = values;
              durakGoster();
            },
          ),
        );
      },
    );
  }

  Future<void> lokasyonIzinleri() async {
    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) {
        return;
      }
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) {
        return;
      }
    }

    locationData = await location.getLocation();
  }

  Future<void> _createMarkerImageFromAsset() async {
    durakIcon = await BitmapDescriptor.fromAssetImage(
        const ImageConfiguration(), 'assets/bus_stop.png');
  }

  Future<void> durakGoster() async {
    duraklarListesi = [];

    if (secilenDuraklar.isEmpty) {
      setState(() {});
      return;
    }

    for (String durak in secilenDuraklar) {
      List<String> splittedDurak = durak.split(' - ');

      http.Response response = await http.get(Uri.parse(
          'http://duraklar.mehmetozsimsekler.com/api/islem.php?duraklar&durakkodu=' +
              splittedDurak[0]));
      if (response.statusCode == 200) {
        setState(() {
          var sonuc = jsonDecode(utf8.decode(response.bodyBytes));

          Marker durakNoktasi = Marker(
            markerId: MarkerId(splittedDurak[0]),
            position: LatLng(
              double.parse(sonuc[0]["durak_latitude"].toString()),
              double.parse(sonuc[0]["durak_longitude"].toString()),
            ),
            infoWindow: InfoWindow(
              title: splittedDurak[0],
              snippet: splittedDurak[1],
              onTap: () => _navigation(Uri.parse(
                  'geo:0,0?q=${sonuc[0]["durak_latitude"].toString()},${sonuc[0]["durak_longitude"].toString()}')),
            ),
            icon: durakIcon!,
          );

          duraklarListesi.add(durakNoktasi);
        });
      } else {
        debugPrint('İşlem başarısız: ${response.statusCode.toString()}');
      }
    }
  }

  Future<void> rotaGoster() async {
    rotalarListesi = [];

    if (secilenVaryantlar.isEmpty) {
      setState(() {});
      return;
    }

    for (String varyant in secilenVaryantlar) {
      http.Response response = await http.get(Uri.parse(
          'http://duraklar.mehmetozsimsekler.com/api/islem.php?varyant_adi="' +
              varyant +
              '"'));
      if (response.statusCode == 200) {
        List<LatLng> koordinatlar = [];
        setState(() {
          var sonuc = jsonDecode(utf8.decode(response.bodyBytes));
          for (var koordinat in sonuc["koordinatlar"]) {
            koordinatlar.add(
              LatLng(
                double.parse(koordinat["latitude"].toString()),
                double.parse(koordinat["longitude"].toString()),
              ),
            );
          }

          Polyline rota = Polyline(
            polylineId: PolylineId(sonuc["varyantadi"]),
            color: Theme.of(context).primaryColor,
            width: 4,
            points: koordinatlar,
          );

          rotalarListesi.add(rota);
        });
      } else {
        debugPrint('İşlem başarısız: ${response.statusCode.toString()}');
      }
    }
  }

  Future<void> _varyantListesiniYenile() async {
    await varyantlarListesiniGetir();
  }

  Future<void> varyantlarListesiniGetir() async {
    //http.Response postResponse = await http.post(Uri.parse(endURL), headers: headers, body: json);
    http.Response response = await http.get(Uri.parse(
        "http://duraklar.mehmetozsimsekler.com/api/islem.php?varyantlar"));

    if (response.statusCode == 200) {
      setState(() {
        varyantlarListesi = [];
        var sonuc = jsonDecode(utf8.decode(response.bodyBytes));

        for (var varyant in sonuc) {
          varyantlarListesi.add(MultiSelectItem(varyant, varyant));
        }
      });

      return;
    } else {
      debugPrint('İşlem başarısız: ${response.statusCode.toString()}');
      return;
    }
  }

  Future<void> _durakListesiniYenile() async {
    await duraklarlarListesiniGetir();
  }

  Future<void> duraklarlarListesiniGetir() async {
    //http.Response postResponse = await http.post(Uri.parse(endURL), headers: headers, body: json);
    http.Response response = await http.get(Uri.parse(
        "http://duraklar.mehmetozsimsekler.com/api/islem.php?duraklar&arama"));

    if (response.statusCode == 200) {
      setState(() {
        tumDuraklarListesi = [];
        var sonuc = jsonDecode(utf8.decode(response.bodyBytes));

        for (var durak in sonuc) {
          tumDuraklarListesi.add(MultiSelectItem(durak, durak));
        }
      });

      return;
    } else {
      debugPrint('İşlem başarısız: ${response.statusCode.toString()}');
      return;
    }
  }

  Future<void> _navigation(Uri url) async {
    if (!await launchUrl(url)) {
      throw 'Could not launch $url';
    }
  }
}
