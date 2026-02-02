from django.db import models
from django.core.validators import RegexValidator
from django.core.exceptions import ValidationError
from django.utils import timezone
from simple_history.models import HistoricalRecords


def validate_photo_size(image):
    """Ensure photo is under 5MB"""
    max_size = 5 * 1024 * 1024  # 5MB
    if image.size > max_size:
        raise ValidationError('Photo must be under 5MB')


class Staff(models.Model):
    """
    Staff model - ORIGINAL STRUCTURE PRESERVED
    """
    name = models.CharField(max_length=255)

    functional_area = models.CharField(
        max_length=255,
        blank=True,
        null=True
    )

    staff_id = models.CharField(
        max_length=50,
        blank=True,
        null=True
        # NOTE: NOT unique - multiple people can have same staff_id or blank
    )

    contact = models.CharField(
        max_length=50,
        unique=True,  # ONLY contact is unique
        blank=False,  # Contact is required
        null=False,
    )

    photo = models.ImageField(
        upload_to='staff_photos/',
        blank=True,
        null=True,
        validators=[validate_photo_size],
    )

    # NEW SECURITY FIELDS (won't affect existing data)
    registered_device_id = models.CharField(
        max_length=100,
        null=True,
        blank=True,
        help_text='Device ID registered to this staff member'
    )
    
    device_registered_at = models.DateTimeField(
        null=True,
        blank=True,
        help_text='When the device was registered'
    )
    
    device_model = models.CharField(
        max_length=100,
        null=True,
        blank=True,
        help_text='Device model'
    )

    is_active = models.BooleanField(
        default=True,
        help_text='Is this account active?'
    )

    created_at = models.DateTimeField(auto_now_add=True, null=True, blank=True)
    updated_at = models.DateTimeField(auto_now=True, null=True, blank=True)

    # VERSION CONTROL
    history = HistoricalRecords()

    class Meta:
        ordering = ['name']
        # NO verbose_name - Django will use "Staff" automatically

    def __str__(self):
        return f"{self.name} ({self.contact})"

    def register_device(self, device_id, device_model=None):
        """Register a device for this staff member"""
        self.registered_device_id = device_id
        self.device_registered_at = timezone.now()
        self.device_model = device_model
        self.save()

    def is_device_authorized(self, device_id):
        """Check if a device is authorized"""
        if not self.registered_device_id:
            return True  # No device registered yet
        return self.registered_device_id == device_id


class AuditLog(models.Model):
    """Audit logging for all activities"""
    ACTION_CHOICES = [
        ('LOGIN', 'Login Attempt'),
        ('LOGIN_SUCCESS', 'Successful Login'),
        ('LOGIN_FAILED', 'Failed Login'),
        ('SCAN', 'QR Scan'),
        ('LOGOUT', 'Logout'),
        ('DEVICE_REGISTER', 'Device Registration'),
        ('DEVICE_CHANGE_ATTEMPT', 'Unauthorized Device Attempt'),
        ('PHOTO_UPDATE', 'Photo Updated'),
        ('DATA_UPDATE', 'Staff Data Updated'),
    ]

    user_contact = models.CharField(max_length=15, db_index=True)
    staff = models.ForeignKey(Staff, on_delete=models.SET_NULL, null=True, blank=True, related_name='audit_logs')
    action = models.CharField(max_length=50, choices=ACTION_CHOICES, db_index=True)
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)
    device_id = models.CharField(max_length=100, null=True, blank=True)
    device_model = models.CharField(max_length=100, null=True, blank=True)
    ip_address = models.GenericIPAddressField(null=True, blank=True)
    success = models.BooleanField(default=True, db_index=True)
    failure_reason = models.TextField(null=True, blank=True)
    metadata = models.JSONField(null=True, blank=True)

    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        status = "✓" if self.success else "✗"
        return f"{status} {self.get_action_display()} - {self.user_contact}"


class SystemLog(models.Model):
    """System-level logs"""
    LEVEL_CHOICES = [
        ('DEBUG', 'Debug'),
        ('INFO', 'Information'),
        ('WARNING', 'Warning'),
        ('ERROR', 'Error'),
        ('CRITICAL', 'Critical'),
    ]

    level = models.CharField(max_length=20, choices=LEVEL_CHOICES, db_index=True)
    message = models.TextField()
    module = models.CharField(max_length=100, db_index=True)
    timestamp = models.DateTimeField(auto_now_add=True, db_index=True)
    exception_trace = models.TextField(null=True, blank=True)

    class Meta:
        ordering = ['-timestamp']

    def __str__(self):
        return f"[{self.level}] {self.module}"


# Keep old LoginAudit for backward compatibility
class LoginAudit(models.Model):
    phone_number = models.CharField(max_length=15)
    success = models.BooleanField(default=False)
    reason = models.CharField(max_length=100, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.phone_number} - {self.success}"