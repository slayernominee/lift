import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url)) {
      throw Exception('Could not launch $url');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('About Lift'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const SizedBox(height: 20),
            // App Logo
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Theme.of(context).colorScheme.surfaceVariant,
                      child: const Icon(Icons.fitness_center, size: 60),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Center(
              child: Text(
                'LIFT',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 4,
                ),
              ),
            ),
            const Center(
              child: Text(
                'Version 1.0.0',
                style: TextStyle(color: Colors.grey),
              ),
            ),
            const SizedBox(height: 48),

            // App Description
            const Text(
              'Your modern companion for fitness and strength tracking. Built with focus on speed, data visualization, and a clean user experience.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 1.5),
            ),
            const SizedBox(height: 48),

            // Source Code Card
            Card(
              child: ListTile(
                leading: const Icon(Icons.code),
                title: const Text('Source Code'),
                subtitle: const Text('View on GitHub'),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () => _launchURL('https://github.com/slayernominee/lift'),
              ),
            ),

            const SizedBox(height: 12),

            // Issues Card
            Card(
              child: ListTile(
                leading: const Icon(Icons.bug_report_outlined),
                title: const Text('Report Issues'),
                subtitle: const Text('Submit feedback or bugs'),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () => _launchURL('https://github.com/slayernominee/lift/issues'),
              ),
            ),

            const SizedBox(height: 12),

            // License Info
            Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: const Text('Licenses'),
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: 'Lift',
                  applicationVersion: '1.0.0',
                ),
              ),
            ),

            const SizedBox(height: 48),

            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'If you enjoy using Lift, consider starring the project on GitHub to support its development!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ),
            ),

            const SizedBox(height: 48),

            const Center(
              child: Text(
                'Keep Lifting.',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
