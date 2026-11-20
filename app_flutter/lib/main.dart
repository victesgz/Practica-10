import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';

void main() {
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SubirFotoScreen(),
    ),
  );
}

class SubirFotoScreen extends StatefulWidget {
  const SubirFotoScreen({super.key});

  @override
  State<SubirFotoScreen> createState() => _SubirFotoScreenState();
}

class _SubirFotoScreenState extends State<SubirFotoScreen> {
  // En Web/Windows usa 127.0.0.1:8000; en emulador Android usa 10.0.2.2:8000
  String get apiUrl => kIsWeb
      ? 'http://127.0.0.1:8000/fotos'
      : 'http://10.0.2.2:8000/fotos';

  final TextEditingController _descripcionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  Uint8List? _imagenBytes;
  String? _nombreArchivo;
  String? _mimeType;
  bool _subiendo = false;

  MediaType _resolverMediaType({String? mimeType, required String nombreArchivo}) {
    final cleanMime = mimeType?.toLowerCase().trim();
    if (cleanMime != null && cleanMime.contains('/')) {
      final partes = cleanMime.split('/');
      if (partes.length == 2 && partes[0].isNotEmpty && partes[1].isNotEmpty) {
        return MediaType(partes[0], partes[1]);
      }
    }

    final lower = nombreArchivo.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    if (lower.endsWith('.gif')) return MediaType('image', 'gif');
    return MediaType('image', 'jpeg');
  }

  Future<void> _tomarFoto() async {
    final XFile? foto = await _picker.pickImage(source: ImageSource.camera);
    if (foto != null) {
      final bytes = await foto.readAsBytes();
      setState(() {
        _imagenBytes = bytes;
        _nombreArchivo = foto.name.isNotEmpty ? foto.name : 'foto.jpg';
        _mimeType = foto.mimeType;
      });
    }
  }

  Future<void> _subirFoto() async {
    final descripcion = _descripcionController.text.trim();

    if (_imagenBytes == null) {
      _mostrarMensaje('No hay imagen seleccionada');
      return;
    }
    if (descripcion.isEmpty) {
      _mostrarMensaje('Escribe una descripción');
      return;
    }

    setState(() => _subiendo = true);

    try {
      final nombre = _nombreArchivo ?? 'foto.jpg';
      final mediaType = _resolverMediaType(
        mimeType: _mimeType,
        nombreArchivo: nombre,
      );

      final request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.fields['descripcion'] = descripcion;
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _imagenBytes!,
          filename: nombre,
          contentType: mediaType,
        ),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200 || response.statusCode == 201) {
        _mostrarMensaje('Foto subida correctamente');
        setState(() {
          _imagenBytes = null;
          _nombreArchivo = null;
          _mimeType = null;
          _descripcionController.clear();
        });
      } else {
        _mostrarMensaje('Error al subir (${response.statusCode}): ${response.body}');
      }
    } catch (e) {
      _mostrarMensaje('Error de conexión: $e');
    } finally {
      if (mounted) {
        setState(() => _subiendo = false);
      }
    }
  }

  void _mostrarMensaje(String texto) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto)),
    );
  }

  @override
  void dispose() {
    _descripcionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir Foto'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          children: [
            const SizedBox(height: 12),
            _imagenBytes == null
                ? const Text(
                    'No hay imagen seleccionada',
                    style: TextStyle(fontSize: 16),
                  )
                : ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.memory(
                      _imagenBytes!,
                      height: 180,
                      fit: BoxFit.cover,
                    ),
                  ),
            const SizedBox(height: 24),
            TextField(
              controller: _descripcionController,
              decoration: const InputDecoration(
                labelText: 'Descripción',
                border: UnderlineInputBorder(),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _subiendo ? null : _tomarFoto,
              child: const Text('Tomar Foto'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: _subiendo ? null : _subirFoto,
              child: Text(_subiendo ? 'Subiendo...' : 'Subir a API'),
            ),
          ],
        ),
      ),
    );
  }
}