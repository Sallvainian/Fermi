/// Models for Jeopardy game functionality
library;

class JeopardyGame {
  final String id;
  final String title;
  final String teacherId;
  final List<JeopardyCategory> categories;
  final FinalJeopardyData? finalJeopardy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;

  JeopardyGame({
    required this.id,
    required this.title,
    required this.teacherId,
    required this.categories,
    this.finalJeopardy,
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = false,
  });

  factory JeopardyGame.empty() => JeopardyGame(
    id: '',
    title: 'New Jeopardy Game',
    teacherId: '',
    categories: [],
    createdAt: DateTime.now(),
    updatedAt: DateTime.now(),
  );

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'teacherId': teacherId,
    'categories': categories.map((c) => c.toJson()).toList(),
    'finalJeopardy': finalJeopardy?.toJson(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isPublic': isPublic,
  };
}

class JeopardyCategory {
  final String name;
  final List<JeopardyQuestion> questions;

  JeopardyCategory({
    required this.name,
    required this.questions,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'questions': questions.map((q) => q.toJson()).toList(),
  };

  factory JeopardyCategory.fromJson(Map<String, dynamic> json) => JeopardyCategory(
    name: json['name'],
    questions: (json['questions'] as List)
        .map((q) => JeopardyQuestion.fromJson(q))
        .toList(),
  );
}

class JeopardyQuestion {
  final String question;
  final String answer;
  final int points;
  final bool isAnswered;
  final String? answeredBy;
  final bool isDailyDouble;

  JeopardyQuestion({
    required this.question,
    required this.answer,
    required this.points,
    this.isAnswered = false,
    this.answeredBy,
    this.isDailyDouble = false,
  });

  JeopardyQuestion copyWith({
    String? question,
    String? answer,
    int? points,
    bool? isAnswered,
    String? answeredBy,
    bool? isDailyDouble,
  }) => JeopardyQuestion(
    question: question ?? this.question,
    answer: answer ?? this.answer,
    points: points ?? this.points,
    isAnswered: isAnswered ?? this.isAnswered,
    answeredBy: answeredBy ?? this.answeredBy,
    isDailyDouble: isDailyDouble ?? this.isDailyDouble,
  );

  Map<String, dynamic> toJson() => {
    'question': question,
    'answer': answer,
    'points': points,
    'isAnswered': isAnswered,
    'answeredBy': answeredBy,
    'isDailyDouble': isDailyDouble,
  };

  factory JeopardyQuestion.fromJson(Map<String, dynamic> json) => JeopardyQuestion(
    question: json['question'],
    answer: json['answer'],
    points: json['points'],
    isAnswered: json['isAnswered'] ?? false,
    answeredBy: json['answeredBy'],
    isDailyDouble: json['isDailyDouble'] ?? false,
  );
}

class JeopardyPlayer {
  final String id;
  String name;
  int score;

  JeopardyPlayer({
    required this.id,
    required this.name,
    this.score = 0,
  });
}

class FinalJeopardyData {
  final String category;
  final String question;
  final String answer;

  FinalJeopardyData({
    required this.category,
    required this.question,
    required this.answer,
  });

  Map<String, dynamic> toJson() => {
    'category': category,
    'question': question,
    'answer': answer,
  };

  factory FinalJeopardyData.fromJson(Map<String, dynamic> json) => FinalJeopardyData(
    category: json['category'],
    question: json['question'],
    answer: json['answer'],
  );
}