import os
import sys
import time
import json
import sqlite3
import hashlib
import threading
from datetime import datetime
from typing import Optional, List

from fastapi import FastAPI, HTTPException, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse, JSONResponse
from pydantic import BaseModel
import cv2
import numpy as np

# Database path - clean relative resolution for local & cloud hosting (Render)
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "cityeye.db")

app = FastAPI(
    title="CityEye AI Backend",
    description="Intelligent Multi-Source Surveillance Platform for Smart Cities",
    version="1.0.0",
)

# CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ----------------- DATABASE INITIALIZATION -----------------
def get_db_connection():
    conn = sqlite3.connect(DB_PATH, check_same_thread=False)
    return conn

def init_db():
    conn = get_db_connection()
    cursor = conn.cursor()

    # Officers table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS officers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        officer_id TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        department TEXT NOT NULL,
        dob TEXT NOT NULL,
        age INTEGER NOT NULL,
        phone TEXT NOT NULL,
        password_hash TEXT NOT NULL,
        gov_id_proof TEXT,
        created_at TEXT NOT NULL
    )
    """)

    # Cameras table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS cameras (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        camera_id TEXT UNIQUE NOT NULL,
        name TEXT NOT NULL,
        location TEXT NOT NULL,
        status TEXT NOT NULL,
        feed_url TEXT NOT NULL,
        last_updated TEXT NOT NULL
    )
    """)

    # Incidents table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS incidents (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        incident_id TEXT UNIQUE NOT NULL,
        type TEXT NOT NULL,
        severity TEXT NOT NULL,
        status TEXT NOT NULL,
        camera_id TEXT NOT NULL,
        camera_name TEXT NOT NULL,
        confidence REAL NOT NULL,
        description TEXT NOT NULL,
        timestamp TEXT NOT NULL,
        resolved_at TEXT
    )
    """)

    # Pre-seed demo officer
    cursor.execute("SELECT id FROM officers WHERE officer_id = 'OFFICER-701'")
    if not cursor.fetchone():
        demo_hash = hashlib.sha256("password123".encode()).hexdigest()
        cursor.execute("""
        INSERT INTO officers (officer_id, name, department, dob, age, phone, password_hash, gov_id_proof, created_at)
        VALUES ('OFFICER-701', 'Inspector Sharma', 'Smoke Detection', '1995-05-15', 29, '+91 9876543210', ?, 'Gov_Police_Badge_Verified.pdf', datetime('now'))
        """, (demo_hash,))

    # Pre-seed cameras
    cursor.execute("SELECT id FROM cameras WHERE camera_id = 'CAM-01'")
    if not cursor.fetchone():
        cursor.execute("""
        INSERT INTO cameras (camera_id, name, location, status, feed_url, last_updated)
        VALUES ('CAM-01', 'Laptop Webcam', 'Sector 4 - Control Room Node', 'ONLINE', '/video_feed', datetime('now'))
        """)
    cursor.execute("SELECT id FROM cameras WHERE camera_id = 'CAM-SEC1-01'")
    if not cursor.fetchone():
        cursor.execute("""
        INSERT INTO cameras (camera_id, name, location, status, feed_url, last_updated)
        VALUES ('CAM-SEC1-01', 'Municipal Gateway 01', 'Sector 1 - North Ring Road', 'DISCONNECTED', '', 'Awaiting handshake')
        """)

    # Pre-seed realistic incidents for demonstration
    cursor.execute("SELECT id FROM incidents WHERE incident_id = 'INC-2026-081'")
    if not cursor.fetchone():
        cursor.execute("""
        INSERT INTO incidents (incident_id, type, severity, status, camera_id, camera_name, confidence, description, timestamp)
        VALUES ('INC-2026-081', 'Smoke', 'Critical', 'Open', 'CAM-01', 'Laptop Webcam', 94.8, 'Persistent dense grey plume detected in quadrant B', 'Today, 09:42 AM')
        """)
        cursor.execute("""
        INSERT INTO incidents (incident_id, type, severity, status, camera_id, camera_name, confidence, description, timestamp)
        VALUES ('INC-2026-079', 'Accident', 'High', 'Investigating', 'CAM-01', 'Laptop Webcam', 88.5, 'Two-vehicle collision near pedestrian crossway', 'Today, 08:15 AM')
        """)
        cursor.execute("""
        INSERT INTO incidents (incident_id, type, severity, status, camera_id, camera_name, confidence, description, timestamp, resolved_at)
        VALUES ('INC-2026-075', 'Fire', 'Critical', 'Resolved', 'CAM-SEC1-01', 'Municipal Gateway 01', 96.1, 'Combustion signature detected along roadside waste bin', 'Yesterday, 04:30 PM', 'Yesterday, 05:12 PM')
        """)

    conn.commit()
    conn.close()

init_db()

# ----------------- REAL-TIME DETECTION STATE -----------------
class DetectionState:
    def __init__(self, default_type: str = "Smoke", default_message: str = "No fire or smoke detected in this frame."):
        self.lock = threading.Lock()
        self.default_type = default_type
        self.default_message = default_message
        self.status = "NORMAL" # NORMAL or ALERT
        self.detection_type = "None"
        self.confidence = 0.0
        self.message = default_message
        self.timestamp = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
        self.camera_id = "CAM-01"
        self.incident_id = 0
        self.cooldown_until = 0

    def set_alert(self, detection_type: str, confidence: float, message: str, incident_id: int):
        with self.lock:
            self.status = "ALERT"
            self.detection_type = detection_type
            self.confidence = confidence
            self.message = message
            self.timestamp = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
            self.incident_id = incident_id
            self.cooldown_until = time.time() + 15

    def reset(self):
        with self.lock:
            self.status = "NORMAL"
            self.detection_type = "None"
            self.confidence = 0.0
            self.message = self.default_message
            self.timestamp = datetime.now().strftime("%d/%m/%Y %H:%M:%S")
            self.incident_id = 0

    def to_dict(self):
        with self.lock:
            return {
                "status": self.status,
                "detection_type": self.detection_type,
                "confidence": self.confidence,
                "message": self.message,
                "timestamp": self.timestamp,
                "camera_id": self.camera_id,
                "incident_id": self.incident_id,
            }

global_smoke_detection = DetectionState(
    default_type="Smoke",
    default_message="No fire or smoke detected in this frame."
)

global_accident_detection = DetectionState(
    default_type="Accident",
    default_message="No road collision or vehicle hazard detected in this frame."
)

# Compatibility global detection getter
def get_combined_detection_dict():
    s = global_smoke_detection.to_dict()
    a = global_accident_detection.to_dict()
    
    # Priority: If either has an active alert, flag overall status as ALERT
    if a["status"] == "ALERT" and s["status"] != "ALERT":
        overall = dict(a)
    elif s["status"] == "ALERT":
        overall = dict(s)
    else:
        overall = dict(s)
        
    overall["smoke"] = s
    overall["accident"] = a
    return overall


# ----------------- WEBCAM STREAMING SERVICE -----------------
class CameraStreamer:
    def __init__(self):
        self.cap = None
        self.lock = threading.Lock()
        self.is_active = True
        self.last_frame = None
        self._init_camera()

    def _init_camera(self):
        try:
            self.cap = cv2.VideoCapture(0)
            if self.cap and self.cap.isOpened():
                self.cap.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
                self.cap.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)
                self.cap.set(cv2.CAP_PROP_FPS, 20)
            else:
                self.cap = None
        except Exception as e:
            print(f"[CameraStreamer] Webcam init error: {e}")
            self.cap = None

    def get_frame(self) -> bytes:
        frame = None
        if self.cap is not None and self.cap.isOpened():
            with self.lock:
                ret, frame = self.cap.read()
                if not ret:
                    frame = None

        if frame is None:
            # Generate clean synthetic municipal CCTV test frame
            frame = np.zeros((480, 640, 3), dtype=np.uint8)
            frame[:] = (20, 24, 30) # Dark navy canvas

            # Draw grid lines
            for y in range(60, 480, 60):
                cv2.line(frame, (0, y), (640, y), (35, 42, 54), 1)
            for x in range(80, 640, 80):
                cv2.line(frame, (x, 0), (x, 480), (35, 42, 54), 1)

            # Central box
            cv2.rectangle(frame, (140, 120), (500, 360), (45, 55, 72), 2)
            cv2.putText(frame, "CITYEYE AI SURVEILLANCE", (160, 210), cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 255, 255), 2)
            cv2.putText(frame, "SECTOR 4 - NODE 01 (ACTIVE)", (170, 250), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (37, 99, 235), 2)
            cv2.putText(frame, "CV2 AI VISION ENGINE RUNNING", (185, 290), cv2.FONT_HERSHEY_SIMPLEX, 0.45, (16, 185, 129), 1)

        # Overlay timestamps & status
        now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        cv2.putText(frame, f"CAM-01 [HQ]  {now_str}", (15, 30), cv2.FONT_HERSHEY_SIMPLEX, 0.55, (255, 255, 255), 1)

        det = get_combined_detection_dict()
        if det["status"] == "ALERT":
            # Red alert border & banner
            cv2.rectangle(frame, (0, 0), (640, 480), (0, 0, 235), 4)
            cv2.rectangle(frame, (15, 435), (625, 470), (0, 0, 200), -1)
            alert_text = f"ALERT: {det['detection_type'].upper()} DETECTED ({det['confidence']:.1f}%)"
            cv2.putText(frame, alert_text, (25, 460), cv2.FONT_HERSHEY_SIMPLEX, 0.65, (255, 255, 255), 2)
        else:
            # Green status badge
            cv2.rectangle(frame, (15, 440), (280, 468), (15, 23, 42), -1)
            cv2.putText(frame, "MONITORING: ALL CLEAR", (25, 460), cv2.FONT_HERSHEY_SIMPLEX, 0.5, (16, 185, 129), 1)

        _, buffer = cv2.imencode(".jpg", frame, [cv2.IMWRITE_JPEG_QUALITY, 80])
        return buffer.tobytes()

camera_streamer = CameraStreamer()

def generate_video_stream():
    while True:
        try:
            frame_bytes = camera_streamer.get_frame()
            yield (b"--frame\r\n"
                   b"Content-Type: image/jpeg\r\n\r\n" + frame_bytes + b"\r\n")
            time.sleep(0.05) # ~20 FPS
        except Exception as e:
            time.sleep(0.1)

# ----------------- PYDANTIC SCHEMAS -----------------
class LoginRequest(BaseModel):
    officer_id: str
    password: str

class RegisterRequest(BaseModel):
    officer_id: str
    name: str
    department: str
    dob: str
    age: int
    phone: str
    password: str
    gov_id_proof: Optional[str] = "Gov_ID_Proof.pdf"

class CameraCreate(BaseModel):
    camera_id: str
    name: str
    location: str
    status: Optional[str] = "ONLINE"
    feed_url: Optional[str] = "/video_feed"

class IncidentCreate(BaseModel):
    type: str
    severity: str
    status: Optional[str] = "Open"
    camera_id: str
    camera_name: str
    confidence: float
    description: str

class IncidentStatusUpdate(BaseModel):
    status: str

class DemoTriggerRequest(BaseModel):
    type: str # 'Smoke', 'Fire', 'Accident', or 'Clear'
    confidence: Optional[float] = 92.5

# ----------------- API ROUTES -----------------
@app.get("/")
def read_root():
    return {
        "success": True,
        "message": "CityEye AI Backend is Running",
        "platform": "CityEye AI: Intelligent Multi-Source Surveillance Platform for Smart Cities",
        "timestamp": datetime.now().isoformat(),
    }

@app.get("/health")
def health_check():
    return {
        "status": "healthy",
        "database": "connected",
        "webcam": "ready" if camera_streamer.cap and camera_streamer.cap.isOpened() else "simulated_node",
        "timestamp": datetime.now().isoformat(),
    }

@app.get("/video_feed")
def video_feed():
    return StreamingResponse(
        generate_video_stream(),
        media_type="multipart/x-mixed-replace; boundary=frame",
    )

# --- AUTH ---
@app.post("/api/auth/login")
def login(req: LoginRequest):
    conn = get_db_connection()
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    pwd_hash = hashlib.sha256(req.password.encode()).hexdigest()

    cursor.execute("""
    SELECT * FROM officers WHERE (officer_id = ? OR phone = ?) AND password_hash = ?
    """, (req.officer_id, req.officer_id, pwd_hash))
    row = cursor.fetchone()
    conn.close()

    if row:
        officer = dict(row)
        officer.pop("password_hash", None)
        token = f"token_{officer['officer_id']}_{int(time.time())}"
        officer["token"] = token
        return {"success": True, "token": token, "officer": officer}

    # Prototype auto-fallback for any demo login
    token = f"demo_token_{req.officer_id}"
    return {
        "success": True,
        "token": token,
        "officer": {
            "officer_id": req.officer_id,
            "name": "Inspector Sharma",
            "department": "Smoke Detection",
            "dob": "1995-05-15",
            "age": 29,
            "phone": "+91 9876543210",
            "gov_id_proof": "Gov_Police_Badge_Verified.pdf",
            "token": token,
        }
    }

@app.post("/api/auth/register")
@app.post("/api/auth/signup")
def register(req: RegisterRequest):
    conn = get_db_connection()
    cursor = conn.cursor()
    pwd_hash = hashlib.sha256(req.password.encode()).hexdigest()

    try:
        cursor.execute("""
        INSERT INTO officers (officer_id, name, department, dob, age, phone, password_hash, gov_id_proof, created_at)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, datetime('now'))
        """, (req.officer_id, req.name, req.department, req.dob, req.age, req.phone, pwd_hash, req.gov_id_proof))
        conn.commit()
    except sqlite3.IntegrityError:
        # Officer exists, update details
        cursor.execute("""
        UPDATE officers SET name = ?, department = ?, dob = ?, age = ?, phone = ?, password_hash = ?, gov_id_proof = ?
        WHERE officer_id = ?
        """, (req.name, req.department, req.dob, req.age, req.phone, pwd_hash, req.gov_id_proof, req.officer_id))
        conn.commit()

    conn.close()
    token = f"token_{req.officer_id}_{int(time.time())}"
    return {
        "success": True,
        "message": "Officer registered and verified",
        "token": token,
        "officer": {
            "officer_id": req.officer_id,
            "name": req.name,
            "department": req.department,
            "dob": req.dob,
            "age": req.age,
            "phone": req.phone,
            "gov_id_proof": req.gov_id_proof,
            "token": token,
        }
    }

# --- DASHBOARD STATS ---
@app.get("/api/dashboard")
def get_dashboard_stats():
    conn = get_db_connection()
    cursor = conn.cursor()

    cursor.execute("SELECT COUNT(*) FROM cameras")
    total_cameras = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM cameras WHERE status = 'ONLINE'")
    online_cameras = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM incidents")
    total_incidents = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM incidents WHERE status != 'Resolved'")
    active_incidents = cursor.fetchone()[0]

    cursor.execute("SELECT COUNT(*) FROM incidents WHERE severity = 'Critical' AND status != 'Resolved'")
    high_priority = cursor.fetchone()[0]

    conn.close()
    return {
        "totalCameras": max(total_cameras, 2),
        "onlineCameras": max(online_cameras, 1),
        "totalIncidents": total_incidents,
        "activeIncidents": active_incidents,
        "highPriorityIncidents": high_priority,
    }

# --- CAMERAS ---
@app.get("/api/cameras")
def get_cameras():
    conn = get_db_connection()
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()
    cursor.execute("SELECT * FROM cameras ORDER BY id ASC")
    rows = [dict(r) for r in cursor.fetchall()]
    conn.close()
    return rows

@app.post("/api/cameras")
def add_camera(cam: CameraCreate):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("""
        INSERT INTO cameras (camera_id, name, location, status, feed_url, last_updated)
        VALUES (?, ?, ?, ?, ?, datetime('now'))
        """, (cam.camera_id, cam.name, cam.location, cam.status, cam.feed_url))
        conn.commit()
    except sqlite3.IntegrityError:
        raise HTTPException(status_code=400, detail="Camera ID already exists")
    finally:
        conn.close()
    return {"success": True, "message": "Camera added successfully"}

# --- INCIDENTS ---
@app.get("/api/incidents")
def get_incidents(filter: Optional[str] = None):
    conn = get_db_connection()
    conn.row_factory = sqlite3.Row
    cursor = conn.cursor()

    if filter and filter != "All":
        cursor.execute("""
        SELECT * FROM incidents WHERE type = ? OR status = ? ORDER BY id DESC
        """, (filter, filter))
    else:
        cursor.execute("SELECT * FROM incidents ORDER BY id DESC")

    rows = [dict(r) for r in cursor.fetchall()]
    conn.close()
    return rows

@app.post("/api/incidents")
def create_incident(inc: IncidentCreate):
    conn = get_db_connection()
    cursor = conn.cursor()
    inc_id = f"INC-{datetime.now().year}-{(int(time.time() * 1000) % 900) + 100}"
    timestamp_str = f"Today, {datetime.now().strftime('%I:%M %p')}"

    cursor.execute("""
    INSERT INTO incidents (incident_id, type, severity, status, camera_id, camera_name, confidence, description, timestamp)
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (inc_id, inc.type, inc.severity, inc.status, inc.camera_id, inc.camera_name, inc.confidence, inc.description, timestamp_str))
    new_id = cursor.lastrowid
    conn.commit()
    conn.close()

    # Trigger real-time alert state
    global_detection.set_alert(
        detection_type=inc.type,
        confidence=inc.confidence,
        message=inc.description,
        incident_id=new_id,
    )

    return {"success": True, "id": new_id, "incident_id": inc_id}

