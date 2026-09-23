class SaRecord {
  final int? id;
  final String idPelanggan;
  final String nama;
  final String noHpUtama;
  final String noHpAlternatif;
  final String alamat;
  final double? latitude;
  final double? longitude;
  final String paket;
  final String tanggalPasang;

  SaRecord({
    this.id,
    required this.idPelanggan,
    required this.nama,
    this.noHpUtama = '',
    this.noHpAlternatif = '',
    required this.alamat,
    this.latitude,
    this.longitude,
    required this.paket,
    required this.tanggalPasang,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_pelanggan': idPelanggan,
      'nama': nama,
      'no_hp_utama': noHpUtama,
      'no_hp_alternatif': noHpAlternatif,
      'alamat': alamat,
      'latitude': latitude,
      'longitude': longitude,
      'paket': paket,
      'tanggal_pasang': tanggalPasang,
    };
  }

  factory SaRecord.fromMap(Map<String, dynamic> map) {
    return SaRecord(
      id: map['id'] as int?,
      idPelanggan: map['id_pelanggan'] as String,
      nama: map['nama'] as String,
      noHpUtama: (map['no_hp_utama'] as String?) ?? '',
      noHpAlternatif: (map['no_hp_alternatif'] as String?) ?? '',
      alamat: map['alamat'] as String,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      paket: map['paket'] as String,
      tanggalPasang: map['tanggal_pasang'] as String,
    );
  }

  bool get hasLocation => latitude != null && longitude != null;
}
