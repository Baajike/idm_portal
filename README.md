# IDM Portal Backend

This project is a Django-based backend system for validating staff identities using a unique staff number.  

The system exposes a secure API endpoint that receives a staff number, verifies it against the database, and returns staff information if valid, or an error response if invalid.

It is designed to support:
- QR code–based access
- API-based staff verification
- Future bulk staff data imports via CSV

---

##  Features
- Staff verification API
- Admin dashboard for staff management
- CSV import support for bulk data
- Scalable and secure backend structure

---

## Tech Stack
- Python
- Django
- Django REST Framework
- SQLite (development)

---

##  Setup Instructions

1. Clone the repository
```bash
git clone https://github.com/Baajike/idm_portal.git
cd idm_portal
```

2. Create and activate virtual environment
```bash
python -m venv venv
source venv/Scripts/activate
```

3. Install dependencies
```bash
pip install -r requirements.txt
```

4. Run migration
```bash
python manage.py migrate
```

5. Start the server
```bash
python manage.py runserver
```

## Admin access
Create a superuser to access the admin dashboard:
```bash
python manage.py createsuperuser
```

Admin panel:
```
http://127.0.0.1:8000/admin/
```
