from django.urls import path
from .views import verify_phone, verify_scan, recent_entry

urlpatterns = [
    path('verify/', verify_phone),
    path('scan/', verify_scan),
    path('recent/', recent_entry),
]
