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
  
  // Nuevos controladores para publicaciones
  final _publicacionFormKey = GlobalKey<FormState>();
  final _mensajeController = TextEditingController();
  
  Uint8List? _imageBytes;
  String? _imageName;
  
  // Nueva variable para imagen de publicación
  Uint8List? _publicacionImageBytes;
  String? _publicacionImageName;
  
  bool _isLoading = false;
  bool _isPublicacionLoading = false;
  String userRole = 'visitante';
  String userEmail = '';
  String? profileImageUrl;
  List<dynamic> lugares = [];
  List<dynamic> publicaciones = [];
  Position? _currentPosition;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args != null) {
      userRole = args['userRole'] ?? 'visitante';
      userEmail = args['userEmail'] ?? '';
      profileImageUrl = args['profileImageUrl'];
    }
    _loadLugares();
    _loadPublicaciones();
    if (userRole == 'publicador') {
      _getCurrentLocation();
    }
  }

  // Nueva función para cargar publicaciones
  Future<void> _loadPublicaciones() async {
    try {
      final response = await supabase
          .from('publicaciones')
          .select('*')
          .order('created_at', ascending: false);
      
      setState(() {
        publicaciones = response;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar publicaciones: $e')),
      );
    }
  }

  // Nueva función para seleccionar imagen de publicación (galería o cámara)
  Future<void> _pickPublicacionImage() async {
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
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImageFromSource(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Cámara'),
                onTap: () async {
                  Navigator.pop(context);
                  await _pickImageFromSource(ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Nueva función para manejar ambas fuentes (galería y cámara)
  Future<void> _pickImageFromSource(ImageSource source) async {
    final picker = ImagePicker();
    final result = await picker.pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 80,
    );
    
    if (result != null) {
      final bytes = await result.readAsBytes();
      final resizedBytes = await _resizeImage(bytes);
      
      setState(() {
        _publicacionImageBytes = resizedBytes;
        _publicacionImageName = source == ImageSource.camera 
            ? 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg'
            : result.name;
      });
    }
  }

  // Nueva función para subir imagen de publicación
  Future<String?> _uploadPublicacionImage() async {
    if (_publicacionImageBytes == null || _publicacionImageName == null) return null;

    try {
      final fileName = 'publicaciones/${DateTime.now().millisecondsSinceEpoch}_$_publicacionImageName';
      await supabase.storage.from('publicfotos').uploadBinary(fileName, _publicacionImageBytes!);
      
      final imageUrl = supabase.storage.from('publicfotos').getPublicUrl(fileName);
      return imageUrl;
    } catch (e) {
      throw Exception('Error al subir imagen de publicación: $e');
    }
  }

  // Nueva función para guardar publicación
  Future<void> _guardarPublicacion() async {
    if (!_publicacionFormKey.currentState!.validate()) return;

    setState(() => _isPublicacionLoading = true);

    try {
      String? imageUrl;
      if (_publicacionImageBytes != null) {
        imageUrl = await _uploadPublicacionImage();
      }

      await supabase.from('publicaciones').insert({
        'usuario': userEmail,
        'mensaje': _mensajeController.text,
        'url': imageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Publicación agregada exitosamente')),
      );

      _publicacionFormKey.currentState!.reset();
      _mensajeController.clear();
      setState(() {
        _publicacionImageBytes = null;
        _publicacionImageName = null;
      });
      
      _loadPublicaciones();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al guardar publicación: $e')),
      );
    } finally {
      setState(() => _isPublicacionLoading = false);
    }
  }

  // Función para mostrar diálogo de nueva publicación
  void _showPublicacionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Nueva Publicación'),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.8,
                child: Form(
                  key: _publicacionFormKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _mensajeController,
                        decoration: const InputDecoration(
                          labelText: 'Mensaje',
                          border: OutlineInputBorder(),
                          hintText: '¿Qué quieres compartir?',
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Por favor ingresa un mensaje';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Container(
                        width: double.infinity,
                        height: 150,
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _publicacionImageBytes != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  _publicacionImageBytes!,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : InkWell(
                                onTap: () async {
                                  await _pickPublicacionImage();
                                  setDialogState(() {});
                                },
                                child: const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo, size: 40, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text(
                                      'Toca para agregar imagen\n(Galería o Cámara)',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                      ),
                      if (_publicacionImageBytes != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton.icon(
                              onPressed: () async {
                                await _pickPublicacionImage();
                                setDialogState(() {});
                              },
                              icon: const Icon(Icons.edit),
                              label: const Text('Cambiar'),
                            ),
                            TextButton.icon(
                              onPressed: () {
                                setDialogState(() {
                                  _publicacionImageBytes = null;
                                  _publicacionImageName = null;
                                });
                              },
                              icon: const Icon(Icons.delete),
                              label: const Text('Eliminar'),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isPublicacionLoading ? null : () {
                    _mensajeController.clear();
                    setState(() {
                      _publicacionImageBytes = null;
                      _publicacionImageName = null;
                    });
                    Navigator.pop(context);
                  },
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: _isPublicacionLoading ? null : () async {
                    await _guardarPublicacion();
                    Navigator.pop(context);
                  },
                  child: _isPublicacionLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Publicar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Widget para mostrar una publicación
  Widget _buildPublicacionCard(Map<String, dynamic> publicacion) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con información del usuario
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  child: Text(
                    publicacion['usuario']?.toString().isNotEmpty == true 
                        ? publicacion['usuario'][0].toUpperCase() 
                        : 'U',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        publicacion['usuario'] ?? 'Usuario desconocido',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        publicacion['created_at'] != null 
                            ? DateTime.parse(publicacion['created_at']).toString().substring(0, 16)
                            : 'Fecha no disponible',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Mensaje
          if (publicacion['mensaje'] != null && publicacion['mensaje'].toString().isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                publicacion['mensaje'],
                style: const TextStyle(fontSize: 14),
              ),
            ),
          // Imagen si existe
          if (publicacion['url'] != null && publicacion['url'].toString().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 400),
              child: Image.network(
                publicacion['url'],
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.error, size: 50),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // Resto de las funciones existentes...
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
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Column(
          children: [
            Container(
              color: Colors.green,
              child: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(icon: Icon(Icons.feed), text: 'Publicaciones'),
                  Tab(icon: Icon(Icons.add_location), text: 'Lugares'),
                  Tab(icon: Icon(Icons.list), text: 'Mis Lugares'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab de Publicaciones
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Text(
                              '¡Bienvenido, Publicador!',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            const SizedBox(height: 10),
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
                        child: publicaciones.isEmpty
                            ? const Center(
                                child: Text(
                                  'No hay publicaciones aún',
                                  style: TextStyle(fontSize: 16, color: Colors.grey),
                                ),
                              )
                            : ListView.builder(
                                itemCount: publicaciones.length,
                                itemBuilder: (context, index) {
                                  return _buildPublicacionCard(publicaciones[index]);
                                },
                              ),
                      ),
                    ],
                  ),
                  // Tab de Agregar Lugares (contenido existente)
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Agregar Nuevo Lugar Turístico',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 20),
                        
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
                      ],
                    ),
                  ),
                  // Tab de Lugares Publicados
                  Column(
                    children: [
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Lugares Publicados',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: lugares.isEmpty
                            ? const Center(
                                child: Text(
                                  'No hay lugares publicados',
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
                  ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showPublicacionDialog,
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }

  Widget _buildVisitorView() {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: Column(
          children: [
            Container(
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
            Container(
              color: Colors.blue,
              child: const TabBar(
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(icon: Icon(Icons.feed), text: 'Publicaciones'),
                  Tab(icon: Icon(Icons.location_on), text: 'Lugares'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  // Tab de Publicaciones
                  publicaciones.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay publicaciones disponibles',
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: publicaciones.length,
                          itemBuilder: (context, index) {
                            return _buildPublicacionCard(publicaciones[index]);
                          },
                        ),
                  // Tab de Lugares
                  lugares.isEmpty
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
                ],
              ),
            ),
          ],
        ),
      ),
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
    _mensajeController.dispose();
    super.dispose();
  }
}

// Widget para manejar comentarios (sin cambios)
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