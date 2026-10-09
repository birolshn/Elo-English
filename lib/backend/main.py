# pyright: reportPrivateImportUsage=false
# type: ignore
import warnings
warnings.filterwarnings("ignore", category=FutureWarning)

from fastapi import FastAPI, HTTPException, UploadFile, File, Request
from fastapi.responses import StreamingResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict, Any
from dotenv import load_dotenv
from contextlib import asynccontextmanager
import google.generativeai as genai
import os
import json
import shutil
import uuid
import re
from datetime import datetime

load_dotenv()

UPLOADS_DIR = "uploads"

# Ensure uploads directory exists
os.makedirs(UPLOADS_DIR, exist_ok=True)

# Lifespan event handler (yeni yöntem)
@asynccontextmanager
async def lifespan(app: FastAPI):
    # Startup
    gemini_key = os.environ.get("GEMINI_API_KEY")
    if not gemini_key:
        print("⚠️  WARNING: GEMINI_API_KEY not found in environment variables!")
    else:
        print("✅ Gemini API Key loaded successfully")
        genai.configure(api_key=gemini_key)

    print("\n🚀 Language Learning API READY")
    print("📖 Swagger: http://localhost:8000/docs")
    print("🔗 Base URL: http://localhost:8000")
    
    yield
    
    # Shutdown
    print("\n👋 Language Learning API shutting down...")

app = FastAPI(
    title="Language Learning API - Gemini Edition",
    lifespan=lifespan
)

# Mount uploads to /uploads
app.mount("/uploads", StaticFiles(directory=UPLOADS_DIR), name="uploads")

# CORS ayarları
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.post("/upload/avatar")
async def upload_avatar(request: Request, file: UploadFile = File(...)):
    """Avatar yükle ve URL döndür"""
    try:
        # Dosya uzantısını al
        filename = file.filename or ""
        file_ext = os.path.splitext(filename)[1]
        if not file_ext or file_ext.lower() not in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
            raise HTTPException(status_code=400, detail="Only images are allowed")
            
        # Benzersiz isim oluştur
        new_filename = f"{uuid.uuid4()}{file_ext}"
        file_path = os.path.join(UPLOADS_DIR, new_filename)
        
        # Dosyayı kaydet
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        # Dinamik URL oluştur (localhost veya production)
        base_url = str(request.base_url).rstrip("/")
        file_url = f"{base_url}/uploads/{new_filename}"
        
        return {"url": file_url}
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

# Models
# ... models ...
class ConversationRequest(BaseModel):
    scenario: str
    user_message: str
    conversation_history: List[dict] = []
    user_level: str = "beginner"
    custom_system_prompt: Optional[str] = None

class ConversationResponse(BaseModel):
    ai_message: str
    feedback: Optional[str] = None
    grammar_corrections: List[str] = []
    vocabulary_suggestions: List[str] = []

class CustomScenarioRequest(BaseModel):
    user_prompt: str
    user_level: str = "intermediate"

class CustomScenarioResponse(BaseModel):
    id: str
    title: str
    description: str
    difficulty: str
    estimated_time: int
    system_prompt: str
    greeting: str
    semantic_icon: str = "forum_rounded"

class WordAnalysis(BaseModel):
    word: str
    ipa: str
    score: int  # 0 - 100
    status: str  # "perfect", "good", "needs_work"
    tip: Optional[str] = None

class PronunciationRequest(BaseModel):
    target_sentence: str
    spoken_text: str

class PronunciationResponse(BaseModel):
    overall_score: int
    fluency_score: int
    words: List[WordAnalysis]
    challenging_sounds: List[str] = []
    encouragement: str

class ScenarioInfo(BaseModel):
    id: str
    title: str
    description: str
    difficulty: str
    estimated_time: int
    custom_system_prompt: Optional[str] = None
    greeting: Optional[str] = None
    is_custom: Optional[bool] = False

    class Config:
        extra = "ignore"

class UserProgress(BaseModel):
    user_id: str
    total_conversations: int
    total_time_minutes: int
    current_level: str
    completed_scenarios: List[str]
    weekly_xp: int = 0  # New field
    display_name: Optional[str] = None
    rank: Optional[int] = None # Helper for response

class ProgressUpdate(BaseModel):
    total_conversations: Optional[int] = None
    total_time_minutes: Optional[int] = None
    completed_scenario: Optional[str] = None
    added_xp: Optional[int] = None
    display_name: Optional[str] = None

class LeaderboardEntry(BaseModel):
    rank: int
    user_id: str
    display_name: str
    weekly_xp: int
    avatar_url: Optional[str] = None

