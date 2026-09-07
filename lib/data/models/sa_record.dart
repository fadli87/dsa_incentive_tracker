class SaRecord {
  final int? id;
  final String idPelanggan;
  final String nama;
  final String noKtp;
  final String alamat;
  final String paket;
  final String tanggalPasang;

  SaRecord({
    this.id,
    required this.idPelanggan,
    required this.nama,
    required this.noKtp,
    required this.alamat,
    required this.paket,
    required this.tanggalPasang,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'id_pelanggan': idPelanggan,
      'nama': nama,
      'no_ktp': noKtp,
      'alamat': alamat,
      'paket': paket,
      'tanggal_pasang': tanggalPasang,
    };
  }

  factory SaRecord.fromMap(Map<String, dynamic> map) {
    return SaRecord(
      id: map['id'] as int?,
      idPelanggan: map['id_pelanggan'] as String,
      nama: map['nama'] as String,
      noKtp: map['no_ktp'] as String,
      alamat: map['alamat'] as String,
      paket: map['paket'] as String,
      tanggalPasang: map['tanggal_pasang'] as String,
    );
  }
}