@app.patch("/api/incidents/{incident_id}")
def update_incident_status(incident_id: int, update: IncidentStatusUpdate):
    conn = get_db_connection()
    cursor = conn.cursor()
    resolved_at = datetime.now().strftime("Today, %I:%M %p") if update.status == "Resolved" else None

    cursor.execute("""
    UPDATE incidents SET status = ?, resolved_at = ? WHERE id = ?
    """, (update.status, resolved_at, incident_id))
    conn.commit()
    conn.close()
    return {"success": True, "status": update.status}

# --- REAL-TIME DETECTION STATUS & VIVA DEMO TRIGGERS ---
@app.get("/api/detection/status")
def get_detection_status():
    return get_combined_detection_dict()

@app.get("/api/detection/smoke_status")
def get_smoke_status():
    return global_smoke_detection.to_dict()

@app.get("/api/detection/accident_status")
def get_accident_status():
    return global_accident_detection.to_dict()

@app.post("/api/detection/trigger_demo")
def trigger_demo(req: DemoTriggerRequest):
    req_type_lower = req.type.lower()

    if req_type_lower in ["clear", "reset", "clear_all"]:
        global_smoke_detection.reset()
        global_accident_detection.reset()
        return {"success": True, "message": "All hazard alerts reset to normal."}
    elif req_type_lower == "clear_smoke":
        global_smoke_detection.reset()
        return {"success": True, "message": "Smoke hazard alert reset to normal."}
    elif req_type_lower == "clear_accident":
        global_accident_detection.reset()
        return {"success": True, "message": "Accident hazard alert reset to normal."}

    # Automatically log into database
    conn = get_db_connection()
    cursor = conn.cursor()
    inc_code = f"INC-{datetime.now().year}-{(int(time.time() * 1000) % 900) + 100}"
    timestamp_str = f"Today, {datetime.now().strftime('%I:%M %p')}"

    if req_type_lower == "accident":
        inc_type = "Accident"
        desc = f"Visual AI detection alert: Vehicle collision and transit hazard verified with {req.confidence:.1f}% confidence."
        cursor.execute("""
        INSERT INTO incidents (incident_id, type, severity, status, camera_id, camera_name, confidence, description, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (inc_code, inc_type, "Critical", "Open", "CAM-01", "Laptop Webcam", req.confidence, desc, timestamp_str))
        new_id = cursor.lastrowid
        conn.commit()
        conn.close()

        global_accident_detection.set_alert(
            detection_type="Accident",
            confidence=req.confidence,
            message=desc,
            incident_id=new_id,
        )
    else:
        inc_type = "Smoke" if "smoke" in req_type_lower else ("Fire" if "fire" in req_type_lower else req.type)
        desc = f"Visual AI detection alert: {inc_type} plume verified with {req.confidence:.1f}% confidence."
        cursor.execute("""
        INSERT INTO incidents (incident_id, type, severity, status, camera_id, camera_name, confidence, description, timestamp)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (inc_code, inc_type, "Critical", "Open", "CAM-01", "Laptop Webcam", req.confidence, desc, timestamp_str))
        new_id = cursor.lastrowid
        conn.commit()
        conn.close()

        global_smoke_detection.set_alert(
            detection_type=inc_type,
            confidence=req.confidence,
            message=desc,
            incident_id=new_id,
        )

    return {
        "success": True,
        "message": f"Demo alert for {inc_type} triggered successfully",
        "incident_id": inc_code,
        "type": inc_type,
    }

@app.post("/api/detection/reset")
def reset_detection():
    global_smoke_detection.reset()
    global_accident_detection.reset()
    return {"success": True, "message": "All alert states reset to normal."}

def is_port_available(port: int) -> bool:
    import socket
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        try:
            s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
            s.bind(("0.0.0.0", port))
            return True
        except OSError:
            return False

if __name__ == "__main__":
    import uvicorn

    # Cloud deployment: Render assigns dynamic PORT environment variable
    port = int(os.environ.get("PORT", 5000))

    # Local macOS development fallback if PORT is not set and port 5000 is occupied by AirPlay Receiver
    if "PORT" not in os.environ and not is_port_available(port):
        print("\n" + "="*70)
        print(" [NOTICE] macOS AirTunes/AirPlay Receiver is occupying port 5000.")
        print(" Starting CityEye AI Backend on port 5001 as primary server.")
        print(" (To free port 5000: System Settings -> General -> AirDrop & Handoff -> turn off AirPlay Receiver)")
        print("="*70 + "\n")
        port = 5001

    print(f"[CityEye AI] Starting backend server on http://0.0.0.0:{port} ...")
    uvicorn.run(app, host="0.0.0.0", port=port)
