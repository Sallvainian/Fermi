/// Models for Jeopardy game functionality
library;

class JeopardyGame {
  final String id;
  final String title;
  final String teacherId;
  final List<JeopardyCategory> categories;
  final List<JeopardyCategory>? doubleJeopardyCategories;
  final FinalJeopardyData? finalJeopardy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool isPublic;
  final GameMode gameMode;
  final List<String> assignedClassIds;
  final List<DailyDouble> dailyDoubles;
  final bool randomDailyDoubles;

  JeopardyGame({
    required this.id,
    required this.title,
    required this.teacherId,
    required this.categories,
    this.doubleJeopardyCategories,
    this.finalJeopardy,
    required this.createdAt,
    required this.updatedAt,
    this.isPublic = false,
    this.gameMode = GameMode.realtime,
    this.assignedClassIds = const [],
    this.dailyDoubles = const [],
    this.randomDailyDoubles = false,
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
        'doubleJeopardyCategories': doubleJeopardyCategories?.map((c) => c.toJson()).toList(),
        'finalJeopardy': finalJeopardy?.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'isPublic': isPublic,
        'gameMode': gameMode.name,
        'assignedClassIds': assignedClassIds,
        'dailyDoubles': dailyDoubles.map((dd) => dd.toJson()).toList(),
        'randomDailyDoubles': randomDailyDoubles,
      };
  
  factory JeopardyGame.fromFirestore(Map<String, dynamic> data, String id) => JeopardyGame(
        id: id,
        title: data['title'] ?? '',
        teacherId: data['teacherId'] ?? '',
        categories: (data['categories'] as List?)
            ?.map((c) => JeopardyCategory.fromJson(c))
            .toList() ?? [],
        doubleJeopardyCategories: (data['doubleJeopardyCategories'] as List?)
            ?.map((c) => JeopardyCategory.fromJson(c))
            .toList(),
        finalJeopardy: data['finalJeopardy'] != null
            ? FinalJeopardyData.fromJson(data['finalJeopardy'])
            : null,
        createdAt: DateTime.parse(data['createdAt'] ?? DateTime.now().toIso8601String()),
        updatedAt: DateTime.parse(data['updatedAt'] ?? DateTime.now().toIso8601String()),
        isPublic: data['isPublic'] ?? false,
        gameMode: GameMode.values.firstWhere(
          (m) => m.name == data['gameMode'],
          orElse: () => GameMode.realtime,
        ),
        assignedClassIds: List<String>.from(data['assignedClassIds'] ?? []),
        dailyDoubles: (data['dailyDoubles'] as List?)
            ?.map((dd) => DailyDouble.fromJson(dd))
            .toList() ?? [],
        randomDailyDoubles: data['randomDailyDoubles'] ?? false,
      );
  
  JeopardyGame copyWith({
    String? id,
    String? title,
    String? teacherId,
    List<JeopardyCategory>? categories,
    List<JeopardyCategory>? doubleJeopardyCategories,
    FinalJeopardyData? finalJeopardy,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isPublic,
    GameMode? gameMode,
    List<String>? assignedClassIds,
    List<DailyDouble>? dailyDoubles,
    bool? randomDailyDoubles,
  }) => JeopardyGame(
        id: id ?? this.id,
        title: title ?? this.title,
        teacherId: teacherId ?? this.teacherId,
        categories: categories ?? this.categories,
        doubleJeopardyCategories: doubleJeopardyCategories ?? this.doubleJeopardyCategories,
        finalJeopardy: finalJeopardy ?? this.finalJeopardy,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isPublic: isPublic ?? this.isPublic,
        gameMode: gameMode ?? this.gameMode,
        assignedClassIds: assignedClassIds ?? this.assignedClassIds,
        dailyDoubles: dailyDoubles ?? this.dailyDoubles,
        randomDailyDoubles: randomDailyDoubles ?? this.randomDailyDoubles,
      );
}

class JeopardyCategory {
  final String name;
  final List<JeopardyQuestion> questions;

  JeopardyCategory({
    required this.name,
    required this.questions,
  });

  JeopardyCategory copyWith({
    String? name,
    List<JeopardyQuestion>? questions,
  }) =>
      JeopardyCategory(
        name: name ?? this.name,
        questions: questions ?? this.questions,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'questions': questions.map((q) => q.toJson()).toList(),
      };

