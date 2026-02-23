import 'package:flutter/material.dart';
import 'dart:math';

void main() {
    runApp(const MyApp());
}

class MyApp extends StatelessWidget {
    const MyApp({super.key});

    @override
    Widget build(BuildContext context) {
        return MaterialApp(
            title: 'Creativity Ideas',
            theme: ThemeData(primarySwatch: Colors.blue),
            home: const CreativityScreen(),
        );
    }
}

class CreativityScreen extends StatefulWidget {
    const CreativityScreen({super.key});

    @override
    State<CreativityScreen> createState() => _CreativityScreenState();
}

class _CreativityScreenState extends State<CreativityScreen> {
    final List<String> ideas = [
        'Write a short story about time travel',
        'Design a new product that solves a daily problem',
        'Create artwork inspired by your favorite song',
        'Invent a new recipe combining unusual ingredients',
        'Write a poem about a forgotten memory',
        'Design a dream vacation itinerary',
        'Create a fictional world with its own rules',
        'Draw your emotions without using words',
        'Write a letter to your future self',
        'Design a new mobile app idea',
    ];

    late String currentIdea;

    @override
    void initState() {
        super.initState();
        currentIdea = ideas[Random().nextInt(ideas.length)];
    }

    void generateNewIdea() {
        setState(() {
            currentIdea = ideas[Random().nextInt(ideas.length)];
        });
    }

    @override
    Widget build(BuildContext context) {
        return Scaffold(
            appBar: AppBar(title: const Text('Creativity Ideas')),
            body: Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                        const Text('Your Creativity Challenge:',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 30),
                        Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                    color: Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.blue),
                                ),
                                child: Text(currentIdea,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 24, color: Colors.black87)),
                            ),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                            onPressed: generateNewIdea,
                            child: const Text('Get New Idea'),
                        ),
                    ],
                ),
            ),
        );
    }
}