import 'package:flutter/material.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height,
      child: Column(
        children: [
          Container(
            color: Colors.blue,
            padding: const EdgeInsets.all(16),
            child: const Center(
              child: Text(
                'Dashboard PDAM Digital',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.grey[100],
              child: const Center(
                child: Text('Homescreen Content'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}