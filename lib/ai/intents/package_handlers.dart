import 'package:intl/intl.dart';
import '../../core/catalog/package_catalog.dart';
import '../../core/engine/incentive_bucket.dart';
import '../core/entity_extractor.dart';
import '../models/quick_action.dart';

/// Handler untuk intent katalog paket, pencarian, komparasi, dan edukasi produk.
class PackageHandlers {
  PackageHandlers._();

  static final NumberFormat _currencyFmt = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Handler untuk `package_list`
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleList({
    required ExtractedEntities entities,
    String? explicitType,
  }) {
    final typeFilter = explicitType ?? entities.packageType;
    final packages = PackageCatalog.search(type: typeFilter);

    final sb = StringBuffer();
    if (typeFilter != null && typeFilter.isNotEmpty) {
      sb.writeln('📦 **Daftar Paket ${typeFilter.toUpperCase()} XL SATU:**\n');
    } else {
      sb.writeln('📦 **Daftar Paket Unggulan XL SATU:**\n');
    }

    if (packages.isEmpty) {
      sb.writeln('Tidak ditemukan paket dengan kriteria tersebut.');
    } else {
      for (final p in packages) {
        final bucket = IncentiveBucket.forPackage(p);
        final bucketLabel = bucket != null ? IncentiveBucket.getLabel(bucket) : '-';
        final isAdvance = p.tab == 3 || p.totalAdvance != null;
        final priceLabel = isAdvance
            ? '${_currencyFmt.format(p.price)}/bln (rata-rata per bulan, Exc. PPN)'
            : '${_currencyFmt.format(p.price)}/bln (Exc. PPN)';
        sb.writeln('• **${p.title}**');
        sb.writeln('  🚀 Speed: ${p.speedLabel} | 💰 $priceLabel');
        sb.writeln('  🎁 ${p.installation}');
        sb.writeln('  💼 Bucket Insentif: $bucketLabel\n');
      }
    }

    final actions = [
      const QuickAction(
        label: 'Daftar Paket FWA',
        intent: 'package_list',
        args: {'type': 'fwa'},
      ),
      const QuickAction(
        label: 'Daftar Paket FTTH',
        intent: 'package_list',
        args: {'type': 'ftth'},
      ),
      const QuickAction(
        label: 'Daftar Paket FMC',
        intent: 'package_list',
        args: {'type': 'fmc'},
      ),
      QuickAction.nav(
        label: 'Buka Katalog Lengkap',
        destination: CoachDestination.catalog,
      ),
    ];

    return (
      text: sb.toString().trim(),
      actions: actions,
      metadata: {'count': packages.length, 'filter': typeFilter},
    );
  }

  /// Handler untuk `package_detail`
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleDetail({
    required ExtractedEntities entities,
    String? explicitPackageId,
  }) {
    CatalogPackage? pkg;
    if (explicitPackageId != null) {
      pkg = PackageCatalog.findById(explicitPackageId);
    } else if (entities.speedMbps != null) {
      final matches = PackageCatalog.search(
        minSpeed: entities.speedMbps,
        type: entities.packageType,
      );
      if (matches.isNotEmpty) pkg = matches.first;
    }

    pkg ??= PackageCatalog.all.firstWhere(
      (p) => p.id == 'ftth-hero-250-mbps',
      orElse: () => PackageCatalog.all.first,
    );

    final bucket = IncentiveBucket.forPackage(pkg);
    final bucketLabel = bucket != null ? IncentiveBucket.getLabel(bucket) : '-';

    final sb = StringBuffer();
    sb.writeln('📦 **Detail Paket: ${pkg.title}**\n');
    sb.writeln('• **Tipe Jaringan:** ${pkg.type}');
    sb.writeln('• **Kecepatan:** ${pkg.speedLabel}');
    sb.writeln('• **Harga Langganan:** ${_currencyFmt.format(pkg.price)} / bulan (Exc. PPN)');
    sb.writeln('• **Biaya Pemasangan:** ${pkg.installation}');
    if (pkg.speedUpgrade != null) {
      sb.writeln('• **Benefit Upgrade:** ${pkg.speedUpgrade}');
    }
    sb.writeln('• **Klasifikasi Insentif:** $bucketLabel\n');

    sb.writeln('⭐ **Keunggulan & Fitur:**');
    for (final f in pkg.features) {
      sb.writeln('  ✓ $f');
    }

    final actions = [
      QuickAction(
        label: 'Script Tawar Paket Ini',
        intent: 'script_get',
        args: {'packageId': pkg.id},
      ),
      QuickAction(
        label: 'Simulasi Insentif',
        intent: 'incentive_calc',
        args: {'bucket': bucket},
      ),
      QuickAction.nav(
        label: 'Lihat di Katalog',
        destination: CoachDestination.catalog,
      ),
    ];

    return (
      text: sb.toString().trim(),
      actions: actions,
      metadata: {'packageId': pkg.id, 'price': pkg.price},
    );
  }

