import '../../domain/entities/workshop.dart';
import '../utils/workshop_coordinates.dart';

class WorkshopMapMarkerModel {
  const WorkshopMapMarkerModel({required this.workshopId, required this.title, required this.latitude, required this.longitude});

  final String workshopId;
  final String title;
  final double latitude;
  final double longitude;

  static List<WorkshopMapMarkerModel> fromWorkshops(Iterable<Workshop> workshops) => workshops
      .where((workshop) => validWorkshopCoordinates(workshop.latitude, workshop.longitude))
      .map((workshop) => WorkshopMapMarkerModel(workshopId: workshop.id, title: workshop.name, latitude: workshop.latitude!, longitude: workshop.longitude!))
      .toList(growable: false);
}