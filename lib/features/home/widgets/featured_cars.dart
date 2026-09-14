import 'package:flutter/material.dart';

import '../../cars/models/car.dart';
import '../../cars/screens/car_details_screen.dart';
import '../../cars/services/car_service.dart';
import '../../../core/config/app_config.dart';
import 'car_card.dart';

class FeaturedCars extends StatefulWidget {
  const FeaturedCars({super.key});

  @override
  State<FeaturedCars> createState() => _FeaturedCarsState();
}

class _FeaturedCarsState extends State<FeaturedCars> {
  final CarService _carService = CarService.instance;

  List<Car> _featuredCars = [];

  bool _isLoading = true;
  String? _errorMessage;

  String get _tenantId => AppConfig.tenant.tenantId;

  @override
  void initState() {
    super.initState();
    _loadFeaturedCars();
  }

  Future<void> _loadFeaturedCars() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tenantId = _tenantId;

      if (tenantId.trim().isEmpty) {
        throw Exception(
          'Tenant configuration is missing.',
        );
      }

      final cars = await _carService.getFeaturedCars(
        tenantId: tenantId,
      );

      if (!mounted) return;

      setState(() {
        _featuredCars = cars;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _featuredCars = [];
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  void _openCarDetails(Car car) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarDetailsScreen(
          car: car,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox.shrink();
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    if (_featuredCars.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        8,
        0,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(
              right: 20,
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Featured cars',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF17201F),
                    ),
                  ),
                ),

                TextButton(
                  onPressed: () {
                    // Connect to the complete Cars
                    // screen when we build Explore.
                  },
                  child: const Text(
                    'View all',
                    style: TextStyle(
                      color: Color(0xFF0F766E),
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 292,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(
                right: 20,
                bottom: 4,
              ),
              itemCount: _featuredCars.length,
              separatorBuilder: (_, __) {
                return const SizedBox(width: 14);
              },
              itemBuilder: (
                context,
                index,
              ) {
                final car = _featuredCars[index];

                return SizedBox(
                  width: 270,
                  child: CarCard(
                    car: car,
                    onTap: () {
                      _openCarDetails(car);
                    },
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFFE5EBE9),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFE6FFFB),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.directions_car_outlined,
                color: Color(0xFF0F766E),
                size: 21,
              ),
            ),

            const SizedBox(width: 12),

            const Expanded(
              child: Text(
                'Unable to load featured cars.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF17201F),
                ),
              ),
            ),

            TextButton(
              onPressed: _loadFeaturedCars,
              child: const Text(
                'Retry',
                style: TextStyle(
                  color: Color(0xFF0F766E),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}