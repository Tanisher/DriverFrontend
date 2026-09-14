import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logistics_app/classes/Load.dart';
import 'package:logistics_app/screens/driver.dart';

void main() {
  Load sampleLoad() {
    return Load(
      id: 12,
      customerId: 4,
      customerName: 'Acme Haulage',
      description: 'Pallet of maize',
      weight: '12t',
      pickupLocation: 'Harare',
      deliveryLocation: 'Bulawayo',
      status: 'ASSIGNED',
    );
  }

  test('Load.fromJson reads nested customer and driver ids', () {
    final load = Load.fromJson({
      'id': 12,
      'description': 'Pallet of maize',
      'weight': 12,
      'pickupLocation': 'Harare',
      'deliveryLocation': 'Bulawayo',
      'status': 'ASSIGNED',
      'customer': {'id': 4, 'name': 'Acme Haulage'},
      'driver': {'id': 9},
    });

    expect(load.id, 12);
    expect(load.customerId, 4);
    expect(load.customerName, 'Acme Haulage');
    expect(load.driverId, 9);
    expect(load.weight, '12');
  });

  test('tripPhaseOf maps backend statuses onto the two-leg flow', () {
    expect(tripPhaseOf(null), TripPhase.ready);
    expect(tripPhaseOf(Trip(status: 'DEADHEAD')), TripPhase.deadhead);
    expect(tripPhaseOf(Trip(status: 'LOADED')), TripPhase.loaded);
    expect(tripPhaseOf(Trip(status: 'COMPLETED')), TripPhase.ready);
  });

  test('mileageRejectionMessage uses backend text instead of a generic failure',
      () {
    const body =
        '{"status":400,"message":"End mileage cannot be lower than start mileage"}';
    expect(
      mileageRejectionMessage(400, body),
      'End mileage cannot be lower than start mileage',
    );
    expect(mileageRejectionMessage(201, body), isNull);
    expect(mileageRejectionMessage(500, '{"message":"boom"}'), isNull);
  });

  testWidgets('assigned loads list lets the driver pick a load',
      (WidgetTester tester) async {
    Load? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AssignedLoadsPanel(
            isLoading: false,
            loads: [sampleLoad()],
            selectedLoad: null,
            onSelect: (load) => selected = load,
          ),
        ),
      ),
    );

    expect(find.text('Assigned Loads'), findsOneWidget);
    expect(find.text('Pallet of maize'), findsOneWidget);
    expect(find.text('Harare → Bulawayo'), findsOneWidget);
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Customer Name'), findsNothing);

    await tester.tap(find.text('Select'));
    await tester.pump();

    expect(selected?.id, 12);
    expect(selected?.customerId, 4);
  });

  testWidgets('ready phase shows Start trip with start mileage',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: TripFlowPanel(
              load: sampleLoad(),
              phase: TripPhase.ready,
              startMileage: '',
              startMileageController: TextEditingController(),
              endMileageController: TextEditingController(),
              dieselController: TextEditingController(),
              trailer1Controller: TextEditingController(),
              trailer2Controller: TextEditingController(),
              endMileageError: null,
              isSubmitting: false,
              onStartTrip: () {},
              onEndDeadhead: () {},
              onCompleteDelivery: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Start trip'), findsOneWidget);
    expect(find.text('Start mileage'), findsOneWidget);
    expect(find.text('Arrived / End deadhead'), findsNothing);
  });

  testWidgets('deadhead phase shows end-deadhead action',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const TripStatusBanner(phase: TripPhase.deadhead),
              Form(
                child: TripFlowPanel(
                  load: sampleLoad(),
                  phase: TripPhase.deadhead,
                  startMileage: '1000',
                  startMileageController: TextEditingController(),
                  endMileageController: TextEditingController(),
                  dieselController: TextEditingController(),
                  trailer1Controller: TextEditingController(),
                  trailer2Controller: TextEditingController(),
                  endMileageError: null,
                  isSubmitting: false,
                  onStartTrip: () {},
                  onEndDeadhead: () {},
                  onCompleteDelivery: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Deadhead — en route to pickup'), findsOneWidget);
    expect(find.text('Arrived / End deadhead'), findsOneWidget);
  });

  testWidgets('loaded phase shows delivery banner and two trailer fields',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const TripStatusBanner(phase: TripPhase.loaded),
              Form(
                child: TripFlowPanel(
                  load: sampleLoad(),
                  phase: TripPhase.loaded,
                  startMileage: '1100',
                  startMileageController: TextEditingController(),
                  endMileageController: TextEditingController(),
                  dieselController: TextEditingController(),
                  trailer1Controller: TextEditingController(),
                  trailer2Controller: TextEditingController(),
                  endMileageError:
                      'End mileage cannot be lower than start mileage',
                  isSubmitting: false,
                  onStartTrip: () {},
                  onEndDeadhead: () {},
                  onCompleteDelivery: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Loaded — en route to delivery'), findsOneWidget);
    expect(find.text('Complete delivery'), findsOneWidget);
    expect(find.text('Trailer 1'), findsOneWidget);
    expect(find.text('Trailer 2'), findsOneWidget);
    expect(
      find.text('End mileage cannot be lower than start mileage'),
      findsOneWidget,
    );
  });

  test('assignedVehicleFromJson reads nested profile assignment', () {
    final vehicle = assignedVehicleFromJson({
      'id': 9,
      'name': 'Sipho',
      'vehicle': {
        'licensePlate': 'ABC 123 GP',
        'make': 'Isuzu',
        'model': 'FTR',
      },
    });

    expect(vehicle?.plate, 'ABC 123 GP');
    expect(vehicle?.subtitle, 'Isuzu FTR');
  });

  testWidgets('assigned vehicle is read-only context, not a picker',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssignedVehicleBanner(
            vehicle: AssignedVehicle(
              plate: 'ABC 123 GP',
              make: 'Isuzu',
              model: 'FTR',
            ),
          ),
        ),
      ),
    );

    expect(find.text('Assigned vehicle'), findsOneWidget);
    expect(find.text('ABC 123 GP'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(DropdownButton), findsNothing);
    expect(find.text('Vehicle Registration'), findsNothing);
  });

  testWidgets('trip flow has no vehicle selection field',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Form(
            child: TripFlowPanel(
              load: sampleLoad(),
              phase: TripPhase.ready,
              startMileage: '',
              startMileageController: TextEditingController(),
              endMileageController: TextEditingController(),
              dieselController: TextEditingController(),
              trailer1Controller: TextEditingController(),
              trailer2Controller: TextEditingController(),
              endMileageError: null,
              isSubmitting: false,
              onStartTrip: () {},
              onEndDeadhead: () {},
              onCompleteDelivery: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Vehicle Registration'), findsNothing);
    expect(find.text('Start trip'), findsOneWidget);
  });

  testWidgets('assigned loads empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AssignedLoadsPanel(
            isLoading: false,
            loads: [],
            selectedLoad: null,
            onSelect: _noopSelect,
          ),
        ),
      ),
    );

    expect(
      find.text('No loads have been assigned to you yet'),
      findsOneWidget,
    );
  });
}

void _noopSelect(Load load) {}