  /// Handler untuk `package_search`
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleSearch({
    required ExtractedEntities entities,
  }) {
    List<CatalogPackage> matches = [];

    if (entities.budgetRupiah != null) {
      matches = PackageCatalog.all
          .where((p) => p.price <= (entities.budgetRupiah! + 30000))
          .toList()
        ..sort((a, b) => a.price.compareTo(b.price));
    } else {
      // Default: paket paling ekonomis
      matches = [...PackageCatalog.all]..sort((a, b) => a.price.compareTo(b.price));
    }

    final topMatches = matches.take(4).toList();

    final sb = StringBuffer();
    if (entities.budgetRupiah != null) {
      sb.writeln('🔍 **Rekomendasi Paket Budget ${_currencyFmt.format(entities.budgetRupiah!)}:**\n');
    } else {
      sb.writeln('🔍 **Rekomendasi Paket Paling Hemat / Terjangkau:**\n');
    }

    if (topMatches.isEmpty) {
      sb.writeln('Belum ada paket yang cocok di bawah anggaran tersebut.');
    } else {
      for (final p in topMatches) {
        sb.writeln('• **${p.title}** (${p.type})');
        sb.writeln('  ⚡ ${p.speedLabel} | 💰 ${_currencyFmt.format(p.price)}/bln (Exc. PPN) | ${p.isFreeInstall ? "Gratis Pasang" : p.installation}\n');
      }
    }

    final actions = [
      const QuickAction(
        label: 'Daftar Paket FWA',
        intent: 'package_list',
        args: {'type': 'fwa'},
      ),
      const QuickAction(
        label: 'Daftar Paket FTTH',
        intent: 'package_list',
        args: {'type': 'ftth'},
      ),
      QuickAction.nav(
        label: 'Buka Katalog Lengkap',
        destination: CoachDestination.catalog,
      ),
    ];

    return (
      text: sb.toString().trim(),
      actions: actions,
      metadata: {'count': topMatches.length},
    );
  }