# Senaryolar - TÜM SENARYOLAR EKLENDİ
SCENARIOS = [
    {
        "id": "restaurant",
        "title": "Ordering at a Restaurant",
        "description": "Learn how to order food at a restaurant",
        "difficulty": "beginner",
        "estimated_time": 5,
        "system_prompt": """You are a friendly waiter at a restaurant. Help the user practice ordering food in English. Speak naturally but clearly. After each user message, provide gentle corrections if needed.

IMPORTANT CONTEXT RULE: This conversation is ONLY about a restaurant dining experience - ordering food, asking about the menu, making reservations, or anything related to eating at a restaurant. If the user says something completely unrelated to a restaurant setting (e.g., talking about job interviews, airports, shopping for clothes, etc.), you MUST politely redirect them. For example: "I appreciate your enthusiasm, but I'm your waiter today! 🍽️ Let's focus on your dining experience. Would you like to see our menu or would you like to hear today's specials?" Stay in character as a waiter at all times.

CRITICAL LENGTH RULE: Keep your responses short, natural, and conversational. Do NOT exceed 2-3 sentences and maximum 30 words per response."""
    },
    {
        "id": "job_interview",
        "title": "Job Interview",
        "description": "Introduce yourself and answer questions in a job interview",
        "difficulty": "intermediate",
        "estimated_time": 10,
        "system_prompt": """You are a professional interviewer conducting a job interview. Ask relevant questions and help the user practice professional English. Be encouraging but realistic.

IMPORTANT CONTEXT RULE: This conversation is ONLY about a job interview setting. If the user says something completely unrelated to a job interview (e.g., ordering food, asking for directions, casual chatting about hobbies unrelated to the interview), you MUST politely redirect them back to the interview. For example: "That's interesting, but let's stay focused on the interview. This is a professional setting, so let me ask you: could you tell me about your relevant experience?" Stay in character as an interviewer at all times.

CRITICAL LENGTH RULE: Keep your responses short, natural, and conversational. Do NOT exceed 2-3 sentences and maximum 30 words per response."""
    },
    {
        "id": "shopping",
        "title": "Shopping",
        "description": "Speak English while shopping at a store",
        "difficulty": "beginner",
        "estimated_time": 5,
        "system_prompt": """You are a helpful shop assistant at a clothing and general goods store. Help the user practice shopping vocabulary and common phrases used when buying things.

IMPORTANT CONTEXT RULE: This conversation is ONLY about shopping at a store - looking for items, asking about prices, sizes, colors, trying things on, or paying. If the user says something completely unrelated to shopping (e.g., talking about job interviews, ordering food at a restaurant, etc.), you MUST politely redirect them. For example: "I'd love to help, but I'm a shop assistant! 🛍️ Let's focus on finding something great for you. Are you looking for anything in particular today?" Stay in character as a shop assistant at all times.

CRITICAL LENGTH RULE: Keep your responses short, natural, and conversational. Do NOT exceed 2-3 sentences and maximum 30 words per response."""
    },
    {
        "id": "airport",
        "title": "At the Airport",
        "description": "Check-in, passport control and security procedures",
        "difficulty": "intermediate",
        "estimated_time": 8,
        "system_prompt": """You are an airport staff member (check-in agent, security officer, or customs official). Help the user practice airport-related English conversations.

IMPORTANT CONTEXT RULE: This conversation is ONLY about airport situations - check-in, boarding, passport control, security, customs, baggage, flight information, etc. If the user says something completely unrelated to an airport experience (e.g., ordering food, job interviews, shopping), you MUST politely redirect them. For example: "I understand, but we're at the airport right now! ✈️ Let's focus on getting you through check-in. May I see your passport and boarding pass, please?" Stay in character as an airport staff member at all times.

CRITICAL LENGTH RULE: Keep your responses short, natural, and conversational. Do NOT exceed 2-3 sentences and maximum 30 words per response."""
    },
    {
        "id": "small_talk",
        "title": "Small Talk",
        "description": "Have a friendly chat with someone you just met",
        "difficulty": "beginner",
        "estimated_time": 5,
        "system_prompt": """You are a friendly person meeting someone new at a social event. Have a casual conversation, ask about their interests, hobbies, and life. Keep it natural and friendly.

IMPORTANT CONTEXT RULE: This conversation is about casual small talk and getting to know someone. Topics like weather, hobbies, travel, family, work (briefly), and interests are all fine. However, if the user tries to start a completely different scenario (e.g., pretending to order food, conducting a job interview, etc.), gently guide them back. For example: "Ha, that's funny! But let's just chat normally - I'd love to get to know you better. So, what do you enjoy doing in your free time?" Stay in character as a friendly acquaintance.

CRITICAL LENGTH RULE: Keep your responses short, natural, and conversational. Do NOT exceed 2-3 sentences and maximum 30 words per response."""
    },
    {
        "id": "general",
        "title": "General Conversation (Premium)",
        "description": "Unlimited conversation practice on any topic",
        "difficulty": "all levels",
        "estimated_time": 0,
        "system_prompt": "You are a helpful and friendly English language partner. The user can discuss any topic with you. Keep the conversation engaging naturally."
    }
]

def get_scenario_by_id(scenario_id: str):
    return next((s for s in SCENARIOS if s["id"] == scenario_id), None)

@app.get("/")
async def root():
    return {
        "message": "Language Learning API is running",
        "version": "2.2.0 - Stateless Edition",
        "endpoints": ["/scenarios", "/conversation", "/speech-to-text", "/health"]
    }

@app.get("/health")
async def health_check():
    """Gemini API bağlantısını test eder"""
    gemini_key = os.environ.get("GEMINI_API_KEY")
    result = {
        "api_key_present": bool(gemini_key),
        "api_key_prefix": gemini_key[:10] + "..." if gemini_key else None,
    }
    
    if gemini_key:
        try:
            genai.configure(api_key=gemini_key)
            model = genai.GenerativeModel('gemini-2.5-flash')
            response = model.generate_content("Say hello in one word")
            result["gemini_status"] = "working"
            result["gemini_response"] = response.text[:100]
        except Exception as e:
            result["gemini_status"] = "error"
            result["gemini_error_type"] = type(e).__name__
            result["gemini_error"] = str(e)[:300]
    else:
        result["gemini_status"] = "no_api_key"
    
    return result

@app.get("/scenarios", response_model=List[ScenarioInfo])
async def get_scenarios() -> List[ScenarioInfo]:
    """Tüm senaryoların listesini döndürür"""
    return [
        ScenarioInfo(
            id=str(s.get("id", "")),
            title=str(s.get("title", "")),
            description=str(s.get("description", "")),
            difficulty=str(s.get("difficulty", "beginner")),
            estimated_time=int(s.get("estimated_time", 5))
        )
        for s in SCENARIOS
    ]

@app.post("/conversation", response_model=ConversationResponse)
async def create_conversation(request: ConversationRequest):
    """Google Gemini kullanarak sohbet ve geri bildirim oluşturur"""
    try:
        if request.custom_system_prompt:
            system_prompt = request.custom_system_prompt
        else:
            scenario = get_scenario_by_id(request.scenario)
            if not scenario:
                system_prompt = "You are a friendly and encouraging English conversation partner. Help the user practice natural English."
            else:
                system_prompt = scenario['system_prompt']

        # Konuşma geçmişini metne dönüştür
        history_text = ""
        for msg in request.conversation_history[-10:]:  # Son 10 mesajı al
            role = "Assistant" if msg["role"] == "assistant" else "User"
            history_text += f"{role}: {msg['content']}\n"

        # Gemini Prompt
        prompt = f"""You are playing the following role: {system_prompt}

The user's English level is: {request.user_level}

Previous conversation:
{history_text}

User's new message: {request.user_message}

Instructions:
1. Respond naturally to the user's message as your character
2. Keep your response conversational and engaging (maximum 2-3 sentences, 35 words max)
3. After your response, provide feedback in JSON format inside <feedback> tags

Response format:
[Your natural conversational response here]

<feedback>
{{
  "grammar_corrections": ["'exact words the user said' -> 'corrected version' (short rule name) - max 1-2 most important; use an EMPTY list [] if there are no mistakes"],
  "vocabulary_suggestions": ["suggest 1-2 better words or phrases they could use"],
  "general_feedback": "One encouraging sentence about their English"
}}
</feedback>"""

        # Google Gemini çağrısı
        try:
            model = genai.GenerativeModel('gemini-2.5-flash')
            response = model.generate_content(prompt)
            ai_response_raw = response.text
        except Exception as gemini_error:
            import traceback
            print(f"❌ Gemini Error Type: {type(gemini_error).__name__}")
            print(f"❌ Gemini Error: {gemini_error}")
            traceback.print_exc()
            ai_response_raw = f"I hear you! That's a great point. How else would you describe that?"

        # Feedback'i ayrıştır
        feedback_data = {
            "ai_message": ai_response_raw,
            "feedback": None,
            "grammar_corrections": [],
            "vocabulary_suggestions": []
        }
        
        if "<feedback>" in ai_response_raw and "</feedback>" in ai_response_raw:
            parts = ai_response_raw.split("<feedback>")
            feedback_data["ai_message"] = parts[0].strip()
            
            try:
                feedback_json_str = parts[1].split("</feedback>")[0].strip()
                fb_json = json.loads(feedback_json_str)
                feedback_data["feedback"] = fb_json.get("general_feedback", "")
                feedback_data["grammar_corrections"] = fb_json.get("grammar_corrections", [])
                feedback_data["vocabulary_suggestions"] = fb_json.get("vocabulary_suggestions", [])
            except json.JSONDecodeError as e:
                print(f"JSON Parse Error: {e}")

        return ConversationResponse(**feedback_data)

    except Exception as e:
        print(f"Conversation Error: {e}")
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")

