from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional, List, Dict
from dotenv import load_dotenv
from contextlib import asynccontextmanager
import google.generativeai as genai
import os
import json
import shutil
import uuid
from datetime import datetime

load_dotenv()

# --- Persistence Layer ---
DB_FILE = "users_db.json"
UPLOADS_DIR = "uploads"

# Ensure uploads directory exists
os.makedirs(UPLOADS_DIR, exist_ok=True)

def load_db() -> Dict:
# ... (existing load_db content) ...
    if not os.path.exists(DB_FILE):
        return {"users": {}}
    try:
        with open(DB_FILE, "r") as f:
            return json.load(f)
    except json.JSONDecodeError:
        return {"users": {}}

def save_db(data: Dict):
    with open(DB_FILE, "w") as f:
        json.dump(data, f, indent=2)

def get_user_data(user_id: str) -> Dict:
    db = load_db()
    users = db.get("users", {})
    if user_id not in users:
        # Default user structure
        users[user_id] = {
            "user_id": user_id,
            "total_conversations": 0,
            "total_time_minutes": 0,
            "weekly_xp": 0,  # New: for leaderboard
            "current_level": "beginner",
            "completed_scenarios": [],
            "last_active": datetime.now().isoformat(),
            "display_name": f"User {user_id[-4:]}" # Placeholder name
        }
        save_db(db)
        return users[user_id]
    return users[user_id]

def update_user_data(user_id: str, data: Dict):
    db = load_db()
    if "users" not in db:
        db["users"] = {}
    
    # Ensure user exists
    if user_id not in db["users"]:
        get_user_data(user_id) # create default
        db = load_db() # reload
    
    # Update fields
    db["users"][user_id].update(data)
    save_db(db)

# --- End Persistence Layer ---

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
async def upload_avatar(file: UploadFile = File(...)):
    """Avatar yükle ve URL döndür"""
    try:
        # Dosya uzantısını al
        file_ext = os.path.splitext(file.filename)[1]
        if file_ext.lower() not in ['.jpg', '.jpeg', '.png', '.gif', '.webp']:
            raise HTTPException(status_code=400, detail="Only images are allowed")
            
        # Benzersiz isim oluştur
        filename = f"{uuid.uuid4()}{file_ext}"
        file_path = os.path.join(UPLOADS_DIR, filename)
        
        # Dosyayı kaydet
        with open(file_path, "wb") as buffer:
            shutil.copyfileobj(file.file, buffer)
            
        # URL oluştur (Local host için)
        file_url = f"http://localhost:8000/uploads/{filename}"
        
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

class ConversationResponse(BaseModel):
    ai_message: str
    feedback: Optional[str] = None
    grammar_corrections: List[str] = []
    vocabulary_suggestions: List[str] = []

class ScenarioInfo(BaseModel):
    id: str
    title: str
    description: str
    difficulty: str
    estimated_time: int

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
        "title": "Restoranda Sipariş",
        "description": "Bir restoranda yemek siparişi vermeyi öğren",
        "difficulty": "beginner",
        "estimated_time": 5,
        "system_prompt": "You are a friendly waiter at a restaurant. Help the user practice ordering food in English. Speak naturally but clearly. After each user message, provide gentle corrections if needed."
    },
    {
        "id": "job_interview",
        "title": "İş Görüşmesi",
        "description": "İş görüşmesinde kendinizi tanıtın ve sorulara cevap verin",
        "difficulty": "intermediate",
        "estimated_time": 10,
        "system_prompt": "You are a professional interviewer conducting a job interview. Ask relevant questions and help the user practice professional English. Be encouraging but realistic."
    },
    {
        "id": "shopping",
        "title": "Alışveriş",
        "description": "Mağazada alışveriş yaparken İngilizce konuş",
        "difficulty": "beginner",
        "estimated_time": 5,
        "system_prompt": "You are a helpful shop assistant. Help the user practice shopping vocabulary and common phrases used when buying things."
    },
    {
        "id": "airport",
        "title": "Havalimanında",
        "description": "Check-in, pasaport kontrolü ve güvenlik işlemleri",
        "difficulty": "intermediate",
        "estimated_time": 8,
        "system_prompt": "You are an airport staff member (check-in agent, security, or customs). Help the user practice airport-related English conversations."
    },
    {
        "id": "small_talk",
        "title": "Günlük Sohbet",
        "description": "Yeni tanıştığınız biriyle arkadaşça sohbet edin",
        "difficulty": "beginner",
        "estimated_time": 5,
        "system_prompt": "You are a friendly person meeting someone new. Have a casual conversation, ask about their interests, hobbies, and life. Keep it natural and friendly."
    }
]