  /// Handler untuk `package_compare`
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleCompare({
    required ExtractedEntities entities,
  }) {
    final fwaHero = PackageCatalog.findById('fwa-hero-100-mbps')!;
    final ftthHero = PackageCatalog.findById('ftth-hero-250-mbps')!;

    final sb = StringBuffer();
    sb.writeln('⚖️ **Perbandingan Paket Populer Lapangan:**\n');
    sb.writeln('1️⃣ **${fwaHero.title}** (${fwaHero.type})');
    sb.writeln('   • Kecepatan: ${fwaHero.speedLabel}');
    sb.writeln('   • Harga: ${_currencyFmt.format(fwaHero.price)} / bulan (Exc. PPN)');
    sb.writeln('   • Keunggulan: Wireless Plug & Play, tanpa nunggu tiang ODP kabel.');
    sb.writeln('   • Bucket Insentif: ${IncentiveBucket.getLabel(IncentiveBucket.forPackage(fwaHero)!)}\n');

    sb.writeln('2️⃣ **${ftthHero.title}** (${ftthHero.type})');
    sb.writeln('   • Kecepatan: ${ftthHero.speedLabel}');
    sb.writeln('   • Harga: ${_currencyFmt.format(ftthHero.price)} / bulan (Exc. PPN)');
    sb.writeln('   • Keunggulan: True Unlimited kabel optik, latensi sangat stabil.');
    sb.writeln('   • Bucket Insentif: ${IncentiveBucket.getLabel(IncentiveBucket.forPackage(ftthHero)!)}\n');

    final diffPrice = ftthHero.price - fwaHero.price;
    sb.writeln('💡 *Insight Sales:* Selisih hanya ${_currencyFmt.format(diffPrice)}/bulan, pelanggan FTTH mendapat kecepatan 2.5x lipat lebih tinggi!');

    final actions = [
      const QuickAction(
        label: 'Perbedaan FWA vs FTTH',
        intent: 'fwa_vs_ftth',
      ),
      const QuickAction(
        label: 'Script Closing FTTH',
        intent: 'script_get',
        args: {'packageId': 'ftth-hero-250-mbps'},
      ),
      QuickAction.nav(
        label: 'Buka Katalog Paket',
        destination: CoachDestination.catalog,
      ),
    ];

    return (
      text: sb.toString().trim(),
      actions: actions,
      metadata: {'type': 'compare'},
    );
  }

  /// Handler untuk `fwa_vs_ftth`
  static ({String text, List<QuickAction> actions, Map<String, dynamic> metadata}) handleFwaVsFtth() {
    final fwaSample = PackageCatalog.findById('fwa-hero-100-mbps')!;
    final ftthSample = PackageCatalog.findById('ftth-hero-250-mbps')!;

    final sb = StringBuffer();
    sb.writeln('📶 **Perbedaan FWA vs FTTH (Kabel Fiber):**\n');
    sb.writeln('1. **XL SATU FWA (Fixed Wireless Access):**');
    sb.writeln('   • **Teknologi:** Router nirkabel Outdoor CPE menangkap sinyal seluler 5G/4G.');
    sb.writeln('   • **Kelebihan:** Sangat cepat dipasang, tidak butuh tiang/ODP kabel fiber.');
    sb.writeln('   • **Kapan Ditawarkan:** Lokasi belum tercover jaringan kabel optik FTTH tapi sinyal 4G/5G bagus (RSRP > -95 dBm).');
    sb.writeln('   • **Contoh Paket:** ${fwaSample.title} (${_currencyFmt.format(fwaSample.price)}/bln)\n');

    sb.writeln('2. **XL SATU FTTH (Fiber To The Home):**');
    sb.writeln('   • **Teknologi:** Menggunakan kabel serat optik dari tiang ODP ke dalam rumah.');
    sb.writeln('   • **Kelebihan:** True Unlimited murni tanpa batas FUP, ping sangat rendah untuk gaming & video call.');
    sb.writeln('   • **Kapan Ditawarkan:** Lokasi masuk radius jangkauan ODP / tiang kabel XL Satu.');
    sb.writeln('   • **Contoh Paket:** ${ftthSample.title} (${_currencyFmt.format(ftthSample.price)}/bln)\n');

    sb.writeln('💡 **Aturan Penjualan Resmi:** Jika lokasi rumah tercover ODP FTTH, wajib tawarkan FTTH terlebih dahulu!');

    final actions = [
      const QuickAction(
        label: 'Daftar Paket FWA',
        intent: 'package_list',
        args: {'type': 'fwa'},
      ),
      const QuickAction(
        label: 'Daftar Paket FTTH',
        intent: 'package_list',
        args: {'type': 'ftth'},
      ),
      const QuickAction(
        label: 'Rekomendasi Paket Sinyal',
        intent: 'rf_analyze',
      ),
    ];

    return (
      text: sb.toString().trim(),
      actions: actions,
      metadata: {'topic': 'fwa_vs_ftth'},
    );
  }
}
