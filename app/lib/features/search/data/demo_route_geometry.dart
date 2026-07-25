import 'package:halo/features/route_map/domain/map_geometry.dart';

/// Downtown LA pedestrian routes from Valhalla/OpenStreetMap.
///
/// The source shapes use Valhalla's polyline6 encoding. Keeping the encoded
/// shapes avoids rounding away short sidewalk links and road turns.
const _encodedRouteShapes = {
  'balanced':
      r'}md}_A|enp`FqK}Gs@BsAzAsGxNU`@oYyWqBpD{TqSuH}GoCcCcDaD}PcPyEaEaK{IyEeAw@q@}FgF{BmB_AuDsE_E{DsDeHwGiCcCiB_BeGqF{JiJgA{@kVwTcSkRsL{Ju@o@wCoCgIp@}@v@yAbC}Sz^yAhC}CnFi@|@GLoAqAG[WFyI}HyMwLqIwH}RmQuAkCSc@MWuDyDx@}A`MqUbE}HR_@lDwGvBgEjDmGnC}E|KwRdTu_@tCqFvCuEvLyT~Pc[n@mAvCmFjDsFqCoDq@EjBcC~]so@mTgTgWoUm@sBeP{NePyNuBu@wOgN]Mb@w@LO{D}DuDuDg\gZuAoAye@wb@YYYU`AmBaCcC}C_DqDeDwJyIqBcBoCmBgKgJqGmF_O{MuDeDrAaCf@s@z@u@lEeC~B{BlCwDzAsEh@uCN}CK_Ew@yCcBiCNY`@_Ap@yAdAcC^y@b@cATe@`@yAFaDr@_KCsBaAwHc@y@h@uBh@g@d@eA~@wEjA}Ft@cBfBoTDi@TuCRgCJmAl@sHRmC{Dc@MC_Hy@PoCm@G',
  'shaded':
      r'}md}_A|enp`FqK}Gs@BsAzAsGxNU`@oYyW_UqSiGqF]y@DaA~BoEp\}j@\m@XWBa@yBsBnBgEpB}CzG_MdEqHpB_D`FoJbB{CzEmIlBaDjAuB`AcBpKmRbEoHrPuZ`AaB~@{ApCoDqAoA_AUmXiVi^w[_KsJeHkGKg@k@}@gCgCaCeCuAa@eqAujA[s@iA}AyAqB_@cA}@?O@cBSum@_m@_GwFiC_C`H}K|AgC~Ro[|@{Ak@aA{DgCiEqC}@k@Gy@Uk@eJcHg@Yc@KkAEc@O{NiK_@e@[iA]i@_CkB_CaBgCiB}BaBRc@HQr@yAiGqEoPwL]UqCqEaBsAgMgK_FsCeE}DaHmGcMwLyBwBcBaBoAsAmCWuCiC}OaOiHyGwFiFcDmF_DyDe@g@iF_FoHiGoC_CyBuBsDyCaGsE{]aWmAw@sAuC{AiA^y@b@cATe@`@yAFaDr@_KCsBaAwHc@y@h@uBh@g@d@eA~@wEjA}Ft@cBfBoTDi@TuCRgCJmAl@sHRmC{Dc@MC_Hy@PoCm@G',
  'quiet':
      r'}md}_A|enp`FqK}Gs@BsAzAsGxNU`@oYyW_UqSiGqF]y@DaA~BoEp\}j@\m@XWBa@lCwDwCcCqBmBq[{YkHaHoDcDeC{Bya@u^_CsBmCkCcJwIoGoG{FgF{OwNeLeKiNqLyEeEqDgDiDiDgv@qr@gHiGoFwEvCuEvLyT~Pc[n@mAvCmFjDsFqCoDq@EjBcC~]so@mTgTgWoUm@sBeP{NePyNuBu@wOgN]M_@Em@e@_CaCcCeCQs@P}@PUg\gZuAoAye@wb@YYYU`AmBaCcC}C_DqDeDwJyIqBcBoCmBgKgJqGmF_O{MuDeDrAaCf@s@z@u@lEeC~B{BlCwDzAsEh@uCN}CK_Ew@yCcBiCNY`@_Ap@yAdAcC^y@b@cATe@`@yAFaDr@_KCsBaAwHc@y@h@uBh@g@d@eA~@wEjA}Ft@cBfBoTDi@TuCRgCJmAl@sHRmC{Dc@MC_Hy@PoCm@G',
  'shortest':
      r'}md}_A|enp`FqK}Gs@BsAzAsGxNU`@oYyW_UqSiGqF]y@DaA~BoEp\}j@\m@XWBa@yBsBoB{BlByDvBmCAYc@QyZ_Y}A}AzIuP@uHxAuDXe@bN_Xd@{@aDsCkF{E~AyC}^e\mCcCeCmC{RcRuBuBgCcCmQiP}`@m^x@yBVm@Ni@s@e@}AwAwAqAw@a@bb@mu@h@s@@o@Tc@Rg@z@}B}|@cy@_A{@yEgEuFoFyz@ev@qDcDkUoS{KmJ}@u@_E{DuD}D}ZkX{CkCcRgPyDsCcMoK{@aAaCcC}C_DqDeDwJyIqBcBoCmBgKgJqGmF_O{MuDeDrAaCf@s@z@u@lEeC~B{BlCwDzAsEh@uCN}CK_Ew@yCcBiCNY`@_Ap@yAdAcC^y@b@cATe@`@yAFaDr@_KCsBaAwHc@y@h@uBh@g@d@eA~@wEjA}Ft@cBfBoTDi@TuCRgCJmAl@sHRmC{Dc@MC_Hy@PoCm@G',
};

final Map<String, List<MapCoordinate>> demoRoutePointsById =
    _buildDemoRoutePoints();

final MapCoordinate demoRouteOrigin = demoRoutePointsById['shortest']!.first;
final MapCoordinate demoRouteDestination =
    demoRoutePointsById['shortest']!.last;

List<MapCoordinate> demoRoutePointsFor(String candidateId) =>
    demoRoutePointsById[candidateId] ?? demoRoutePointsById['balanced']!;

List<MapCoordinate> _decodePolyline6(String shape) {
  final points = <MapCoordinate>[];
  var index = 0;
  var latitude = 0;
  var longitude = 0;

  int nextDelta() {
    var result = 0;
    var shift = 0;
    int byte;
    do {
      byte = shape.codeUnitAt(index++) - 63;
      result |= (byte & 0x1f) << shift;
      shift += 5;
    } while (byte >= 0x20);
    return (result & 1) == 0 ? result >> 1 : ~(result >> 1);
  }

  while (index < shape.length) {
    latitude += nextDelta();
    longitude += nextDelta();
    points.add(MapCoordinate(latitude / 1e6, longitude / 1e6));
  }
  return points;
}

Map<String, List<MapCoordinate>> _buildDemoRoutePoints() {
  final decoded = {
    for (final shape in _encodedRouteShapes.entries)
      shape.key: _decodePolyline6(shape.value),
  };
  final origin = decoded['shortest']!.first;
  final destination = decoded['shortest']!.last;
  return {
    for (final route in decoded.entries)
      route.key: List.unmodifiable([
        origin,
        ...route.value.skip(1).take(route.value.length - 2),
        destination,
      ]),
  };
}