@app.post("/conversation/stream")
async def stream_conversation(request: ConversationRequest):
    """Canlı akış (SSE streaming) - Yanıtları kelime kelime ekrana ve TTS motoruna aktarır"""
    try:
        if request.custom_system_prompt:
            system_prompt = request.custom_system_prompt
        else:
            scenario = get_scenario_by_id(request.scenario)
            system_prompt = scenario['system_prompt'] if scenario else "You are a friendly English conversation tutor."

        history_text = ""
        for msg in request.conversation_history[-10:]:
            role = "Assistant" if msg["role"] == "assistant" else "User"
            history_text += f"{role}: {msg['content']}\n"

        prompt = f"""You are playing the following role: {system_prompt}

The user's English level is: {request.user_level}

Previous conversation:
{history_text}

User's new message: {request.user_message}

Instructions:
1. Respond naturally to the user's message as your character
2. Keep your response conversational and engaging (maximum 2-3 sentences, 35 words max)
3. After your response, provide feedback in JSON format inside <feedback> tags

Response format:
[Your natural conversational response here]

<feedback>
{{
  "grammar_corrections": ["'exact words the user said' -> 'corrected version' (short rule name) - max 1-2 most important; use an EMPTY list [] if there are no mistakes"],
  "vocabulary_suggestions": ["suggest 1-2 better words or phrases"],
  "general_feedback": "One encouraging sentence about their English"
}}
</feedback>"""

        feedback_tag = "<feedback>"

        async def event_generator():
            full_text = ""
            streamed_len = 0  # Kullanıcıya gönderilmiş mesaj kısmının uzunluğu
            try:
                model = genai.GenerativeModel('gemini-2.5-flash')
                # Async stream: event loop'u bloklamaz
                response = await model.generate_content_async(prompt, stream=True)

                async for chunk in response:
                    try:
                        chunk_text = chunk.text
                    except Exception:
                        # Metin içermeyen (ör. güvenlik) parçaları atla
                        continue
                    if not chunk_text:
                        continue
                    full_text += chunk_text

                    if feedback_tag in full_text:
                        message_part = full_text.split(feedback_tag)[0]
                    else:
                        # Parçalara bölünmüş "<feedb" gibi yarım etiketi geri tut
                        message_part = full_text
                        lt = full_text.rfind("<")
                        if lt != -1 and feedback_tag.startswith(full_text[lt:]):
                            message_part = full_text[:lt]

                    if len(message_part) > streamed_len:
                        new_text = message_part[streamed_len:]
                        streamed_len = len(message_part)
                        yield f"data: {json.dumps({'type': 'chunk', 'text': new_text})}\n\n"
                    # Etiket geldikten sonra akışı kesmiyoruz: feedback JSON'unun
                    # tamamını toplamak için okumaya devam ediyoruz.

                if feedback_tag not in full_text and len(full_text) > streamed_len:
                    yield f"data: {json.dumps({'type': 'chunk', 'text': full_text[streamed_len:]})}\n\n"
                    streamed_len = len(full_text)

                if streamed_len == 0:
                    yield f"data: {json.dumps({'type': 'chunk', 'text': 'I see! Could you tell me a bit more about that?'})}\n\n"

                # Parse feedback
                fb_data = {
                    "type": "feedback",
                    "feedback": "Great conversational flow!",
                    "grammar_corrections": [],
                    "vocabulary_suggestions": []
                }
                if "<feedback>" in full_text and "</feedback>" in full_text:
                    try:
                        fb_str = full_text.split("<feedback>")[1].split("</feedback>")[0].strip()
                        fb_json = json.loads(fb_str)
                        fb_data["feedback"] = fb_json.get("general_feedback", "Great job!")
                        fb_data["grammar_corrections"] = fb_json.get("grammar_corrections", [])
                        fb_data["vocabulary_suggestions"] = fb_json.get("vocabulary_suggestions", [])
                    except Exception:
                        pass
                
                yield f"data: {json.dumps(fb_data)}\n\n"
                yield f"data: {json.dumps({'type': 'done'})}\n\n"

            except Exception as stream_err:
                print(f"Stream error: {stream_err}")
                # Yarım kalan bir cevabın sonuna yedek cümle eklemeyelim
                if streamed_len == 0:
                    yield f"data: {json.dumps({'type': 'chunk', 'text': 'I understand! That is very interesting.'})}\n\n"
                yield f"data: {json.dumps({'type': 'done'})}\n\n"

        return StreamingResponse(
            event_generator(),
            media_type="text/event-stream",
            # Proxy'lerin (Render vb.) SSE'yi tamponlamasını engelle
            headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
        )

    except Exception as e:
        print(f"Stream Conversation Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@app.post("/scenarios/custom", response_model=CustomScenarioResponse)
async def create_custom_scenario(request: CustomScenarioRequest):
    """Kullanıcının yazdığı fikre göre yapay zeka ile anında özel senaryo yaratır"""
    user_idea = request.user_prompt.strip()
    scenario_id = f"custom_{uuid.uuid4().hex[:8]}"

    prompt = f"""You are an expert English language curriculum designer.
A user wants to practice English for this specific real-life situation:
"{user_idea}"

The user's English level is: {request.user_level}

Create a realistic roleplay scenario for this situation.
Return JSON ONLY matching this exact format:
{{
  "title": "Short catchy title in English (e.g. Negotiating Rent)",
  "description": "One sentence describing the situation and goal",
  "difficulty": "beginner" or "intermediate" or "advanced",
  "estimated_time": 5 to 10 (minutes as integer),
  "system_prompt": "You are [role/character]. [Guidelines on how to interact, stay in character, be realistic, and gently guide the user]. CRITICAL LENGTH RULE: Keep each response short (max 2-3 sentences, 30 words max).",
  "greeting": "First sentence spoken by the AI character to open the conversation naturally.",
  "semantic_icon": "forum_rounded" or "work_rounded" or "shopping_bag_rounded" or "restaurant_menu_rounded" or "flight_takeoff_rounded"
}}"""

    try:
        model = genai.GenerativeModel('gemini-2.5-flash')
        response = model.generate_content(prompt)
        raw_text = response.text.strip()
        if "```json" in raw_text:
            raw_text = raw_text.split("```json")[1].split("```")[0].strip()
        elif "```" in raw_text:
            raw_text = raw_text.split("```")[1].split("```")[0].strip()
        
        data = json.loads(raw_text)
        return CustomScenarioResponse(
            id=scenario_id,
            title=data.get("title", user_idea.title()[:30]),
            description=data.get("description", f"Practice English in: {user_idea}"),
            difficulty=data.get("difficulty", "intermediate"),
            estimated_time=int(data.get("estimated_time", 7)),
            system_prompt=data.get("system_prompt", f"You are a friendly conversation partner in this situation: {user_idea}. Keep answers under 30 words."),
            greeting=data.get("greeting", f"Hello! Let's talk about {user_idea}. How are you today?"),
            semantic_icon=data.get("semantic_icon", "forum_rounded")
        )
    except Exception as e:
        print(f"Custom Scenario Generation Error: {e}")
        # Intelligent fallback
        return CustomScenarioResponse(
            id=scenario_id,
            title=user_idea.title()[:30] if len(user_idea) > 3 else "Custom Roleplay",
            description=f"Practice scenario: {user_idea}",
            difficulty="intermediate",
            estimated_time=7,
            system_prompt=f"You are a friendly conversation partner roleplaying the following situation: {user_idea}. Speak naturally, be supportive, and keep answers to 2-3 sentences.",
            greeting=f"Hello! I am ready to practice with you. Let's start our conversation about {user_idea}!",
            semantic_icon="forum_rounded"
        )

@app.post("/pronunciation/evaluate", response_model=PronunciationResponse)
async def evaluate_pronunciation(request: PronunciationRequest):
    """Telaffuz ve vurgu analizi (Kelime bazlı skor, IPA fonetik ve öneriler)"""
    target = request.target_sentence.strip()
    spoken = request.spoken_text.strip()

    # Serbest konuşmada hedef cümle yok; uygulama tanınan metni iki alana da koyuyor.
    # Bu durumda kendisiyle karşılaştırıp hep %100 vermek yerine bağlamdan çıkarım yaptır.
    if target.lower() == spoken.lower():
        comparison_context = f"""The user spoke freely (there is NO reference sentence).
Speech-to-text transcript of what the user said: "{spoken}"

Speech recognition tends to mishear words that were mispronounced. Infer what the user most likely intended,
and treat words that look out of context, misrecognized or grammatically odd as likely pronunciation problems.
Also weigh the sounds Turkish speakers typically struggle with (/θ/, /ð/, /w/ vs /v/, /æ/ vs /e/, /r/, word-final consonant clusters).
Do NOT give every word a perfect score unless the transcript is clearly flawless."""
    else:
        comparison_context = f"""Target sentence: "{target}"
What the speech-to-text recognized from the user's speech: "{spoken}"
Words of the target sentence that are missing or changed in the recognized text were most likely mispronounced."""

    prompt = f"""You are an expert English phonetics and pronunciation coach.
{comparison_context}

Analyze the pronunciation and fluency.
Evaluate each word in the target sentence:
1. Provide accurate IPA phonetic transcription for the word.
2. Estimate pronunciation accuracy score (0-100) based on how well it was recognized in context.
3. Status: "perfect" (score >= 85), "good" (60 <= score < 85), "needs_work" (score < 60).
4. Add a quick phonetic tip if the word has tricky phonemes like /θ/ (th), /ð/, /w/ vs /v/, or /r/.

Return JSON ONLY in this format:
{{
  "overall_score": 88,
  "fluency_score": 85,
  "words": [
    {{"word": "word", "ipa": "/wɜːrd/", "score": 90, "status": "perfect", "tip": "Round your lips for the /w/ sound"}},
    ...
  ],
  "challenging_sounds": ["/θ/", "/w/"],
  "encouragement": "Great rhythm and clear consonants! Work a little on the 'th' sound."
}}"""

    try:
        model = genai.GenerativeModel('gemini-2.5-flash')
        response = model.generate_content(prompt)
        raw = response.text.strip()
        if "```json" in raw:
            raw = raw.split("```json")[1].split("```")[0].strip()
        elif "```" in raw:
            raw = raw.split("```")[1].split("```")[0].strip()
        
        data = json.loads(raw)
        words_list = [
            WordAnalysis(
                word=w.get("word", ""),
                ipa=w.get("ipa", ""),
                score=int(w.get("score", 85)),
                status=w.get("status", "good"),
                tip=w.get("tip")
            )
            for w in data.get("words", [])
        ]
        return PronunciationResponse(
            overall_score=int(data.get("overall_score", 85)),
            fluency_score=int(data.get("fluency_score", 80)),
            words=words_list,
            challenging_sounds=data.get("challenging_sounds", []),
            encouragement=data.get("encouragement", "Good effort! Keep practicing every day.")
        )
    except Exception as e:
        print(f"Pronunciation Evaluation Error: {e}")
        # Algorithmic fallback
        target_words = re.findall(r"[\w']+", target)
        spoken_words = [w.lower() for w in re.findall(r"[\w']+", spoken)]
        
        words_analysis = []
        matches = 0
        for tw in target_words:
            is_matched = tw.lower() in spoken_words
            score = 92 if is_matched else 55
            status = "perfect" if is_matched else "needs_work"
            if is_matched:
                matches += 1
            words_analysis.append(
                WordAnalysis(
                    word=tw,
                    ipa=f"/{tw.lower()}/",
                    score=score,
                    status=status,
                    tip="Focus on clear vowel elongation" if not is_matched else None
                )
            )
        
        calc_score = int((matches / max(len(target_words), 1)) * 100)
        calc_score = max(50, min(calc_score, 98))
        return PronunciationResponse(
            overall_score=calc_score,
            fluency_score=calc_score - 5,
            words=words_analysis,
            challenging_sounds=["/θ/", "/r/"],
            encouragement="Clear articulation! Continue practicing speaking smoothly."
        )

@app.post("/speech-to-text")
async def speech_to_text(audio: UploadFile = File(...)):
    """Ses-metin dönüşümü (şimdilik devre dışı - AssemblyAI kaldırıldı)"""
    return {
        "text": "Speech-to-text feature temporarily disabled. Please type your message.",
        "confidence": 0.0,
        "words": []
    }


# IELTS Speaking Models
class IeltsConversationRequest(BaseModel):
    part: int  # 1, 2, or 3
    user_message: str
    conversation_history: List[dict] = []
    topic_card: Optional[str] = None
    is_last_turn: bool = False  # Bölümün son cevabı: yeni soru sorma


LAST_TURN_RULE = """

IMPORTANT: This is the candidate's LAST answer in this part/task. The app will move on to the next part right after your reply.
Briefly acknowledge the answer in ONE short sentence and do NOT ask any new question."""


# IELTS Part prompts
IELTS_PROMPTS = {
    1: """You are a professional IELTS speaking examiner conducting Part 1 of the test.
Your role:
- Ask general questions about the candidate's life, work, studies, hobbies, etc.
- Be professional but friendly
- Ask ONE clear question at a time
- If this is the first message, introduce yourself briefly and ask about their name
- Follow up naturally on their responses
- Keep questions simple and direct

Remember: In Part 1, questions are about familiar topics. Ask about things like:
- Home/accommodation, family, work/studies, hobbies, daily routine, hometown

IMPORTANT CONTEXT RULE: This is a formal IELTS Speaking exam. If the candidate says something completely unrelated to the exam (e.g., ordering food, asking random questions), politely redirect them: "Let's stay focused on the exam. I'll ask you a question, and please answer as clearly as you can." Stay in character as an IELTS examiner at all times.""",

    2: """You are a professional IELTS speaking examiner conducting Part 2 of the test.
The candidate has been given a topic card and has just finished speaking for 1-2 minutes.
Your role:
- Listen to their response about the topic card
- Ask 1-2 brief follow-up questions related to their topic
- Be encouraging but professional
- Transition smoothly when ready to move to Part 3

Topic card given to candidate: {topic_card}

IMPORTANT CONTEXT RULE: This is a formal IELTS Speaking exam. If the candidate goes completely off-topic from the topic card, gently guide them back: "That's interesting, but let's focus on the topic card. Could you tell me more about [topic]?" Stay in character as an IELTS examiner.""",

    3: """You are a professional IELTS speaking examiner conducting Part 3 of the test.
Your role:
- Ask deeper, more abstract questions related to the Part 2 topic
- Encourage the candidate to give extended answers with opinions and explanations
- Ask about general/societal aspects, not personal experiences
- Challenge them to think critically
- Ask ONE question at a time

Focus on:
- Asking "why" and "how" questions
- Exploring different perspectives
- Discussing trends, changes, and future implications

IMPORTANT CONTEXT RULE: This is a formal IELTS Speaking exam. If the candidate says something completely unrelated to the discussion topic, redirect them professionally: "That's an interesting thought, but let's stay on topic. Let me rephrase my question..." Stay in character as an IELTS examiner."""
}


@app.post("/ielts/conversation", response_model=ConversationResponse)
async def ielts_conversation(request: IeltsConversationRequest):
    """IELTS Speaking sınavı için özel endpoint"""
    try:
        # Part için sistem promptunu al
        part = min(max(request.part, 1), 3)  # 1-3 arası sınırla
        system_prompt = IELTS_PROMPTS.get(part, IELTS_PROMPTS[1])
        
        # Part 2 için topic card'ı prompt'a ekle (boşsa "{topic_card}" metni kalmasın)
        if part == 2:
            system_prompt = system_prompt.replace(
                "{topic_card}", request.topic_card or "(the topic card shown to the candidate)"
            )
        elif request.topic_card:
            # Part 1 kategori soruları / Part 3 tartışma soruları (2025-2026 konu havuzu)
            system_prompt += f"""

Official question bank guidance for this part (use these as the basis of your questions, one at a time, adapting naturally to the candidate's answers):
{request.topic_card}"""

        # Konuşma geçmişini metne dönüştür
        history_text = ""
        for msg in request.conversation_history[-10:]:
            role = "Examiner" if msg["role"] == "assistant" else "Candidate"
            history_text += f"{role}: {msg['content']}\n"

        # Gemini Prompt
        prompt = f"""{system_prompt}

Previous conversation:
{history_text}

Candidate's response: {request.user_message}
{LAST_TURN_RULE if request.is_last_turn else ''}

Instructions:
1. Respond naturally as an IELTS examiner
2. For Part 1: Ask another general question OR acknowledge and move on
3. For Part 2: Give brief feedback and ask a follow-up question
4. For Part 3: Acknowledge their point and ask a deeper related question
5. After your response, provide feedback in JSON format inside <feedback> tags

IELTS Band Scoring Criteria to consider:
- Fluency and Coherence
- Lexical Resource (vocabulary range)
- Grammatical Range and Accuracy
- Pronunciation (mention if relevant based on text)

Response format:
[Your natural examiner response - keep it concise and professional]

<feedback>
{{
  "grammar_corrections": ["'exact words the candidate said' -> 'corrected version' (short rule name) - max 2; use an EMPTY list [] if there are no mistakes"],
  "vocabulary_suggestions": ["suggest better word choices if applicable - max 2"],
  "general_feedback": "Brief encouraging comment about their IELTS speaking performance"
}}
</feedback>"""

        # Google Gemini çağrısı
        try:
            model = genai.GenerativeModel('gemini-2.5-flash')
            response = model.generate_content(prompt)
            ai_response_raw = response.text
        except Exception as gemini_error:
            print(f"Gemini Error: {gemini_error}")
            if part == 1:
                ai_response_raw = "That's interesting. Can you tell me about your hobbies or what you like to do in your free time?"
            elif part == 2:
                ai_response_raw = "Thank you for that response. Is there anything else you'd like to add about this topic?"
            else:
                ai_response_raw = "That's a thoughtful perspective. Why do you think this is the case in modern society?"

        # Feedback'i ayrıştır
        feedback_data = {
            "ai_message": ai_response_raw,
            "feedback": None,
            "grammar_corrections": [],
            "vocabulary_suggestions": []
        }
        
        if "<feedback>" in ai_response_raw and "</feedback>" in ai_response_raw:
            parts = ai_response_raw.split("<feedback>")
            feedback_data["ai_message"] = parts[0].strip()
            
            try:
                feedback_json_str = parts[1].split("</feedback>")[0].strip()
                fb_json = json.loads(feedback_json_str)
                feedback_data["feedback"] = fb_json.get("general_feedback", "")
                feedback_data["grammar_corrections"] = fb_json.get("grammar_corrections", [])
                feedback_data["vocabulary_suggestions"] = fb_json.get("vocabulary_suggestions", [])
            except json.JSONDecodeError as e:
                print(f"JSON Parse Error: {e}")

        return ConversationResponse(**feedback_data)

    except Exception as e:
        print(f"IELTS Conversation Error: {e}")
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")


# IELTS Band Score Evaluation
class IeltsEvaluationRequest(BaseModel):
    conversation_history: List[dict]

class IeltsEvaluationResponse(BaseModel):
    band_score: float
    feedback: str
    fluency_score: Optional[float] = None
    vocabulary_score: Optional[float] = None
    grammar_score: Optional[float] = None
    coherence_score: Optional[float] = None
    pronunciation_score: Optional[float] = None
    strengths: List[str] = []
    weaknesses: List[str] = []
    actionable_tips: List[str] = []

# 2025-2026 exam-style topic pool (sınav tarzı, resmi soru değildir)
IELTS_EXAM_TOPICS_2026 = {
    "part1_categories": [
        {
            "category": "Work & Career",
            "questions": [
                "What kind of work do you do, or what are you studying?",
                "Why did you choose that specific career or field of study?",
                "What is the most challenging aspect of your daily work?",
                "Do you prefer working alone or in a team? Why?"
            ]
        },
        {
            "category": "Artificial Intelligence & Technology",
            "questions": [
                "How often do you use technology or AI tools in your daily life?",
                "Do you think technology makes our lives simpler or more complicated?",
                "What piece of technology could you not live without?",
                "Will computers or robots ever replace teachers in the future?"
            ]
        },
        {
            "category": "Hometown & Living Environment",
            "questions": [
                "Where is your hometown, and what is special about it?",
                "Has your hometown changed a lot since you were a child?",
                "What is your favourite spot in your neighborhood?",
                "Would you recommend your hometown to tourists? Why?"
            ]
        },
        {
            "category": "Green Spaces & Environment",
            "questions": [
                "Do you enjoy spending time in public parks or gardens?",
                "How important are green areas in large modern cities?",
                "Did you play outdoors much when you were younger?",
                "What environmental habits do you practice every day?"
            ]
        }
    ],
    "part2_cue_cards": [
        {
            "id": "ai_tool",
            "topic": "Describe an occasion when you used an artificial intelligence or digital tool to solve a problem",
            "category": "Technology (2025-2026)",
            "bullets": [
                "What tool or app you used",
                "What problem or task you needed help with",
                "How the tool assisted you",
                "And explain how satisfied you were with the result"
            ],
            "part3_questions": [
                "How has artificial intelligence changed the way students study nowadays?",
                "What ethical concerns should we consider when developing smarter AI?",
                "Will human creativity still be valued in an automated world?"
            ]
        },
        {
            "id": "memorable_challenge",
            "topic": "Describe a difficult challenge you faced and successfully overcame",
            "category": "Personal Experience",
            "bullets": [
                "What the challenge or difficulty was",
                "When and where it occurred",
                "What steps you took to overcome it",
                "And explain how you felt after resolving it"
            ],
            "part3_questions": [
                "Why do some people enjoy taking on difficult challenges while others avoid them?",
                "How can parents encourage children to develop resilience?",
                "Is failure an essential step on the path to success?"
            ]
        },
        {
            "id": "cultural_festival",
            "topic": "Describe a traditional celebration or cultural festival in your country",
            "category": "Culture & Society",
            "bullets": [
                "What festival or celebration it is",
                "When and where it takes place",
                "What traditional foods or activities are involved",
                "And explain why this festival is meaningful to people"
            ],
            "part3_questions": [
                "Are younger generations losing interest in cultural traditions today?",
                "How does globalization affect local cultural identity?",
                "Should governments invest public funds into preserving heritage events?"
            ]
        },
        {
            "id": "inspiring_leader",
            "topic": "Describe a person who has inspired you to achieve a goal",
            "category": "People",
            "bullets": [
                "Who this person is and your relationship to them",
                "What they did that inspired you",
                "What goal they motivated you to pursue",
                "And explain how their influence shaped your mindset"
            ],
            "part3_questions": [
                "What qualities make a truly inspiring leader?",
                "Can leadership skills be taught, or are people born leaders?",
                "How has the concept of role models changed in the era of social media?"
            ]
        },
        {
            "id": "environmental_habit",
            "topic": "Describe an environmentally friendly habit or change you made in your lifestyle",
            "category": "Environment",
            "bullets": [
                "What the habit or change is",
                "Why you decided to make this change",
                "How easy or hard it was to maintain",
                "And explain what impact you believe it has"
            ],
            "part3_questions": [
                "Whose responsibility is climate change: individual citizens or corporations?",
                "How can schools educate children to care for the environment from a young age?",
                "Will renewable energy completely replace fossil fuels in the near future?"
            ]
        }
    ]
}

@app.get("/ielts/topics")
async def get_ielts_exam_topics():
    """2025-2026 sınav tarzı konu kartları havuzu"""
    return IELTS_EXAM_TOPICS_2026

@app.post("/ielts/evaluate", response_model=IeltsEvaluationResponse)
async def evaluate_ielts_speaking(request: IeltsEvaluationRequest):
    """IELTS Speaking sınavını 4 resmi kritere göre detaylı değerlendirir ve karne üretir"""
    try:
        conversation_text = ""
        candidate_responses = []
        
        for msg in request.conversation_history:
            role = "Examiner" if msg["role"] == "assistant" else "Candidate"
            conversation_text += f"{role}: {msg['content']}\n"
            if msg["role"] == "user":
                candidate_responses.append(msg["content"])

        if not candidate_responses:
            return IeltsEvaluationResponse(
                band_score=0.0,
                feedback="No candidate responses to evaluate."
            )

        prompt = f"""You are an official Cambridge/IDP certified IELTS Speaking senior examiner.
Evaluate this IELTS Speaking test conversation:

CONVERSATION:
{conversation_text}

Evaluate according to the official IELTS Band Descriptors (0 to 9.0 in 0.5 increments):
1. Fluency and Coherence (0-9)
2. Lexical Resource / Vocabulary (0-9)
3. Grammatical Range and Accuracy (0-9)
4. Pronunciation (estimate based on sentence phonetics/cadence) (0-9)

Overall Band Score = average of four rounded to nearest 0.5.

Provide your response in JSON format ONLY:
{{
  "band_score": 6.5,
  "fluency_score": 6.5,
  "vocabulary_score": 6.5,
  "grammar_score": 6.0,
  "coherence_score": 6.5,
  "pronunciation_score": 6.5,
  "feedback": "2-3 sentences summarizing the candidate's performance professionally.",
  "strengths": ["Spoke with confidence without long pauses", "Good use of discourse markers (However, Furthermore)"],
  "weaknesses": ["Occasional slip in subject-verb agreement", "Repeated simple adjectives like 'good' and 'nice'"],
  "actionable_tips": [
    "To move to Band 7.5: Practice using conditional sentences (If I had known, I would have...)",
    "Incorporate idiomatic collocations naturally rather than simple standalone words."
  ]
}}"""

        try:
            model = genai.GenerativeModel('gemini-2.5-flash')
            response = model.generate_content(prompt)
            result_text = response.text.strip()
            
            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0].strip()
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0].strip()
            
            result = json.loads(result_text)
            
            return IeltsEvaluationResponse(
                band_score=float(result.get("band_score", 6.0)),
                feedback=result.get("feedback", "Exam successfully evaluated."),
                fluency_score=result.get("fluency_score", 6.0),
                vocabulary_score=result.get("vocabulary_score", 6.0),
                grammar_score=result.get("grammar_score", 6.0),
                coherence_score=result.get("coherence_score", 6.0),
                pronunciation_score=result.get("pronunciation_score", 6.0),
                strengths=result.get("strengths", ["Clear responses", "Good attempt at complex sentences"]),
                weaknesses=result.get("weaknesses", ["Expand vocabulary range", "Watch tense consistency"]),
                actionable_tips=result.get("actionable_tips", [
                    "To reach Band 7.5+: Use a wider range of cohesive devices and idioms.",
                    "Practice speaking for 2 full minutes without hesitations on Part 2."
                ])
            )

        except Exception as gemini_error:
            print(f"Gemini Evaluation Error: {gemini_error}")
            total_words = sum(len(r.split()) for r in candidate_responses)
            est_score = 7.0 if total_words > 120 else (6.0 if total_words > 60 else 5.0)
            return IeltsEvaluationResponse(
                band_score=est_score,
                feedback="Your IELTS performance shows solid comprehension and good conversational capability. Continue enriching your vocabulary to raise your band score.",
                fluency_score=est_score,
                vocabulary_score=est_score,
                grammar_score=est_score,
                coherence_score=est_score,
                pronunciation_score=est_score,
                strengths=["Engaged actively with the examiner", "Clear communication of ideas"],
                weaknesses=["Could provide more elaborate explanations in Part 3"],
                actionable_tips=[
                    f"To move from {est_score} to {est_score + 1.0}: Incorporate advanced collocations and complex sentence structures."
                ]
            )

    except Exception as e:
        print(f"IELTS Evaluation Error: {e}")
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")

