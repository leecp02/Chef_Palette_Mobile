import 'package:chef_palette/controller/reservation_controller.dart';
import 'package:chef_palette/models/reservation_model.dart';
import 'package:flutter/material.dart';

class ReservationAdminPanel extends StatefulWidget {
  const ReservationAdminPanel({super.key});

  @override
  State<ReservationAdminPanel> createState() => _ReservationAdminPanelState();
}

class _ReservationAdminPanelState extends State<ReservationAdminPanel> {
  final ReservationController _reservationController = ReservationController();
  Map<String, List<Map<String, dynamic>>> userReservations = {};

  @override
  void initState() {
    super.initState();
    _fetchAllReservations();
  }

  Future<void> _fetchAllReservations() async {
    try {
      // Group reservations by userId
          Map<String, List<Map<String, dynamic>>> groupedByUser = {};
            for (var reservation in  await _reservationController.getAllReservations()) {
              final status = reservation.status;
              groupedByUser.putIfAbsent(status, () => []);
              groupedByUser[status]!.add({
                'status': reservation.status,
                'reservation': reservation,
              });
            }
              setState(() {
              userReservations = groupedByUser;
              });                  
                               
    } catch (e) {
      debugPrint("Error fetching reservations: $e");
    }
  }

  Future<void> _updateReservationStatus(String id, String status) async {
    try {
      final updatedReservation = await _reservationController.getReservationById(id);
      if (updatedReservation != null) {
        updatedReservation.status = status;
        await _reservationController.updateReservation(id, updatedReservation);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Reservation $status successfully!")),
          );
        }
        _fetchAllReservations();
      }
      else {
        debugPrint("no data found");
      }
    } catch (e) {
      debugPrint("Failed to update reservation status: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Admin - Reservations")),
      body: userReservations.isEmpty
          ? Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: userReservations.length,
              itemBuilder: (context, index) {
                final status = userReservations.keys.elementAt(index);
                final reservations = userReservations[status]!;
                return ExpansionTile(
                  title: Text("Status: $status"),
                  children: reservations.map((res) {
                    final reservation = res['reservation'] as ReservationModel;
                    return Card(
                      child: ListTile(
                        title: Text(
                          "Date: ${reservation.date.toLocal()} - Time: ${reservation.time.format(context)}",
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("User ID: ${reservation.userId}"),
                            Text("Number of Persons: ${reservation.numberOfPersons}"),
                            Text("Notes: ${reservation.notes}"),
                            Text("Status: ${reservation.status}"),
                          ],
                        ),
                         trailing: reservation.status == "Pending"
                      ? DropdownButton<String>(
                          value: null, // No value selected by default
                          hint: Text("Select Action"),
                          items: [
                            DropdownMenuItem(
                              value: "Approved",
                              child: Text("Accept"),
                            ),
                            DropdownMenuItem(
                              value: "Rejected",
                              child: Text("Reject"),
                            ),
                          ],
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              debugPrint("this is executred");
                              debugPrint(res['reservation']);
                              _updateReservationStatus(res['id'], newValue);
                             }
                            else {
                              debugPrint("error on set value.");
                            }
                          },
                        )
                      : Text(reservation.status),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
    );
  }
}
