import 'package:flutter_test/flutter_test.dart';
import 'package:dsa_incentive_tracker/core/catalog/package_catalog.dart';
import 'package:dsa_incentive_tracker/core/engine/incentive_bucket.dart';

void main() {
  group('PackageCatalog Tests', () {
    test('Semua paket memiliki ID unik dan valid', () {
      final all = PackageCatalog.all;
      expect(all.isNotEmpty, isTrue);

      final ids = all.map((p) => p.id).toSet();
      expect(ids.length, equals(all.length), reason: 'Semua ID paket harus unik');
    });

    test('Semua paket memiliki harga > 0 dan speedMbps > 0', () {
      for (final p in PackageCatalog.all) {
        expect(p.price, greaterThan(0), reason: 'Harga paket ${p.id} harus > 0');
        expect(p.speedMbps, greaterThan(0), reason: 'Speed Mbps paket ${p.id} harus > 0');
        expect(p.title.isNotEmpty, isTrue);
        expect(p.speedLabel.isNotEmpty, isTrue);
        expect(p.type.isNotEmpty, isTrue);
        expect(p.features.isNotEmpty, isTrue);
      }
    });

    test('IncentiveBucket mapping untuk paket katalog utama', () {
      final tactical = PackageCatalog.findById('tactical-ftth-20-mbps')!;
      expect(IncentiveBucket.forPackage(tactical), equals(IncentiveBucket.f0));

      final fwaHero = PackageCatalog.findById('fwa-hero-100-mbps')!;
      expect(IncentiveBucket.forPackage(fwaHero), equals(IncentiveBucket.fwa));

      final ftth250 = PackageCatalog.findById('ftth-hero-250-mbps')!;
      expect(IncentiveBucket.forPackage(ftth250), equals(IncentiveBucket.f50));

      final ftth500 = PackageCatalog.findById('ftth-ultra-high-500-mbps')!;
      expect(IncentiveBucket.forPackage(ftth500), equals(IncentiveBucket.f100));

      final ftth1gb = PackageCatalog.findById('ftth-ultra-high-1-gbps')!;
      expect(IncentiveBucket.forPackage(ftth1gb), equals(IncentiveBucket.f200));

      final advance4Bln = PackageCatalog.findById('advance-50-mbps-4bln')!;
      expect(IncentiveBucket.forPackage(advance4Bln), equals(IncentiveBucket.p35));
    });

    test('PackageCatalog search filter by type and budget', () {
      final fwaPackages = PackageCatalog.search(type: 'fwa');
      expect(fwaPackages.every((p) => p.type.toLowerCase().contains('fwa') || p.title.toLowerCase().contains('fwa')), isTrue);

      final budgetPackages = PackageCatalog.search(maxPrice: 250000);
      expect(budgetPackages.every((p) => p.price <= 250000), isTrue);

      final speedPackages = PackageCatalog.search(minSpeed: 300);
      expect(speedPackages.every((p) => p.speedMbps >= 300), isTrue);
    });
  });
}
