#!/bin/zsh
# CityEye AI Backend Launch Script
cd "$(dirname "$0")/ai_backend"
echo "=========================================================="
echo " Starting CityEye AI Backend (FastAPI + OpenCV + SQLite) "
echo "=========================================================="
./venv/bin/python main.py