def get_scenario_by_id(scenario_id: str):
    return next((s for s in SCENARIOS if s["id"] == scenario_id), None)

@app.get("/")
async def root():
    return {
        "message": "Language Learning API is running",
        "version": "2.1.0 - Leaderboard Edition",
        "endpoints": ["/scenarios", "/conversation", "/speech-to-text", "/user/progress/{user_id}", "/leaderboard"]
    }

@app.get("/scenarios", response_model=List[ScenarioInfo])
async def get_scenarios():
    """Tüm senaryoların listesini döndürür"""
    return [
        ScenarioInfo(
            id=s["id"],
            title=s["title"],
            description=s["description"],
            difficulty=s["difficulty"],
            estimated_time=s["estimated_time"]
        )
        for s in SCENARIOS
    ]

@app.post("/conversation", response_model=ConversationResponse)
async def create_conversation(request: ConversationRequest):
    """Google Gemini kullanarak sohbet ve geri bildirim oluşturur"""
    try:
        scenario = get_scenario_by_id(request.scenario)
        if not scenario:
            raise HTTPException(status_code=404, detail="Scenario not found")

        # Konuşma geçmişini metne dönüştür
        history_text = ""
        for msg in request.conversation_history[-10:]:  # Son 10 mesajı al
            role = "Assistant" if msg["role"] == "assistant" else "User"
            history_text += f"{role}: {msg['content']}\n"

        # Gemini Prompt
        prompt = f"""You are playing the following role: {scenario['system_prompt']}

The user's English level is: {request.user_level}

Previous conversation:
{history_text}

User's new message: {request.user_message}

Instructions:
1. Respond naturally to the user's message as your character
2. Keep your response conversational and engaging
3. After your response, provide feedback in JSON format inside <feedback> tags

Response format:
[Your natural conversational response here]

<feedback>
{{
  "grammar_corrections": ["list any grammar mistakes - keep it to 1-2 most important ones"],
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
            # Gemini hatası varsa basit bir cevap döndür
            print(f"Gemini Error: {gemini_error}")
            ai_response_raw = "Hello! I'm here to help you practice English. Could you please try again?"

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
                # Feedback parse edilemezse devam et

        return ConversationResponse(**feedback_data)

    except Exception as e:
        print(f"Conversation Error: {e}")
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")

@app.post("/speech-to-text")
async def speech_to_text(audio: UploadFile = File(...)):
    """Ses-metin dönüşümü (şimdilik devre dışı - AssemblyAI kaldırıldı)"""
    return {
        "text": "Speech-to-text feature temporarily disabled. Please type your message.",
        "confidence": 0.0,
        "words": []
    }

@app.get("/user/progress/{user_id}", response_model=UserProgress)
async def get_user_progress(user_id: str):
    """Kullanıcı ilerlemesini DB'den döndürür"""
    user_data = get_user_data(user_id)
    return UserProgress(**user_data)

@app.post("/user/progress/{user_id}")
async def update_user_progress(user_id: str, update: ProgressUpdate):
    """Kullanıcı ilerlemesini günceller"""
    user_data = get_user_data(user_id)
    
    # Yeni değerleri hazırla
    new_data = {}
    if update.total_conversations is not None:
        new_data["total_conversations"] = update.total_conversations
    if update.total_time_minutes is not None:
        new_data["total_time_minutes"] = update.total_time_minutes
    if update.display_name:
        new_data["display_name"] = update.display_name
        
    if update.completed_scenario:
        scenarios = user_data.get("completed_scenarios", [])
        if update.completed_scenario not in scenarios:
            scenarios.append(update.completed_scenario)
            new_data["completed_scenarios"] = scenarios
            
    if update.added_xp:
        current_xp = user_data.get("weekly_xp", 0)
        new_data["weekly_xp"] = current_xp + update.added_xp
        
    new_data["last_active"] = datetime.now().isoformat()
    
    # DB Güncelle
    update_user_data(user_id, new_data)
    
    return {"status": "success", "updated_fields": list(new_data.keys())}

@app.get("/leaderboard", response_model=List[LeaderboardEntry])
async def get_leaderboard():
    """Haftalık liderlik tablosunu döndürür"""
    db = load_db()
    users = db.get("users", {})
    
    # Listeye çevir
    user_list = []
    for uid, data in users.items():
        user_list.append({
            "user_id": uid,
            "display_name": data.get("display_name", f"User {uid[-4:]}"),
            "weekly_xp": data.get("weekly_xp", 0),
            "avatar_url": data.get("avatar_url")
        })
    
    # Puanına göre sırala (büyükten küçüğe)
    sorted_users = sorted(user_list, key=lambda x: x["weekly_xp"], reverse=True)
    
    # Top 50'yi al ve rank ekle
    leaderboard = []
    for idx, user in enumerate(sorted_users[:50]):
        entry = LeaderboardEntry(
            rank=idx + 1,
            user_id=user["user_id"],
            display_name=user["display_name"],
            weekly_xp=user["weekly_xp"],
            avatar_url=user["avatar_url"]
        )
        leaderboard.append(entry)
        
    return leaderboard


