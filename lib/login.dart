import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final supabase = Supabase.instance.client;
  String selectedRole = 'visitante';
  bool isLogin = true;
  File? selectedImage;
  Uint8List? webImage;
  String? selectedImageName;
  final ImagePicker _picker = ImagePicker();
  bool isUploading = false;

  Future<void> pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );
      
      if (image != null) {
        if (kIsWeb) {
          // Para web, usar bytes
          final bytes = await image.readAsBytes();
          setState(() {
            webImage = bytes;
            selectedImageName = image.name;
            selectedImage = null;
          });
        } else {
          // Para móvil, usar File
          setState(() {
            selectedImage = File(image.path);
            webImage = null;
            selectedImageName = image.name;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al seleccionar imagen: $e')),
      );
    }
  }

  Future<String?> uploadImage() async {
    if (selectedImage == null && webImage == null) return null;
    
    try {
      Uint8List bytes;
      String fileName;
      
      if (kIsWeb && webImage != null) {
        // Para web
        bytes = webImage!;
        fileName = '${DateTime.now().millisecondsSinceEpoch}_${emailController.text}_${selectedImageName ?? 'image'}.jpg';
      } else if (selectedImage != null) {
        // Para móvil
        bytes = await selectedImage!.readAsBytes();
        fileName = '${DateTime.now().millisecondsSinceEpoch}_${emailController.text}.jpg';
      } else {
        return null;
      }
      
      await supabase.storage
          .from('perfilfoto')
          .uploadBinary(fileName, bytes);
      
      final imageUrl = supabase.storage
          .from('perfilfoto')
          .getPublicUrl(fileName);
      
      return imageUrl;
    } catch (e) {
      throw Exception('Error al subir imagen: $e');
    }
  }

  Future<void> login() async {
    try {
      setState(() {
        isUploading = true;
      });
      
      // Verificar credenciales en la tabla perfilesfoto
      final response = await supabase
          .from('perfilesfoto')
          .select('email, password, role, url')
          .eq('email', emailController.text)
          .eq('password', passwordController.text)
          .eq('role', selectedRole)
          .maybeSingle();

      if (response != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bienvenido, ${response['role']}')),
        );
        
        // Navegar a TurismoPage pasando el rol del usuario y el email
        Navigator.pushReplacementNamed(
          context, 
          '/turismo',
          arguments: {
            'userRole': response['role'],
            'userEmail': response['email'],
            'profileImageUrl': response['url'],
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Credenciales incorrectas o rol no válido')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar sesión: $e')),
      );
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  Future<void> signup() async {
    try {
      setState(() {
        isUploading = true;
      });
      
      // Verificar si el email ya existe
      final existingUser = await supabase
          .from('perfilesfoto')
          .select('email')
          .eq('email', emailController.text)
          .maybeSingle();

      if (existingUser != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Este email ya está registrado')),
        );
        return;
      }

      // Subir imagen si se seleccionó una
      String? imageUrl;
      if (selectedImage != null || webImage != null) {
        imageUrl = await uploadImage();
      }

      // Insertar nuevo usuario en la tabla perfilesfoto
      await supabase.from('perfilesfoto').insert({
        'email': emailController.text,
        'password': passwordController.text,
        'role': selectedRole,
        'url': imageUrl,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cuenta creada exitosamente')),
      );
      
      setState(() {
        isLogin = true;
        emailController.clear();
        passwordController.clear();
        selectedImage = null;
        webImage = null;
        selectedImageName = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al registrarse: $e')),
      );
    } finally {
      setState(() {
        isUploading = false;
      });
    }
  }

  Widget _buildImagePreview() {
    if (kIsWeb && webImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          webImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    } else if (selectedImage != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          selectedImage!,
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
        ),
      );
    } else {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person, size: 50, color: Colors.grey),
            SizedBox(height: 8),
            Text('Foto de perfil (opcional)'),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isLogin ? 'Iniciar Sesión' : 'Registrarse'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Contraseña'),
                obscureText: true,
              ),
              const SizedBox(height: 16),
              
              // Selector de rol
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: const InputDecoration(labelText: 'Rol'),
                items: const [
                  DropdownMenuItem(value: 'visitante', child: Text('Visitante')),
                  DropdownMenuItem(value: 'publicador', child: Text('Publicador')),
                ],
                onChanged: (value) {
                  setState(() {
                    selectedRole = value!;
                  });
                },
              ),
              
              // Selector de imagen (solo en modo registro)
              if (!isLogin) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 200,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _buildImagePreview(),
                ),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: pickImage,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Seleccionar imagen'),
                ),
              ],
              
              const SizedBox(height: 24),
              
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isUploading ? null : (isLogin ? login : signup),
                  child: isUploading
                      ? const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Procesando...'),
                          ],
                        )
                      : Text(isLogin ? 'Iniciar Sesión' : 'Registrarse'),
                ),
              ),
              
              const SizedBox(height: 16),
              
              TextButton(
                onPressed: isUploading ? null : () {
                  setState(() {
                    isLogin = !isLogin;
                    emailController.clear();
                    passwordController.clear();
                    selectedImage = null;
                    webImage = null;
                    selectedImageName = null;
                  });
                },
                child: Text(
                  isLogin 
                    ? '¿No tienes cuenta? Regístrate' 
                    : '¿Ya tienes cuenta? Inicia sesión'
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}