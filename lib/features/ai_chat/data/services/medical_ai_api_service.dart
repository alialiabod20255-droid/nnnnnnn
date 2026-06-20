import 'package:dio/dio.dart';
import '../models/ai_chat_message.dart';
import '../models/medical_intake.dart';

class MedicalAiApiService {
  // اترك المفتاح فارغاً داخل الكود، ومرره وقت التشغيل عبر:
  // --dart-define=GEMINI_API_KEY=YOUR_KEY

  final Dio _dio;
  final String? baseUrl;
  final String? apiKey;

  MedicalAiApiService({
    Dio? dio,
    this.baseUrl = const String.fromEnvironment(' '),
    this.apiKey = const String.fromEnvironment(''),
  }) : _dio = dio ?? Dio();

  Future<String> sendMedicalMessage({
    required MedicalIntake intake,
    required List<AiChatMessage> history,
    required String message,
  }) async {
    final configuredUrl = (baseUrl ?? '').trim();

    if (configuredUrl.isNotEmpty) {
      final response = await _dio.post(
        configuredUrl,
        data: {
          'system': _systemPrompt,
          'intake': intake.toPrompt(),
          'message': message,
          'history': history.map((e) => e.toMap(firestore: false)).toList(),
        },
        options: Options(
          headers: {
            if ((apiKey ?? '').isNotEmpty) 'Authorization': 'Bearer $apiKey',
          },
        ),
      );

      return (
          response.data['reply'] ??
              response.data['message'] ??
              response.data['choices']?[0]?['message']?['content'] ??
              ''
      ).toString();
    }

    final key = (apiKey ?? '').trim();

    if (key.isEmpty) {
      return 'لم يتم ضبط مفتاح الذكاء الاصطناعي بعد. شغّل التطبيق باستخدام --dart-define=GEMINI_API_KEY=YOUR_KEY لتفعيل الردود. لن يتم إرسال رسالتك لأي خدمة خارجية حتى يتم ضبط المفتاح.';
    }

    final geminiUrl =
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$key';

    final response = await _dio.post(
      geminiUrl,
      data: {
        'contents': [
          {
            'role': 'user',
            'parts': [
              {
                'text':
                '$_systemPrompt\n\n'
                    'بيانات الحالة:\n${intake.toPrompt()}\n\n'
                    'سجل مختصر:\n${history.map((e) => '${e.isUser ? 'المستخدم' : 'المساعد'}: ${e.content}').join('\n')}\n\n'
                    'سؤال المستخدم:\n$message',
              }
            ]
          }
        ],
        'generationConfig': {
          'temperature': 0.4,
          'maxOutputTokens': 900,
        },
      },
    );

    final reply = (
        response.data['candidates']?[0]?['content']?['parts']?[0]?['text'] ??
            ''
    ).toString().trim();

    if (reply.isEmpty) {
      return 'وصل الطلب إلى خدمة الذكاء الاصطناعي لكن لم يصل رد مفهوم. حاول إعادة صياغة السؤال.';
    }

    return reply;
  }

  String get _systemPrompt =>
      'أنت مساعد طبي عربي داخل تطبيق نبض. قدم إجابة منظمة وواضحة، نبه للحالات الطارئة، ولا تقدم تشخيصاً نهائياً أو وصفة دوائية خطرة.';
}
