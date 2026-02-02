from django.contrib import admin
from simple_history.admin import SimpleHistoryAdmin
from .models import Staff, AuditLog, SystemLog, LoginAudit


@admin.register(Staff)
class StaffAdmin(SimpleHistoryAdmin):
    list_display = ['name', 'contact', 'staff_id', 'functional_area', 'is_active', 'registered_device_id']
    list_filter = ['is_active', 'functional_area', 'created_at']
    search_fields = ['name', 'contact', 'staff_id']
    readonly_fields = ['created_at', 'updated_at', 'device_registered_at']
    
    fieldsets = (
        ('Basic Information', {
            'fields': ('name', 'staff_id', 'functional_area', 'contact', 'photo', 'is_active')
        }),
        ('Device Security', {
            'fields': ('registered_device_id', 'device_model', 'device_registered_at'),
            'classes': ('collapse',)
        }),
        ('Timestamps', {
            'fields': ('created_at', 'updated_at'),
            'classes': ('collapse',)
        }),
    )


@admin.register(AuditLog)
class AuditLogAdmin(admin.ModelAdmin):
    list_display = ['timestamp', 'action', 'user_contact', 'success', 'ip_address', 'device_id']
    list_filter = ['action', 'success', 'timestamp']
    search_fields = ['user_contact', 'device_id', 'ip_address']
    readonly_fields = ['timestamp']
    date_hierarchy = 'timestamp'
    
    def has_add_permission(self, request):
        return False  # Audit logs are created automatically
    
    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser  # Only superusers can delete logs


@admin.register(SystemLog)
class SystemLogAdmin(admin.ModelAdmin):
    list_display = ['timestamp', 'level', 'module', 'message']
    list_filter = ['level', 'module', 'timestamp']
    search_fields = ['message', 'module']
    readonly_fields = ['timestamp']
    date_hierarchy = 'timestamp'
    
    def has_add_permission(self, request):
        return False
    
    def has_delete_permission(self, request, obj=None):
        return request.user.is_superuser


@admin.register(LoginAudit)
class LoginAuditAdmin(admin.ModelAdmin):
    list_display = ['phone_number', 'success', 'reason', 'created_at']
    list_filter = ['success', 'created_at']
    search_fields = ['phone_number']
    readonly_fields = ['created_at']