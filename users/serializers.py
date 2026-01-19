from rest_framework import serializers
from .models import Staff


class StaffSerializer(serializers.ModelSerializer):
    class Meta:
        model = Staff
        fields = [
            'full_name',
            'phone_number',
            'staff_id_number',
            'id_card_image',
        ]
