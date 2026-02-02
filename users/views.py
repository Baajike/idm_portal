from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
import json
import re
import traceback
from datetime import datetime
from .models import Staff, AuditLog, SystemLog


def get_client_ip(request):
    """Extract client IP address from request"""
    x_forwarded_for = request.META.get('HTTP_X_FORWARDED_FOR')
    if x_forwarded_for:
        ip = x_forwarded_for.split(',')[0].strip()
    else:
        ip = request.META.get('REMOTE_ADDR')
    return ip


def validate_contact_format(contact):
    """
    Data quality check: Validate phone number format
    Returns: (is_valid, error_message)
    """
    if not contact:
        return False, "Contact is required"
    
    if not isinstance(contact, str):
        return False, "Contact must be a string"
    
    # Must be exactly 10 digits starting with 0
    if not re.match(r'^0\d{9}$', contact):
        return False, "Phone number must be 10 digits starting with 0 (e.g., 0547788117)"
    
    return True, None


def validate_device_id(device_id):
    """
    Data quality check: Validate device ID
    Returns: (is_valid, error_message)
    """
    if not device_id:
        return False, "Device ID is required for security"
    
    if not isinstance(device_id, str):
        return False, "Device ID must be a string"
    
    if len(device_id) < 10:
        return False, "Invalid device ID format"
    
    return True, None


def log_system_error(module, message, exception=None):
    """Helper function to log system errors"""
    try:
        SystemLog.objects.create(
            level='ERROR',
            module=module,
            message=message,
            exception_trace=traceback.format_exc() if exception else None
        )
    except Exception as e:
        # If logging fails, at least print to console
        print(f"Failed to log error: {e}")


@csrf_exempt
def verify_phone(request):
    """
    Verify phone number and device, with comprehensive security and logging
    """
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=405)

    # Get IP address
    ip_address = get_client_ip(request)
    
    try:
        data = json.loads(request.body)
        contact = data.get("contact")
        device_id = data.get("device_id")
        device_model = data.get("device_model")  # Optional: e.g., "Samsung Galaxy S21"

        # ============================================
        # STEP 1: DATA QUALITY CHECKS
        # ============================================
        errors = []

        # Validate contact format
        is_valid, error_msg = validate_contact_format(contact)
        if not is_valid:
            errors.append(error_msg)

        # Validate device ID
        is_valid, error_msg = validate_device_id(device_id)
        if not is_valid:
            errors.append(error_msg)

        if errors:
            # Log failed validation
            AuditLog.objects.create(
                user_contact=contact or 'unknown',
                action='LOGIN_FAILED',
                device_id=device_id,
                device_model=device_model,
                ip_address=ip_address,
                success=False,
                failure_reason=f"Validation errors: {', '.join(errors)}",
                metadata={'errors': errors}
            )
            return JsonResponse({"errors": errors}, status=400)

        # ============================================
        # STEP 2: CHECK IF STAFF EXISTS
        # ============================================
        try:
            staff = Staff.objects.get(contact=contact)
        except Staff.DoesNotExist:
            # Log failed login attempt - user not found
            AuditLog.objects.create(
                user_contact=contact,
                action='LOGIN_FAILED',
                device_id=device_id,
                device_model=device_model,
                ip_address=ip_address,
                success=False,
                failure_reason='Contact not found in database',
                metadata={
                    'attempted_contact': contact,
                    'device_id': device_id
                }
            )
            
            SystemLog.objects.create(
                level='WARNING',
                module='Authentication',
                message=f'Login attempt with non-existent contact: {contact}'
            )
            
            return JsonResponse({
                "verified": False,
                "message": "Contact not found in system. Please contact administrator."
            }, status=404)

        # ============================================
        # STEP 3: CHECK IF ACCOUNT IS ACTIVE
        # ============================================
        if not staff.is_active:
            # Log attempt to access inactive account
            AuditLog.objects.create(
                user_contact=contact,
                staff=staff,
                action='LOGIN_FAILED',
                device_id=device_id,
                device_model=device_model,
                ip_address=ip_address,
                success=False,
                failure_reason='Account is inactive',
                metadata={
                    'staff_id': staff.staff_id,
                    'name': staff.name
                }
            )
            
            return JsonResponse({
                "verified": False,
                "message": "Your account is inactive. Please contact administrator."
            }, status=403)

        # ============================================
        # STEP 4: DEVICE SECURITY CHECK (IMEI)
        # ============================================
        
        # Check if this is first-time device registration
        if not staff.registered_device_id:
            # First login - register this device
            staff.register_device(device_id, device_model)
            
            # Log device registration
            AuditLog.objects.create(
                user_contact=contact,
                staff=staff,
                action='DEVICE_REGISTER',
                device_id=device_id,
                device_model=device_model,
                ip_address=ip_address,
                success=True,
                metadata={
                    'staff_id': staff.staff_id,
                    'name': staff.name,
                    'first_registration': True
                }
            )
            
            SystemLog.objects.create(
                level='INFO',
                module='Device Management',
                message=f'Device registered for {staff.name} ({contact}): {device_id}'
            )
        
        elif not staff.is_device_authorized(device_id):
            # SECURITY ALERT: Different device trying to access account
            AuditLog.objects.create(
                user_contact=contact,
                staff=staff,
                action='DEVICE_CHANGE_ATTEMPT',
                device_id=device_id,
                device_model=device_model,
                ip_address=ip_address,
                success=False,
                failure_reason='Unauthorized device - device ID mismatch',
                metadata={
                    'registered_device': staff.registered_device_id,
                    'attempted_device': device_id,
                    'staff_id': staff.staff_id,
                    'name': staff.name,
                    'registered_at': staff.device_registered_at.isoformat() if staff.device_registered_at else None
                }
            )
            
            SystemLog.objects.create(
                level='WARNING',
                module='Security',
                message=f'SECURITY ALERT: Unauthorized device attempt for {staff.name} ({contact}). IP: {ip_address}'
            )
            
            return JsonResponse({
                "verified": False,
                "message": "Unauthorized device. This account is registered to another device. Please contact administrator to change devices.",
                "security_alert": True
            }, status=403)

        # ============================================
        # STEP 5: SUCCESS - LOG AND RETURN DATA
        # ============================================
        
        # Log successful login
        AuditLog.objects.create(
            user_contact=contact,
            staff=staff,
            action='LOGIN_SUCCESS',
            device_id=device_id,
            device_model=device_model,
            ip_address=ip_address,
            success=True,
            metadata={
                'staff_id': staff.staff_id,
                'name': staff.name,
                'functional_area': staff.functional_area
            }
        )
        
        # Return staff data
        return JsonResponse({
            "verified": True,
            "name": staff.name,
            "staff_id": staff.staff_id,
            "functional_area": staff.functional_area,
            "contact": staff.contact,
            "photo": staff.photo.url if staff.photo else None,
            "device_registered": staff.registered_device_id is not None,
        })

    except json.JSONDecodeError:
        # Log invalid JSON
        SystemLog.objects.create(
            level='ERROR',
            module='API',
            message=f'Invalid JSON received from IP: {ip_address}'
        )
        return JsonResponse({"error": "Invalid JSON format"}, status=400)
    
    except Exception as e:
        # Log unexpected errors
        error_message = str(e)
        log_system_error('verify_phone', f'Unexpected error: {error_message}', e)
        
        return JsonResponse({
            "error": "An unexpected error occurred. Please try again.",
            "details": error_message if SystemLog.objects.filter(level='DEBUG').exists() else None
        }, status=500)


