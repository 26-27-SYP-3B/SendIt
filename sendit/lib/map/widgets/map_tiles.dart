import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

const mapInitialCenter = LatLng(47.6, 13.8);

TileLayer openStreetMapTiles({Key? key, ErrorTileCallBack? onError}) =>
    TileLayer(
      key: key,
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'at.sendit.app',
      maxNativeZoom: 19,
      errorTileCallback: onError,
    );

Widget openStreetMapAttribution() => const RichAttributionWidget(
  alignment: AttributionAlignment.bottomLeft,
  attributions: [TextSourceAttribution('OpenStreetMap-Mitwirkende')],
);