  factory JeopardyCategory.fromJson(Map<String, dynamic> json) =>
      JeopardyCategory(
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
  }) =>
      JeopardyQuestion(
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

  factory JeopardyQuestion.fromJson(Map<String, dynamic> json) =>
      JeopardyQuestion(
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
  final String? teamId;

  JeopardyPlayer({
    required this.id,
    required this.name,
    this.score = 0,
    this.teamId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'score': score,
        'teamId': teamId,
      };

  factory JeopardyPlayer.fromJson(Map<String, dynamic> json) => JeopardyPlayer(
        id: json['id'],
        name: json['name'],
        score: json['score'] ?? 0,
        teamId: json['teamId'],
      );
}

class JeopardyTeam {
  final String id;
  final String name;
  final List<String> memberIds;
  int score;

  JeopardyTeam({
    required this.id,
    required this.name,
    required this.memberIds,
    this.score = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'memberIds': memberIds,
        'score': score,
      };

  factory JeopardyTeam.fromJson(Map<String, dynamic> json) => JeopardyTeam(
        id: json['id'],
        name: json['name'],
        memberIds: List<String>.from(json['memberIds'] ?? []),
        score: json['score'] ?? 0,
      );
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

  factory FinalJeopardyData.fromJson(Map<String, dynamic> json) =>
      FinalJeopardyData(
        category: json['category'],
        question: json['question'],
        answer: json['answer'],
      );
}

/// Enum for game modes
enum GameMode {
  realtime,  // Students play together in class
  async,     // Students can play anytime for study
}

/// Daily Double location in the game
class DailyDouble {
  final String round;  // 'jeopardy' or 'doubleJeopardy'
  final int categoryIndex;
  final int questionIndex;

  DailyDouble({
    required this.round,
    required this.categoryIndex,
    required this.questionIndex,
  });

  Map<String, dynamic> toJson() => {
        'round': round,
        'categoryIndex': categoryIndex,
        'questionIndex': questionIndex,
      };

  factory DailyDouble.fromJson(Map<String, dynamic> json) => DailyDouble(
        round: json['round'],
        categoryIndex: json['categoryIndex'],
        questionIndex: json['questionIndex'],
      );
}

/// Active game session model
class JeopardyGameSession {
  final String id;
  final String gameId;
  final String teacherId;
  final String classId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<JeopardyPlayer> players;
  final List<JeopardyTeam>? teams;
  final String currentRound; // 'jeopardy', 'doubleJeopardy', 'finalJeopardy'
  final Map<String, Map<String, bool>> answeredQuestions; // round -> categoryIndex_questionIndex -> answered
  final bool isActive;

  JeopardyGameSession({
    required this.id,
    required this.gameId,
    required this.teacherId,
    required this.classId,
    required this.startedAt,
    this.endedAt,
    required this.players,
    this.teams,
    this.currentRound = 'jeopardy',
    this.answeredQuestions = const {},
    this.isActive = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'gameId': gameId,
        'teacherId': teacherId,
        'classId': classId,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'players': players.map((p) => p.toJson()).toList(),
        'teams': teams?.map((t) => t.toJson()).toList(),
        'currentRound': currentRound,
        'answeredQuestions': answeredQuestions,
        'isActive': isActive,
      };

  factory JeopardyGameSession.fromJson(Map<String, dynamic> json) => JeopardyGameSession(
        id: json['id'],
        gameId: json['gameId'],
        teacherId: json['teacherId'],
        classId: json['classId'],
        startedAt: DateTime.parse(json['startedAt']),
        endedAt: json['endedAt'] != null ? DateTime.parse(json['endedAt']) : null,
        players: (json['players'] as List)
            .map((p) => JeopardyPlayer.fromJson(p))
            .toList(),
        teams: (json['teams'] as List?)
            ?.map((t) => JeopardyTeam.fromJson(t))
            .toList(),
        currentRound: json['currentRound'] ?? 'jeopardy',
        answeredQuestions: (json['answeredQuestions'] as Map<String, dynamic>?)
            ?.map((key, value) => MapEntry(key, Map<String, bool>.from(value))) ?? {},
        isActive: json['isActive'] ?? true,
      );
}