# Multi-Exam Support (IELTS & TOEFL iBT)
class ExamConversationRequest(BaseModel):
    exam_type: str  # "ielts", "toefl"
    task_index: int  # 1, 2, 3
    user_message: str
    conversation_history: List[dict] = []
    task_prompt: Optional[str] = None
    is_last_turn: bool = False  # Bölümün son cevabı: yeni soru sorma

class ExamEvaluationRequest(BaseModel):
    exam_type: str  # "ielts", "toefl"
    conversation_history: List[dict]
    listen_repeat_accuracy: Optional[float] = None  # TOEFL Listen and Repeat ortalama doğruluğu (%)

class ExamEvaluationResponse(BaseModel):
    exam_type: str
    score: float
    score_display: str
    cefr_level: str
    feedback: str
    criteria_scores: Dict[str, float] = {}
    strengths: List[str] = []
    improvement_areas: List[str] = []
    recommended_practice: List[str] = []

@app.post("/exam/conversation", response_model=ConversationResponse)
async def exam_conversation(request: ExamConversationRequest):
    """TOEFL iBT (ve IELTS) için sınav simülatörü endpoint'i"""
    exam_type = request.exam_type.lower()
    
    if exam_type == "toefl":
        # TOEFL iBT 2026: Speaking = Listen and Repeat (uygulamada, AI'sız) + Take an Interview
        system_prompt = f"""You are the interviewer in a TOEFL iBT-style (2026 format) "Take an Interview" speaking task.
The interview has exactly 4 questions on ONE academic or campus-life topic, getting harder each time:
Q1 describe a personal experience (already asked), Q2 explain or compare, Q3 give and support an opinion, Q4 predict or discuss a hypothetical situation.

Interview material:
{request.task_prompt or 'Interview scenario: a university survey about student life.'}

Rules:
- Count the candidate's answers in the conversation and ask the NEXT question in the sequence, staying on the same topic.
- Start with a very short neutral acknowledgment (max 6 words), then ask ONE clear question. Keep the whole reply under 35 words.
- Do NOT give feedback, scores or band levels during the interview."""
    else:
        # Default to IELTS
        part = min(max(request.task_index, 1), 3)
        system_prompt = IELTS_PROMPTS.get(part, IELTS_PROMPTS[1]).replace(
            "{topic_card}", request.task_prompt or "(the topic card shown to the candidate)"
        )

    history_text = ""
    for msg in request.conversation_history[-10:]:
        role = "Examiner" if msg["role"] == "assistant" else "Candidate"
        history_text += f"{role}: {msg['content']}\n"

    prompt = f"""{system_prompt}

Previous conversation:
{history_text}

Candidate's response: {request.user_message}
{LAST_TURN_RULE if request.is_last_turn else ''}

Instructions:
1. Respond naturally and professionally as the {exam_type.upper()} examiner.
2. Provide feedback in JSON format inside <feedback> tags.

Response format:
[Your natural examiner response]

<feedback>
{{
  "grammar_corrections": ["'exact words the candidate said' -> 'corrected version' (short rule name) - max 2; use an EMPTY list [] if there are no mistakes"],
  "vocabulary_suggestions": ["academic synonyms - max 2"],
  "general_feedback": "Brief comment on performance"
}}
</feedback>"""

    try:
        model = genai.GenerativeModel('gemini-2.5-flash')
        response = model.generate_content(prompt)
        ai_response_raw = response.text
    except Exception as e:
        ai_response_raw = "Thank you. Let's move to the next question."

    feedback_data = {
        "ai_message": ai_response_raw,
        "feedback": None,
        "grammar_corrections": [],
        "vocabulary_suggestions": []
    }
    if "<feedback>" in ai_response_raw and "</feedback>" in ai_response_raw:
        parts = ai_response_raw.split("<feedback>")
        feedback_data["ai_message"] = parts[0].strip()
        try:
            fb_json = json.loads(parts[1].split("</feedback>")[0].strip())
            feedback_data["feedback"] = fb_json.get("general_feedback", "")
            feedback_data["grammar_corrections"] = fb_json.get("grammar_corrections", [])
            feedback_data["vocabulary_suggestions"] = fb_json.get("vocabulary_suggestions", [])
        except Exception:
            pass

    return ConversationResponse(**feedback_data)

