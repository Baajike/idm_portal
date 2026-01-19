from django.urls import path
from .views import verify_staff

urlpatterns = [
    path('verify/', verify_staff, name='verify_staff'),
]
