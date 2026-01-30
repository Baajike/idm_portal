from django.contrib import admin
from .models import Staff, LoginAudit


@admin.register(Staff)
class StaffAdmin(admin.ModelAdmin):
    list_display = ("name", "functional_area", "contact", "staff_id")
    search_fields = ("name", "contact", "staff_id")


@admin.register(LoginAudit)
class LoginAuditAdmin(admin.ModelAdmin):
    list_display = ("phone_number", "success", "reason", "created_at")