import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class TurismoPage extends StatefulWidget {
  const TurismoPage({super.key});

  @override
  State<TurismoPage> createState() => _TurismoPageState();
}

class _TurismoPageState extends State<TurismoPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _ubicacionController = TextEditingController();
  final _resenaController = TextEditingController();
  final _descripcionController = TextEditingController();
  
  Uint8List? _imageBytes;
  String? _imageName;
  bool _isLoading = false;
  String userRole = 'visitante';
  String userEmail = '';
  List<dynamic> lugares = [];
  Position? _currentPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      userRole = args['userRole'] ?? 'visitante';
      userEmail = args['userEmail'] ?? '';
    }
    _loadLugares();
    if (userRole == 'publicador') {
      _getCurrentLocation();
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Los servicios de ubicación están deshabilitados')),
        );
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Permisos de ubicación denegados')),
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Los permisos de ubicación están permanentemente denegados')),
        );
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high
      );
      
      setState(() {
        _currentPosition = position;
        _ubicacionController.text = 'https://www.google.com/maps/search/?api=1&query=${position.latitude},${position.longitude}';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ubicación obtenida exitosamente')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al obtener ubicación: $e')),
      );
    }
  }



  Future<void> _loadLugares() async {
    try {
      final response = await supabase
          .from('lugares')
          .select('*')
          .order('created_at', ascending: false);
      
      setState(() {
        lugares = response;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar lugares: $e')),
      );
    }
  }

  Future<List<dynamic>> _loadComentarios(dynamic lugarId) async {
    try {
      final response = await supabase
          .from('comentarios')
          .select('*')
          .eq('lugar_id', lugarId.toString())
          .order('created_at', ascending: false);
      
      return response;
    } catch (e) {
      throw Exception('Error al cargar comentarios: $e');
    }
  }

  Future<void> _agregarComentario(dynamic lugarId, String comentario) async {
    try {
      if (userEmail.isEmpty) {
        throw Exception('Email de usuario no disponible');
      }
      
      await supabase.from('comentarios').insert({
        'lugar_id': lugarId.toString(),
        'usuario_email': userEmail,
        'comentario': comentario,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comentario agregado exitosamente')),
      );
    } catch (e) {
      throw Exception('Error al agregar comentario: $e');
    }
  }

  void _showComentariosDialog(dynamic lugarId, String nombreLugar) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: MediaQuery.of(context).size.height * 0.7,
            child: ComentariosView(
              lugarId: lugarId,
              nombreLugar: nombreLugar,
              userEmail: userEmail,
              userRole: userRole,
              onAgregarComentario: _agregarComentario,
              loadComentarios: _loadComentarios,
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List> _resizeImage(Uint8List imageBytes) async {
    final image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('No se pudo procesar la imagen');
    
    final resized = img.copyResize(image, width: 1080, height: 1350);
    return Uint8List.fromList(img.encodeJpg(resized, quality: 85));
  }

  Future<void> _pickImageFromGallery() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.gallery);
    
    if (result != null) {
      final bytes = await result.readAsBytes();
      final resizedBytes = await _resizeImage(bytes);
      
      setState(() {
        _imageBytes = resizedBytes;
        _imageName = result.name;
      });
    }
  }

  Future<void> _pickImageFromCamera() async {
    final picker = ImagePicker();
    final result = await picker.pickImage(source: ImageSource.camera);
    
    if (result != null) {
      final bytes = await result.readAsBytes();
      final resizedBytes = await _resizeImage(bytes);
      
      setState(() {
        _imageBytes = resizedBytes;
        _imageName = 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
      });
    }
  }

  void _showImagePickerDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Seleccionar imagen'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Galería'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Cámara'),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromCamera();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<String?> _uploadImage() async {
    if (_imageBytes == null || _imageName == null) return null;

    try {
      final fileName = 'lugares/${DateTime.now().millisecondsSinceEpoch}_$_imageName';
      await supabase.storage.from('uploads').uploadBinary(fileName, _imageBytes!);
      
      final imageUrl = supabase.storage.from('uploads').getPublicUrl(fileName);
      return imageUrl;
    } catch (e) {
      throw Exception('Error al subir imagen: $e');
    }
  }

  Future<void> _guardarLugar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_imageBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona una imagen')),
      );
      return;
    }
    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Obteniendo ubicación...')),
      );
      await _getCurrentLocation();
      if (_currentPosition == null) return;
    }

    setState(() => _isLoading = true);

    try {
      final imageUrl = await _uploadImage();
      
      // Crear enlace de Google Maps con las coordenadas
      final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=${_currentPosition!.latitude},${_currentPosition!.longitude}';
      
      await supabase.from('lugares').insert({
        'nombre': _nombreController.text,
        'ubicacion': googleMapsUrl,
        'resena': _resenaController.text,
        'descripcion': _descripcionController.text,
        'url_imagen': imageUrl,
        'latitude': _currentPosition!.latitude,
        'longitude': _currentPosition!.longitude,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lugar turístico agregado exitosamente')),
      );

      _formKey.currentState!.reset();
      _nombreController.clear();
      _ubicacionController.clear();
      _resenaController.clear();
      _descripcionController.clear();
      setState(() {
        _imageBytes = null;
        _imageName = null;
      });
      
      _loadLugares();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildLugarCard(Map<String, dynamic> lugar) {
    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (lugar['url_imagen'] != null)
            Container(
              height: 200,
              width: double.infinity,
              child: Image.network(
                lugar['url_imagen'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.error, size: 50),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lugar['nombre'] ?? 'Sin nombre',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.red),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          if (lugar['ubicacion'] != null && lugar['ubicacion'].toString().startsWith('http')) {
                            if (await canLaunchUrl(Uri.parse(lugar['ubicacion']))) {
                              await launchUrl(Uri.parse(lugar['ubicacion']), mode: LaunchMode.externalApplication);
                            }
                          }
                        },
                        child: Text(
                          lugar['ubicacion']?.toString().startsWith('http') == true 
                              ? 'Ver ubicación en Google Maps'
                              : lugar['ubicacion'] ?? 'Sin ubicación',
                          style: TextStyle(
                            color: lugar['ubicacion']?.toString().startsWith('http') == true 
                                ? Colors.blue 
                                : Colors.grey,
                            decoration: lugar['ubicacion']?.toString().startsWith('http') == true 
                                ? TextDecoration.underline 
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  lugar['resena'] ?? 'Sin reseña',
                  style: const TextStyle(
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  lugar['descripcion'] ?? 'Sin descripción',
                  style: const TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (lugar['ubicacion'] != null && lugar['ubicacion'].toString().startsWith('http'))
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (await canLaunchUrl(Uri.parse(lugar['ubicacion']))) {
                            await launchUrl(Uri.parse(lugar['ubicacion']), mode: LaunchMode.externalApplication);
                          }
                        },
                        icon: const Icon(Icons.map, size: 16),
                        label: const Text('Ver en Maps'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ElevatedButton.icon(
                      onPressed: () => _showComentariosDialog(
                        lugar['id'],
                        lugar['nombre'] ?? 'Lugar',
                      ),
                      icon: const Icon(Icons.comment, size: 16),
                      label: const Text('Comentarios'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPublisherView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '¡Bienvenido, Publicador!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Center(
            child: ElevatedButton.icon(
              onPressed: () => logout(context),
              icon: const Icon(Icons.logout),
              label: const Text('Cerrar Sesión'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          // Información de ubicación
          if (_currentPosition != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green),
              ),
              child: Row(
                children: [
                  const Icon(Icons.location_on, color: Colors.green),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Ubicación obtenida: ${_currentPosition!.latitude.toStringAsFixed(4)}, ${_currentPosition!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.orange),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Obteniendo ubicación GPS...',
                      style: TextStyle(color: Colors.orange),
                    ),
                  ),
                  TextButton(
                    onPressed: _getCurrentLocation,
                    child: const Text('Reintentar'),
                  ),
                ],
              ),
            ),
          
          const SizedBox(height: 20),
          const Text(
            'Agregar Nuevo Lugar Turístico',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          // Formulario existente...
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nombreController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del lugar',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa el nombre';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _ubicacionController,
                  decoration: const InputDecoration(
                    labelText: 'Ubicación (Google Maps)',
                    border: OutlineInputBorder(),
                    helperText: 'Se generará automáticamente con GPS',
                  ),
                  readOnly: true,
                  validator: (value) {
                    if (_currentPosition == null) {
                      return 'Se requiere ubicación GPS';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _resenaController,
                  decoration: const InputDecoration(
                    labelText: 'Reseña',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa una reseña';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                TextFormField(
                  controller: _descripcionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Por favor ingresa una descripción';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _imageBytes != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            _imageBytes!,
                            fit: BoxFit.cover,
                          ),
                        )
                      : InkWell(
                          onTap: _showImagePickerDialog,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 50, color: Colors.grey),
                              SizedBox(height: 8),
                              Text(
                                'Toca para seleccionar imagen\n(1080 x 1350 píxeles)',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                ),
                
                if (_imageBytes != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(
                        onPressed: _showImagePickerDialog,
                        icon: const Icon(Icons.edit),
                        label: const Text('Cambiar imagen'),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _imageBytes = null;
                            _imageName = null;
                          });
                        },
                        icon: const Icon(Icons.delete),
                        label: const Text('Eliminar'),
                      ),
                    ],
                  ),
                ],
                
                const SizedBox(height: 24),
                
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _guardarLugar,
                    icon: _isLoading 
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save),
                    label: Text(_isLoading ? 'Guardando...' : 'Guardar Lugar'),
                    style: ElevatedButton.styleFrom(
                      textStyle: const TextStyle(fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          const Divider(),
          const SizedBox(height: 20),
          const Text(
            'Lugares Publicados',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          
          // Lista de lugares
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: lugares.length,
            itemBuilder: (context, index) {
              return _buildLugarCard(lugares[index]);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVisitorView() {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Text(
                '¡Bienvenido, Visitante!',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Explora los mejores destinos turísticos',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 15),
              ElevatedButton.icon(
                onPressed: () => logout(context),
                icon: const Icon(Icons.logout),
                label: const Text('Cerrar Sesión'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: lugares.isEmpty
              ? const Center(
                  child: Text(
                    'No hay lugares turísticos disponibles',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                )
              : ListView.builder(
                  itemCount: lugares.length,
                  itemBuilder: (context, index) {
                    return _buildLugarCard(lugares[index]);
                  },
                ),
        ),
      ],
    );
  }

  Future<void> logout(BuildContext context) async {
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Panel de Turismo - ${userRole.toUpperCase()}'),
        backgroundColor: userRole == 'publicador' ? Colors.green : Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: () => logout(context),
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
          ),
        ],
      ),
      body: userRole == 'publicador' ? _buildPublisherView() : _buildVisitorView(),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _ubicacionController.dispose();
    _resenaController.dispose();
    _descripcionController.dispose();
    super.dispose();
  }
}

// Widget para manejar comentarios
class ComentariosView extends StatefulWidget {
  final dynamic lugarId;
  final String nombreLugar;
  final String userEmail;
  final String userRole;
  final Function(dynamic, String) onAgregarComentario;
  final Future<List<dynamic>> Function(dynamic) loadComentarios;

  const ComentariosView({
    super.key,
    required this.lugarId,
    required this.nombreLugar,
    required this.userEmail,
    required this.userRole,
    required this.onAgregarComentario,
    required this.loadComentarios,
  });

  @override
  State<ComentariosView> createState() => _ComentariosViewState();
}

class _ComentariosViewState extends State<ComentariosView> {
  final _comentarioController = TextEditingController();
  List<dynamic> comentarios = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadComentarios();
  }

  Future<void> _loadComentarios() async {
    setState(() => _isLoading = true);
    try {
      final response = await widget.loadComentarios(widget.lugarId);
      setState(() {
        comentarios = response;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _agregarComentario() async {
    if (_comentarioController.text.trim().isEmpty) return;

    try {
      await widget.onAgregarComentario(widget.lugarId, _comentarioController.text);
      _comentarioController.clear();
      _loadComentarios();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppBar(
          title: Text('Comentarios - ${widget.nombreLugar}'),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : comentarios.isEmpty
                  ? const Center(
                      child: Text('No hay comentarios aún'),
                    )
                  : ListView.builder(
                      itemCount: comentarios.length,
                      itemBuilder: (context, index) {
                        final comentario = comentarios[index];
                        final userEmail = comentario['usuario_email'] ?? 'Usuario';
                        final emailInitial = userEmail.isNotEmpty ? userEmail[0].toUpperCase() : 'U';
                        
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(emailInitial),
                          ),
                          title: Text(userEmail),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(comentario['comentario'] ?? 'Sin comentario'),
                              const SizedBox(height: 4),
                              Text(
                                comentario['created_at'] != null 
                                    ? DateTime.parse(comentario['created_at']).toString().substring(0, 16)
                                    : 'Fecha no disponible',
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                            ],
                          ),
                          isThreeLine: true,
                        );
                      },
                    ),
        ),
        // Solo mostrar el campo de comentario si es publicador
        if (widget.userRole == 'publicador')
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _comentarioController,
                    decoration: const InputDecoration(
                      hintText: 'Escribe tu comentario...',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 2,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _agregarComentario,
                  icon: const Icon(Icons.send),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.grey[600]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Solo los publicadores pueden agregar comentarios',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    super.dispose();
  }
}