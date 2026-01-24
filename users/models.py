from django.db import models


class Staff(models.Model):
    full_name = models.CharField(max_length=150)
    phone_number = models.CharField(max_length=25)
    staff_id_number = models.CharField(max_length=50, unique=True)
    id_card_image = models.ImageField(upload_to='id_cards/')
    is_active = models.BooleanField(default=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.full_name

class LoginAudit(models.Model):
    phone_number = models.CharField(max_length=15)
    success = models.BooleanField(default=False)
    reason = models.CharField(max_length=100, null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return f"{self.phone_number} - {self.success}"
