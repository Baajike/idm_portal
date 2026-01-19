from rest_framework.decorators import api_view
from rest_framework.response import Response
from rest_framework import status
from .models import Staff
from .serializers import StaffSerializer


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

    try:
        staff = Staff.objects.get(phone_number=phone_number, is_active=True)
        serializer = StaffSerializer(staff)
        return Response(
            {
                'success': True,
                'data': serializer.data
            },
            status=status.HTTP_200_OK
        )

    except Staff.DoesNotExist:
        return Response(
            {
                'success': False,
                'message': 'Staff not authorized'
            },
            status=status.HTTP_404_NOT_FOUND
        )