# IELTS Speaking Models
class IeltsConversationRequest(BaseModel):
    part: int  # 1, 2, or 3
    user_message: str
    conversation_history: List[dict] = []
    topic_card: Optional[str] = None


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
- Home/accommodation, family, work/studies, hobbies, daily routine, hometown""",

    2: """You are a professional IELTS speaking examiner conducting Part 2 of the test.
The candidate has been given a topic card and has just finished speaking for 1-2 minutes.
Your role:
- Listen to their response about the topic card
- Ask 1-2 brief follow-up questions related to their topic
- Be encouraging but professional
- Transition smoothly when ready to move to Part 3

Topic card given to candidate: {topic_card}""",

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
- Discussing trends, changes, and future implications"""
}


@app.post("/ielts/conversation", response_model=ConversationResponse)
async def ielts_conversation(request: IeltsConversationRequest):
    """IELTS Speaking sınavı için özel endpoint"""
    try:
        # Part için sistem promptunu al
        part = min(max(request.part, 1), 3)  # 1-3 arası sınırla
        system_prompt = IELTS_PROMPTS.get(part, IELTS_PROMPTS[1])
        
        # Part 2 için topic card'ı prompt'a ekle
        if part == 2 and request.topic_card:
            system_prompt = system_prompt.format(topic_card=request.topic_card)

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
  "grammar_corrections": ["list any significant grammar mistakes - max 2"],
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


@app.post("/ielts/evaluate", response_model=IeltsEvaluationResponse)
async def evaluate_ielts_speaking(request: IeltsEvaluationRequest):
    """IELTS Speaking sınavını değerlendir ve band score hesapla"""
    try:
        # Konuşma geçmişini metne dönüştür
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

        # Gemini ile değerlendirme
        prompt = f"""You are an experienced IELTS Speaking examiner. Evaluate the following IELTS Speaking test conversation.

CONVERSATION:
{conversation_text}

Evaluate the candidate's performance based on the official IELTS Speaking assessment criteria:
1. Fluency and Coherence (0-9)
2. Lexical Resource / Vocabulary (0-9)
3. Grammatical Range and Accuracy (0-9)
4. Pronunciation (assume average pronunciation since this is text-based) (0-9)

Calculate the overall band score as the average of these four criteria, rounded to the nearest 0.5.

Provide your assessment in the following JSON format ONLY (no other text):
{{
  "band_score": <overall band score as float, e.g. 6.5>,
  "fluency_score": <fluency score>,
  "vocabulary_score": <vocabulary score>,
  "grammar_score": <grammar score>,
  "coherence_score": <coherence score>,
  "feedback": "<Brief 2-3 sentence feedback in Turkish summarizing the candidate's strengths and areas for improvement>"
}}"""

        try:
            model = genai.GenerativeModel('gemini-2.5-flash')
            response = model.generate_content(prompt)
            result_text = response.text.strip()
            
            # Extract JSON from response
            if "```json" in result_text:
                result_text = result_text.split("```json")[1].split("```")[0].strip()
            elif "```" in result_text:
                result_text = result_text.split("```")[1].split("```")[0].strip()
            
            result = json.loads(result_text)
            
            return IeltsEvaluationResponse(
                band_score=float(result.get("band_score", 5.0)),
                feedback=result.get("feedback", "Değerlendirme tamamlandı."),
                fluency_score=result.get("fluency_score"),
                vocabulary_score=result.get("vocabulary_score"),
                grammar_score=result.get("grammar_score"),
                coherence_score=result.get("coherence_score")
            )

        except Exception as gemini_error:
            print(f"Gemini Evaluation Error: {gemini_error}")
            # Basit bir fallback hesaplama
            avg_response_length = sum(len(r.split()) for r in candidate_responses) / len(candidate_responses)
            
            # Basit bir puan tahmini
            if avg_response_length >= 50:
                estimated_score = 7.0
            elif avg_response_length >= 30:
                estimated_score = 6.0
            elif avg_response_length >= 15:
                estimated_score = 5.0
            else:
                estimated_score = 4.5
            
            return IeltsEvaluationResponse(
                band_score=estimated_score,
                feedback="Sınav performansınız değerlendirildi. Daha uzun ve detaylı cevaplar vererek puanınızı artırabilirsiniz."
            )

    except Exception as e:
        print(f"IELTS Evaluation Error: {e}")
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")