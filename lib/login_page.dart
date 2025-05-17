import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool _isLogin = true;
  bool _isLoading = false;

  final _auth = FirebaseAuth.instance;

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final email = emailController.text.trim();
    final password = passwordController.text.trim();

    try {
      if (_isLogin) {
        final credential = await _auth.signInWithEmailAndPassword(email: email, password: password);
        await _postLogin(credential.user);
      } else {
        final confirmPassword = confirmPasswordController.text.trim();
        if (password != confirmPassword) {
          _showSnackBar('Passwords do not match!');
          setState(() => _isLoading = false);
          return;
        }

        final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
        await FirebaseFirestore.instance.collection('users').doc(credential.user?.uid).set({'isAdmin': false});
        _showSnackBar('Account created. Please login.');
        setState(() => _isLogin = true);
      }
    } on FirebaseAuthException catch (e) {
      _showSnackBar(e.message ?? 'Authentication failed');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _postLogin(User? user) async {
    if (user == null) {
      _showSnackBar('Login failed');
      return;
    }

    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final isAdmin = doc.data()?['isAdmin'] == true;

    Navigator.pushReplacementNamed(context, isAdmin ? '/adminDashboard' : '/userDashboard');
  }

  Future<void> _signInWithGoogle() async {
    setState(() => _isLoading = true);
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        _showSnackBar('Google sign-in canceled');
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(idToken: googleAuth.idToken, accessToken: googleAuth.accessToken);
      final userCred = await _auth.signInWithCredential(credential);

      final doc = await FirebaseFirestore.instance.collection('users').doc(userCred.user?.uid).get();
      if (!doc.exists) {
        await FirebaseFirestore.instance.collection('users').doc(userCred.user?.uid).set({'isAdmin': false});
      }

      await _postLogin(userCred.user);
    } catch (e) {
      _showSnackBar('Google login failed');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isLogin ? 'Login' : 'Sign Up')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) => (value == null || !value.contains('@')) ? 'Enter valid email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) => (value == null || value.length < 6) ? 'Minimum 6 characters' : null,
                  ),
                  if (!_isLogin)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextFormField(
                        controller: confirmPasswordController,
                        decoration: const InputDecoration(labelText: 'Confirm Password'),
                        obscureText: true,
                        validator: (value) => (value == null || value.length < 6) ? 'Confirm your password' : null,
                      ),
                    ),
                  const SizedBox(height: 20),
                  _isLoading
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    onPressed: _handleSubmit,
                    child: Text(_isLogin ? 'Login' : 'Sign Up'),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? 'Create new account' : 'I already have an account'),
                  ),
                  const Divider(height: 32),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.login, color: Colors.red),
                    label: const Text('Sign in with Google'),
                    onPressed: _isLoading ? null : _signInWithGoogle,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