EXAM_CRITERIA = {
    "ielts": [
        "Fluency and Coherence",
        "Lexical Resource",
        "Grammatical Range and Accuracy",
        "Pronunciation",
    ],
    # TOEFL iBT 2026: Listen and Repeat (doğruluk, anlaşılırlık) + Take an Interview (akıcılık, dil, detaylandırma)
    "toefl": ["Repeat Accuracy", "Fluency & Pace", "Vocabulary & Grammar", "Elaboration"],
}

def _normalize_band(raw, exam_type: str) -> float:
    """Skoru 0.5 adıma yuvarla: TOEFL 1-6, IELTS 0-9"""
    low, high, default = (1.0, 6.0, 4.0) if exam_type == "toefl" else (0.0, 9.0, 6.5)
    try:
        value = float(raw)
    except (TypeError, ValueError):
        value = default
    return min(max(round(value * 2) / 2, low), high)


def _toefl_cefr(band: float) -> str:
    """ETS 1-6 bant -> CEFR eşlemesi (6=C2, 5-5.5=C1, 4-4.5=B2, 3-3.5=B1, 2-2.5=A2, 1-1.5=A1)"""
    for threshold, level in ((6.0, "C2"), (5.0, "C1"), (4.0, "B2"), (3.0, "B1"), (2.0, "A2")):
        if band >= threshold:
            return level
    return "A1"


