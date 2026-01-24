from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status

from .models import Staff, LoginAudit
from .serializers import StaffSerializer
from .utils import normalize_phone


@api_view(['POST'])
def verify_staff(request):
    phone_number = request.data.get('phone_number')

    if not phone_number:
        return Response(
            {
                'success': False,
                'message': 'Phone number is required'
            },
            status=status.HTTP_400_BAD_REQUEST
        )

    # Get all active staff
    staff_qs = Staff.objects.filter(is_active=True)

    matched_staff = []

    # Match phone number against possibly multiple stored numbers
    for staff in staff_qs:
        stored_numbers = normalize_phone(staff.phone_number)
        if phone_number in stored_numbers:
            matched_staff.append(staff)

    # 🚫 No record found
    if len(matched_staff) == 0:
        LoginAudit.objects.create(
            phone_number=phone_number,
            success=False,
            reason="not_found"
        )
        return Response(
            {
                'success': False,
                'message': 'Staff not authorized'
            },
            status=status.HTTP_404_NOT_FOUND
        )

    # ⚠️ Duplicate phone number
    if len(matched_staff) > 1:
        LoginAudit.objects.create(
            phone_number=phone_number,
            success=False,
            reason="duplicate_phone_number"
        )
        return Response(
            {
                'success': False,
                'data': None,
                'message': 'Multiple records found for this phone number'
            },
            status=status.HTTP_200_OK
        )

    # ✅ Exactly one valid staff
    staff = matched_staff[0]
    serializer = StaffSerializer(staff)

    LoginAudit.objects.create(
        phone_number=phone_number,
        success=True,
        reason="success"
    )

    return Response(
        {
            'success': True,
            'data': serializer.data
        },
        status=status.HTTP_200_OK
    )
