import 'package:flutter/material.dart';
import '../theme/landing_colors.dart';
import '../widgets/marketing_page_shell.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  bool _sent = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _sent = true);
    _nameCtrl.clear();
    _emailCtrl.clear();
    _messageCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return MarketingPageShell(
      title: 'Contact Us',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Get in touch',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w600, color: LandingColors.foreground)),
          const SizedBox(height: 12),
          const Text(
            'Questions about a request, becoming a field agent, or partnering with EBN? '
            'Send us a message and we\u2019ll get back to you.',
            style: TextStyle(fontSize: 15, color: LandingColors.muted, height: 1.6),
          ),
          const SizedBox(height: 32),
          _ContactInfoRow(icon: Icons.email_outlined, label: 'hello@ebn.et'),
          const SizedBox(height: 12),
          _ContactInfoRow(icon: Icons.phone_outlined, label: '+251 900 000 000'),
          const SizedBox(height: 12),
          _ContactInfoRow(icon: Icons.location_on_outlined, label: 'Addis Ababa, Ethiopia'),
          const SizedBox(height: 40),
          if (_sent)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: LandingColors.card,
                border: Border.all(color: LandingColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: const [
                  Icon(Icons.check_circle, color: LandingColors.gold),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Thanks \u2014 your message has been sent. This is a demo, so nothing is '
                      'actually delivered yet.',
                      style: TextStyle(fontSize: 14, color: LandingColors.foreground, height: 1.4),
                    ),
                  ),
                ],
              ),
            )
          else
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel('Name'),
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: _inputDecoration('Your full name'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter your name' : null,
                  ),
                  const SizedBox(height: 20),
                  _FieldLabel('Email'),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: _inputDecoration('you@example.com'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Please enter your email';
                      if (!v.contains('@')) return 'Please enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  _FieldLabel('Message'),
                  TextFormField(
                    controller: _messageCtrl,
                    decoration: _inputDecoration('How can we help?'),
                    maxLines: 5,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please enter a message' : null,
                  ),
                  const SizedBox(height: 28),
                  Material(
                    color: LandingColors.gold,
                    borderRadius: BorderRadius.circular(999),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: _submit,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                        child: Text('Send message',
                          style: TextStyle(color: LandingColors.goldFg, fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: LandingColors.muted),
      filled: true,
      fillColor: LandingColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LandingColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LandingColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LandingColors.gold, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel(this.label);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: LandingColors.foreground)),
    );
  }
}

class _ContactInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ContactInfoRow({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          height: 36, width: 36,
          decoration: BoxDecoration(
            color: LandingColors.card,
            border: Border.all(color: LandingColors.border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: LandingColors.gold),
        ),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(fontSize: 14, color: LandingColors.foreground)),
      ],
    );
  }
}
