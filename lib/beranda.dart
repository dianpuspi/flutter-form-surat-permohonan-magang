import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FormSuratMagang extends StatefulWidget {
  const FormSuratMagang({super.key});

  @override
  State<FormSuratMagang> createState() => _FormSuratMagangState();
}

class _FormSuratMagangState extends State<FormSuratMagang> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _tempatMagangController = TextEditingController();
  
  // Controllers untuk nama dan NPM mahasiswa
  final List<TextEditingController> _namaControllers = List.generate(4, (_) => TextEditingController());
  final List<TextEditingController> _npmControllers = List.generate(4, (_) => TextEditingController());
  
  int _jumlahAnggota = 1;
  String? _selectedProdi;
  String? _selectedKaprodi;
  String? _selectedNPP;

  // Variabel untuk edit
  int? _editingIndex;

  // Hanya menyertakan 3 program studi
  final List<String> _prodiList = [
    'Teknik Sipil',
    'Informatika',
    'Teknologi Pangan',
  ];

  final Map<String, Map<String, String>> _kaprodiData = {
    'Dr. Ikhwanudin, S.T., M.T.': {'npp': '146901439'},
    'Bambang Agus Herlambang, S.Kom., M.Kom.': {'npp': '148201433'},
    'Fafa Nurdyansyah, S.TP., M.Sc.': {'npp': '158901487'},
  };

  List<Map<String, dynamic>> _submissions = [];
  static const String _prefsKey = 'magang_submissions';

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _tempatMagangController.dispose();
    for (var controller in _namaControllers) {
      controller.dispose();
    }
    for (var controller in _npmControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String>? raw = prefs.getStringList(_prefsKey);
    if (raw != null) {
      setState(() {
        _submissions = raw.map((s) => jsonDecode(s) as Map<String, dynamic>).toList();
      });
    }
  }

  Future<void> _saveAll() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> raw = _submissions.map((m) => jsonEncode(m)).toList();
    await prefs.setStringList(_prefsKey, raw);
  }

  void _submitForm() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final email = _emailController.text.trim();
    final tempatMagang = _tempatMagangController.text.trim();

    List<Map<String, String>> mahasiswaList = [];
    for (int i = 0; i < _jumlahAnggota; i++) {
      mahasiswaList.add({
        'nama': _namaControllers[i].text.trim(),
        'npm': _npmControllers[i].text.trim(),
      });
    }

    final submission = {
      'email': email,
      'tempatMagang': tempatMagang,
      'jumlahAnggota': _jumlahAnggota,
      'mahasiswa': mahasiswaList,
      'prodi': _selectedProdi ?? '-',
      'kaprodi': _selectedKaprodi ?? '-',
      'npp': _selectedNPP ?? '-',
      'createdAt': _editingIndex != null ? _submissions[_editingIndex!]['createdAt'] : DateTime.now().toIso8601String(),
      // Hanya tambahkan updatedAt jika sedang edit
      'updatedAt': _editingIndex != null ? DateTime.now().toIso8601String() : null,
    };

    setState(() {
      if (_editingIndex != null) {
        _submissions[_editingIndex!] = submission;
        _editingIndex = null;
      } else {
        _submissions.insert(0, submission);
      }
    });

    _saveAll();

    // Reset form
    _resetForm();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_editingIndex != null ? 'Permohonan berhasil diperbarui!' : 'Permohonan berhasil diajukan!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _emailController.clear();
    _tempatMagangController.clear();
    for (var controller in _namaControllers) {
      controller.clear();
    }
    for (var controller in _npmControllers) {
      controller.clear();
    }
    setState(() {
      _jumlahAnggota = 1;
      _selectedProdi = null;
      _selectedKaprodi = null;
      _selectedNPP = null;
      _editingIndex = null;
    });
  }

  void _loadFormForEdit(int index) {
    final item = _submissions[index];
    
    // Reset form terlebih dahulu
    _resetForm();
    
    // Load data dari item yang dipilih
    _emailController.text = item['email'];
    _tempatMagangController.text = item['tempatMagang'];
    _jumlahAnggota = item['jumlahAnggota'];
    _selectedProdi = item['prodi'];
    _selectedKaprodi = item['kaprodi'];
    _selectedNPP = item['npp'];
    
    // Load data mahasiswa
    final mahasiswaList = item['mahasiswa'] as List<dynamic>;
    for (int i = 0; i < mahasiswaList.length; i++) {
      if (i < _namaControllers.length) {
        _namaControllers[i].text = mahasiswaList[i]['nama'];
        _npmControllers[i].text = mahasiswaList[i]['npm'];
      }
    }
    
    setState(() {
      _editingIndex = index;
    });
    
    // Scroll ke atas form
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final scrollController = PrimaryScrollController.of(context);
      scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _removeSubmission(int index) async {
    
    // Konfirmasi hapus
    bool confirmDelete = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Hapus'),
        content: const Text('Apakah Anda yakin ingin menghapus permohonan ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    ) ?? false;

    if (confirmDelete) {
      setState(() {
        _submissions.removeAt(index);
      });
      await _saveAll();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Permohonan berhasil dihapus'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showDetail(int index) {
    final item = _submissions[index];
    final mahasiswaList = item['mahasiswa'] as List<dynamic>;
    
    String mahasiswaText = '';
    for (int i = 0; i < mahasiswaList.length; i++) {
      final mhs = mahasiswaList[i];
      mahasiswaText += 'Mahasiswa ${i + 1}:\n'
          '  Nama: ${mhs['nama']}\n'
          '  NPM: ${mhs['npm']}\n\n';
    }

    // Siapkan teks detail
    String detailText = 'Email: ${item['email']}\n\n'
        'Tempat Magang: ${item['tempatMagang']}\n\n'
        'Jumlah Anggota: ${item['jumlahAnggota']} orang\n\n'
        '$mahasiswaText'
        'Program Studi: ${item['prodi']}\n'
        'Kaprodi: ${item['kaprodi']}\n'
        'NPP Kaprodi: ${item['npp']}\n\n'
        'Diajukan: ${item['createdAt']}';
    
    // Tambahkan updatedAt hanya jika ada
    if (item['updatedAt'] != null) {
      detailText += '\nDiperbarui: ${item['updatedAt']}';
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Detail Permohonan'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(detailText),
            ],
          ),
        ),
        actions: [
          // Tombol Edit
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _loadFormForEdit(index);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.blue,
            ),
            child: const Text('Edit'),
          ),
          
          // Tombol Hapus
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _removeSubmission(index);
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Hapus'),
          ),
          
          // Tombol Tutup
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Permohonan Surat Magang',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1976D2), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editingIndex != null ? 'Edit Permohonan' : 'Formulir Pengajuan',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _editingIndex != null ? Colors.orange.shade800 : Colors.blue.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Lengkapi data di bawah ini dengan benar',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        
                        // Email
                        _buildSectionTitle('1. Email Mahasiswa'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _buildInputDecoration(
                            'Email Aktif',
                            Icons.email_outlined,
                            'contoh@email.com',
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Email wajib diisi';
                            }
                            if (!value.contains('@')) {
                              return 'Format email tidak valid';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Tempat Magang
                        _buildSectionTitle('2. Tempat Magang yang Dituju'),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _tempatMagangController,
                          decoration: _buildInputDecoration(
                            'Nama Instansi Lengkap',
                            Icons.business_outlined,
                            'Masukkan nama instansi lengkap',
                          ),
                          maxLines: 2,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Tempat magang wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Jumlah Anggota
                        _buildSectionTitle('3. Jumlah Anggota Kelompok'),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            for (int i = 1; i <= 4; i++)
                              Expanded(
                                child: Padding(
                                  padding: EdgeInsets.only(right: i < 4 ? 8 : 0),
                                  child: _buildAnggotaButton(i),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Data Mahasiswa
                        _buildSectionTitle('4. Data Mahasiswa'),
                        const SizedBox(height: 8),
                        ..._buildMahasiswaFields(),
                        const SizedBox(height: 12),

                        // Program Studi
                        _buildSectionTitle('5. Program Studi'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _selectedProdi,
                          decoration: _buildInputDecoration(
                            'Pilih Program Studi',
                            Icons.school_outlined,
                            null,
                          ),
                          items: _prodiList.map((prodi) {
                            return DropdownMenuItem(
                              value: prodi,
                              child: Text(prodi),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedProdi = value;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Program studi wajib dipilih';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Kaprodi
                        _buildSectionTitle('6. Ketua Program Studi'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          value: _selectedKaprodi,
                          decoration: _buildInputDecoration(
                            'Pilih Kaprodi',
                            Icons.person_outline,
                            null,
                          ),
                          items: _kaprodiData.keys.map((kaprodi) {
                            return DropdownMenuItem(
                              value: kaprodi,
                              child: Text(
                                kaprodi,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedKaprodi = value;
                              _selectedNPP = value != null ? _kaprodiData[value]!['npp'] : null;
                            });
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Kaprodi wajib dipilih';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        
                        // NPP Info
                        if (_selectedNPP != null)
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  'NPP Kaprodi: $_selectedNPP',
                                  style: TextStyle(
                                    color: Colors.blue.shade900,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 12),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _editingIndex != null ? Colors.orange.shade700 : Colors.blue.shade700,
                              foregroundColor: Colors.white,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(_editingIndex != null ? Icons.save : Icons.send_rounded),
                                const SizedBox(width: 8),
                                Text(
                                  _editingIndex != null ? 'Simpan Perubahan' : 'Ajukan Permohonan',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        // Tombol Batal Edit
                        if (_editingIndex != null) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: OutlinedButton(
                              onPressed: () {
                                _resetForm();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Edit dibatalkan'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey.shade700,
                                side: BorderSide(color: Colors.grey.shade300),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.close),
                                  SizedBox(width: 8),
                                  Text(
                                    'Batal Edit',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 12),

              // Daftar Pengajuan
              Text(
                'Riwayat Pengajuan',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade800,
                ),
              ),
              const SizedBox(height: 12),
              
              _submissions.isEmpty
                  ? Card(
                      elevation: 1,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 64,
                                color: Colors.grey.shade400,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Belum ada pengajuan',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _submissions.length,
                      itemBuilder: (context, index) {
                        final item = _submissions[index];
                        final mahasiswaList = item['mahasiswa'] as List<dynamic>;
                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: InkWell(
                            onTap: () => _showDetail(index),
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.blue.shade50,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(
                                          Icons.description_outlined,
                                          color: Colors.blue.shade700,
                                          size: 24,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item['tempatMagang'],
                                              style: const TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              mahasiswaList[0]['nama'],
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      _buildInfoChip(
                                        Icons.people_outline,
                                        '${item['jumlahAnggota']} orang',
                                        Colors.green,
                                      ),
                                      const SizedBox(width: 8),
                                      _buildInfoChip(
                                        Icons.school_outlined,
                                        item['prodi'],
                                        Colors.orange,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey.shade800,
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon, String? hint) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 13),
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12),
      prefixIcon: Icon(icon, color: Colors.blue.shade700, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
    );
  }

  Widget _buildAnggotaButton(int jumlah) {
    final isSelected = _jumlahAnggota == jumlah;
    return InkWell(
      onTap: () {
        setState(() {
          _jumlahAnggota = jumlah;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue.shade700 : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.blue.shade700 : Colors.grey.shade300,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Icon(
              Icons.person,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 24,
            ),
            const SizedBox(height: 2),
            Text(
              '$jumlah',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildMahasiswaFields() {
    List<Widget> fields = [];
    for (int i = 0; i < _jumlahAnggota; i++) {
      fields.add(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade700,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Mahasiswa ${i + 1}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _namaControllers[i],
                decoration: _buildInputDecoration(
                  'Nama Lengkap',
                  Icons.person_outline,
                  'Masukkan nama lengkap',
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Nama mahasiswa ${i + 1} wajib diisi';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _npmControllers[i],
                decoration: _buildInputDecoration(
                  'NPM',
                  Icons.badge_outlined,
                  'Masukkan NPM',
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'NPM mahasiswa ${i + 1} wajib diisi';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
      );
    }
    return fields;
  }

  Widget _buildInfoChip(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color.shade700),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color.shade900,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

extension on Color {
  Color? get shade700 => null;
  
  Color? get shade900 => null;
}