@csrf_exempt
def verify_scan(request):
    """
    Log QR code scans with device and location tracking
    """
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=405)

    ip_address = get_client_ip(request)
    
    try:
        data = json.loads(request.body)
        contact = data.get("contact")
        device_id = data.get("device_id")
        device_model = data.get("device_model")
        location = data.get("location", "Main Entrance")  # Optional: gate location

        # Validate inputs
        if not contact:
            return JsonResponse({"error": "Contact required"}, status=400)

        # Try to get staff (optional - scan might happen without full verification)
        staff = None
        try:
            staff = Staff.objects.get(contact=contact)
        except Staff.DoesNotExist:
            pass

        # Log the scan
        AuditLog.objects.create(
            user_contact=contact,
            staff=staff,
            action='SCAN',
            device_id=device_id,
            device_model=device_model,
            ip_address=ip_address,
            success=True,
            metadata={
                'location': location,
                'staff_id': staff.staff_id if staff else None,
                'name': staff.name if staff else None
            }
        )

        return JsonResponse({
            "success": True,
            "contact": contact,
            "timestamp": timezone.now().strftime("%Y-%m-%d %H:%M:%S"),
            "location": location
        })

    except Exception as e:
        log_system_error('verify_scan', f'Error logging scan: {str(e)}', e)
        return JsonResponse({"error": str(e)}, status=500)


def recent_entry(request):
    """
    Get recent entry logs for a contact
    """
    contact = request.GET.get("contact")

    if not contact:
        return JsonResponse({"recent_entry": None})

    try:
        # Get most recent scan from new AuditLog
        recent = AuditLog.objects.filter(
            user_contact=contact,
            action='SCAN',
            success=True
        ).order_by('-timestamp').first()
        
        if recent:
            return JsonResponse({
                "recent_entry": {
                    "contact": recent.user_contact,
                    "timestamp": recent.timestamp.strftime("%Y-%m-%d %H:%M:%S"),
                    "location": recent.metadata.get('location', 'Main Entrance') if recent.metadata else 'Main Entrance',
                    "success": recent.success
                }
            })
        else:
            return JsonResponse({"recent_entry": None})
            
    except Exception as e:
        log_system_error('recent_entry', f'Error fetching recent entry: {str(e)}', e)
        return JsonResponse({"error": str(e)}, status=500)


def audit_report(request):
    """
    Get audit logs for admin panel (optional endpoint)
    Requires admin authentication in production
    """
    try:
        # Get query parameters
        contact = request.GET.get('contact')
        action = request.GET.get('action')
        limit = int(request.GET.get('limit', 50))
        
        # Build query
        logs = AuditLog.objects.all()
        
        if contact:
            logs = logs.filter(user_contact=contact)
        if action:
            logs = logs.filter(action=action)
        
        logs = logs[:limit]
        
        # Format response
        log_data = [{
            'id': log.id,
            'contact': log.user_contact,
            'action': log.get_action_display(),
            'success': log.success,
            'timestamp': log.timestamp.isoformat(),
            'ip_address': log.ip_address,
            'device_id': log.device_id,
            'failure_reason': log.failure_reason,
        } for log in logs]
        
        return JsonResponse({
            'count': len(log_data),
            'logs': log_data
        })
    
    except Exception as e:
        log_system_error('audit_report', f'Error generating report: {str(e)}', e)
        return JsonResponse({"error": str(e)}, status=500)