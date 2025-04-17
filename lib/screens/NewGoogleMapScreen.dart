import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_place_picker_mb/google_maps_place_picker.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../utils/Constants.dart';
import '../utils/Extensions/app_common.dart';

class NewGoogleMapScreen extends StatefulWidget {
  @override
  NewGoogleMapScreenState createState() => NewGoogleMapScreenState();
}

class NewGoogleMapScreenState extends State<NewGoogleMapScreen> {
  static final kInitialPosition = LatLng(-33.8567844, 151.213108);

  PickResult? selectedPlace;
  bool showPlacePickerInContainer = false;
  bool showGoogleMapInContainer = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  void init() async {
    //
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: PlacePicker(
        apiKey: googleMapAPIKey,
        hintText: language.findPlace,
        searchingText: language.pleaseWait,
        selectText: language.selectPlace,
        outsideOfPickAreaText: language.placeNotInArea,
        initialPosition: kInitialPosition,
        useCurrentLocation: true,
        selectInitialPosition: true,
        usePinPointingSearch: true,
        usePlaceDetailSearch: true,
        zoomGesturesEnabled: true,
        zoomControlsEnabled: true,
        automaticallyImplyAppBarLeading: false,
        autocompleteLanguage: '',
        autocompleteRadius: googleMapAutocompleteRadius,
        onMapCreated: (GoogleMapController controller) async {
          String _darkMapStyle =  await rootBundle.loadString('assets/json/dark_mode_style.json');
          controller.setMapStyle(_darkMapStyle);
        },
        onPlacePicked: (PickResult result) {
          setState(() {
            selectedPlace = result;
            log(selectedPlace!.formattedAddress);
            Navigator.pop(context, selectedPlace);
          });
        },
        onMapTypeChanged: (MapType mapType) {
          //
        },
      ),
    );
  }
}
