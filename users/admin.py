from django.contrib import admin
from .models import Staff


@admin.register(Staff)
class StaffAdmin(admin.ModelAdmin):
    list_display = ('full_name', 'phone_number', 'staff_id_number', 'is_active')
    search_fields = ('full_name', 'phone_number', 'staff_id_number')
    list_filter = ('is_active',)
