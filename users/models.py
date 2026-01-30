from django.db import models


class Staff(models.Model):
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
    )

    contact = models.CharField(
        max_length=50,
        unique=True,      # 👈 IMPORTANT
        blank=True,
        null=True
    )

    photo = models.ImageField(
        upload_to='staff_photos/',
        blank=True,
        null=True
    )

    def __str__(self):
        return f"{self.name} ({self.contact})"


class LoginAudit(models.Model):
    phone_number = models.CharField(max_length=15)
    success = models.BooleanField(default=False)
    reason = models.CharField(max_length=100, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.phone_number} - {self.success}"