def _coerce_scores(raw) -> Dict[str, float]:
    """Gemini bazen puanları metin ("7.5") döndürüyor; sayıya çevrilemeyenleri at"""
    scores = {}
    if isinstance(raw, dict):
        for k, v in raw.items():
            try:
                scores[str(k)] = float(v)
            except (TypeError, ValueError):
                continue
    return scores

@app.post("/exam/evaluate", response_model=ExamEvaluationResponse)
async def evaluate_general_exam(request: ExamEvaluationRequest):
    """IELTS ve TOEFL sınavları için ortak değerlendirme ve karne motoru"""
    exam_type = request.exam_type.lower()
    # Desteklenmeyen tür (ör. eski sürümlerden gelen "det") IELTS olarak değerlendirilir
    if exam_type not in EXAM_CRITERIA:
        exam_type = "ielts"
    conv_text = "\n".join([f"{m.get('role', 'user')}: {m.get('content', '')}" for m in request.conversation_history])

    # Karne (PDF) ve arayüz bu kriter adlarını gösterir; modele açıkça veriyoruz
    criteria_names = EXAM_CRITERIA.get(exam_type, EXAM_CRITERIA["ielts"])
    if exam_type == "toefl":
        accuracy_note = (
            f"Listen and Repeat word accuracy measured by the app: {request.listen_repeat_accuracy:.0f}% average over the repeated sentences. "
            "Base 'Repeat Accuracy' mainly on this number."
            if request.listen_repeat_accuracy is not None else
            "Judge 'Repeat Accuracy' by comparing each repeated sentence with the original sentence in the transcript."
        )
        criteria_rules = ("TOEFL iBT 2026 format (Listen and Repeat + Take an Interview). "
                          "Overall band 1.0 to 6.0 in 0.5 steps, CEFR aligned: 6 = C2, 5-5.5 = C1, 4-4.5 = B2, 3-3.5 = B1, 2-2.5 = A2, 1-1.5 = A1. "
                          "Score each criterion on the same 1.0-6.0 band scale. " + accuracy_note)
        score_display_example = "<score> / 6"
    else:
        criteria_rules = "Overall band 0.0 to 9.0 in 0.5 steps (official IELTS band descriptors). Score each criterion as a band from 0.0 to 9.0."
        score_display_example = "Band <score> / 9.0"
    criteria_json_example = ",\n".join([f'    "{c}": <number>' for c in criteria_names])
    
    prompt = f"""You are a senior standardized English language examiner evaluating a {exam_type.upper()} Speaking test.
Conversation transcript:
{conv_text}

Scoring rules for this {exam_type.upper()} test:
{criteria_rules}

Return JSON ONLY:
{{
  "score": <number>,
  "score_display": "{score_display_example}",
  "cefr_level": "<B1/B2/C1/C2>",
  "feedback": "Comprehensive 2-3 sentence performance summary",
  "criteria_scores": {{
{criteria_json_example}
  }},
  "strengths": ["List 2-3 notable strengths"],
  "improvement_areas": ["List 2-3 specific areas for growth"],
  "recommended_practice": ["Actionable study recommendations to reach the next tier"]
}}"""

    try:
        model = genai.GenerativeModel('gemini-2.5-flash')
        response = model.generate_content(prompt)
        raw = response.text.strip()
        if "```json" in raw:
            raw = raw.split("```json")[1].split("```")[0].strip()
        elif "```" in raw:
            raw = raw.split("```")[1].split("```")[0].strip()
        data = json.loads(raw)
        # Puanı resmi ölçeğe oturt (0.5 adım) ve gösterimi/CEFR'i tutarlı üret
        score = _normalize_band(data.get("score"), exam_type)
        if exam_type == "toefl":
            score_display = f"{score:.1f} / 6"
            cefr_level = _toefl_cefr(score)
        else:
            score_display = f"Band {score:.1f} / 9.0"
            cefr_level = data.get("cefr_level", "B2")
        return ExamEvaluationResponse(
            exam_type=exam_type,
            score=score,
            score_display=score_display,
            cefr_level=cefr_level,
            feedback=data.get("feedback", "Test completed successfully."),
            criteria_scores=_coerce_scores(data.get("criteria_scores", {})),
            strengths=data.get("strengths", ["Good coherence", "Fluid responses"]),
            improvement_areas=data.get("improvement_areas", ["Lexical variety"]),
            recommended_practice=data.get("recommended_practice", ["Daily targeted speaking practice"])
        )
    except Exception as e:
        print(f"Exam Evaluation Error: {e}")
        default_score = 4.0 if exam_type == "toefl" else 6.5
        default_display = "4.0 / 6" if exam_type == "toefl" else "Band 6.5 / 9.0"
        default_criterion = 4.0 if exam_type == "toefl" else 6.5
        return ExamEvaluationResponse(
            exam_type=exam_type,
            score=float(default_score),
            score_display=default_display,
            cefr_level="B2",
            feedback=f"Your {exam_type.upper()} speaking performance demonstrates conversational competence and clear communication.",
            criteria_scores={c: default_criterion for c in EXAM_CRITERIA.get(exam_type, EXAM_CRITERIA["ielts"])},
            strengths=["Clear articulation", "Consistent conversational flow"],
            improvement_areas=["Increase academic vocabulary usage"],
            recommended_practice=["Practice timed speaking on abstract topics"]
        )
 