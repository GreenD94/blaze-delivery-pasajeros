// import 'package:flutter/material.dart';
// import 'package:taxibooking/utils/Common.dart';

// class RequestsCard extends StatefulWidget {
//   // Define una función de callback que recibe los nuevos datos
//   final Function(List<String>) onDataChanged;

//   RequestsCard({required this.onDataChanged});

//   @override
//   _RequestsCardState createState() => _RequestsCardState();
// }

// class _RequestsCardState extends State<RequestsCard> {
//   List<String> rideRequests = [];

//   @override
//   void initState() {
//     super.initState();
//     // Inicialmente, carga los datos de alguna fuente de datos
//     _loadData();
//   }

//   void _loadData() async {
//     // Carga los datos de alguna fuente de datos
//     // _dataToShow = await fetchData();

//     // Llama a la función de callback para notificar que hay nuevos datos
//     widget.onDataChanged(rideRequests);
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: <Widget>[
//           for (var request in rideRequests)
//             Card(
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: <Widget>[
//                   ListTile(
//                     leading: commonCachedNetworkImage(request['driver_profile_image']),
//                     title: Text(request['driver_name']),
//                     subtitle: Text(toCurrency(request['counteroffer'])),
//                   ),
//                   ButtonBar(
//                     children: <Widget>[
//                       TextButton(
//                         child: Text(
//                           'RECHAZAR',
//                           style: TextStyle(color: Colors.red),
//                         ),
//                         // style: ButtonStyle(colo),
//                         onPressed: () {
//                           if (isBooking) {
//                             rideRequestId = request['id'];
//                             cancelRequest(goToRiderDashboardScreen: false);

//                             setState(() {
//                               rideRequests.removeWhere((element) => element['id'] == request['id']);
//                             });

//                             if (rideRequests.length == 0) {
//                               Navigator.pop(context);
//                             }
//                           }
//                         },
//                       ),
//                       TextButton(
//                         child: Text(
//                           'ACEPTAR',
//                           style: TextStyle(color: Colors.green),
//                         ),
//                         onPressed: () {
//                           if (isBooking) {
//                             acceptRequest(request['id'], request['driver_id']);
//                             setState(() {
//                               rideRequests.clear();
//                             });
//                             Navigator.pop(context);
//                           }
//                         },
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//         ],
//       ),
//     );
//   }
// }
