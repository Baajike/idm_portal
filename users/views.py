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
    """Validate phone number format"""
    if not contact:
        return False, "Contact is required"
    
    if not isinstance(contact, str):
        return False, "Contact must be a string"
    
    if not re.match(r'^0\d{9}$', contact):
        return False, "Phone number must be 10 digits starting with 0 (e.g., 0547788117)"
    
    return True, None


def validate_device_id(device_id):
    """Validate device ID"""
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
        print(f"Failed to log error: {e}")


@csrf_exempt
def verify_phone(request):
    """
    Verify phone number and device with detailed error messages
    """
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=405)

    ip_address = get_client_ip(request)
    contact = None
    device_id = None
    
    try:
        # ============================================
        # STEP 1: PARSE REQUEST BODY
        # ============================================
        try:
            data = json.loads(request.body)
        except json.JSONDecodeError as e:
            SystemLog.objects.create(
                level='ERROR',
                module='API',
                message=f'Invalid JSON from IP: {ip_address}'
            )
            return JsonResponse({
                "verified": False,
                "message": "Invalid request format. Please check your connection and try again."
            }, status=400)

        contact = data.get("contact")
        device_id = data.get("device_id")
        device_model = data.get("device_model")

        # ============================================
        # STEP 2: VALIDATE PHONE NUMBER FORMAT
        # ============================================
        is_valid, error_msg = validate_contact_format(contact)
        if not is_valid:
            AuditLog.objects.create(
                user_contact=contact or 'unknown',
                action='LOGIN_FAILED',
                device_id=device_id,
                device_model=device_model,
                ip_address=ip_address,
                success=False,
                failure_reason=f"Invalid phone format: {error_msg}",
                metadata={'error': error_msg}
            )
            return JsonResponse({
                "verified": False,
                "message": f"Invalid phone number format. {error_msg}"
            }, status=400)

        # ============================================
        # STEP 3: VALIDATE DEVICE ID
        # ============================================
        is_valid, error_msg = validate_device_id(device_id)
        if not is_valid:
            AuditLog.objects.create(
                user_contact=contact,
                action='LOGIN_FAILED',
                device_id=device_id,
                device_model=device_model,
                ip_address=ip_address,
                success=False,
                failure_reason=f"Invalid device ID: {error_msg}",
                metadata={'error': error_msg}
            )
            return JsonResponse({
                "verified": False,
                "message": f"Device validation failed. {error_msg}"
            }, status=400)

        # ============================================
        # STEP 4: CHECK IF STAFF EXISTS
        # ============================================
        try:
            staff = Staff.objects.get(contact=contact)
        except Staff.DoesNotExist:
            # Log failed login - user not found
            AuditLog.objects.create(
                user_contact=contact,
                action='LOGIN_FAILED',
                device_id=device_id,
                device_model=device_model,
                ip_address=ip_address,
                success=False,
                failure_reason='Phone number not found in database',
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
                "message": f"Phone number {contact} not found in our system. Please contact your administrator."
            }, status=404)
        except Exception as e:
            # Unexpected database error
            log_system_error('Database', f'Error querying staff with contact {contact}: {str(e)}', e)
            return JsonResponse({
                "verified": False,
                "message": "Database error occurred. Please try again or contact support."
            }, status=500)

        # ============================================
        # STEP 5: CHECK IF ACCOUNT IS ACTIVE
        # ============================================
        if not staff.is_active:
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
                "message": f"Your account ({staff.name}) is currently inactive. Please contact your administrator to reactivate it."
            }, status=403)

        # ============================================
        # STEP 6: DEVICE SECURITY CHECK
        # ============================================
        
        # First login - register device
        if not staff.registered_device_id:
            try:
                staff.register_device(device_id, device_model)
                
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
            except Exception as e:
                log_system_error('Device Registration', f'Failed to register device for {contact}: {str(e)}', e)
                return JsonResponse({
                    "verified": False,
                    "message": "Failed to register device. Please try again."
                }, status=500)
        
        # Check if device matches
        elif not staff.is_device_authorized(device_id):
            # SECURITY ALERT: Different device
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
                "message": f"Security Alert: Your account ({staff.name}) is registered to another device. Please contact your administrator to change devices.",
                "security_alert": True
            }, status=403)

        # ============================================
        # STEP 7: SUCCESS - RETURN DATA
        # ============================================
        
        try:
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
                "staff_id": staff.staff_id or "N/A",
                "functional_area": staff.functional_area or "N/A",
                "contact": staff.contact,
                "photo": staff.photo.url if staff.photo else None,
                "device_registered": staff.registered_device_id is not None,
            })
        except Exception as e:
            log_system_error('Response Generation', f'Error generating response for {contact}: {str(e)}', e)
            return JsonResponse({
                "verified": False,
                "message": "Error generating response. Please try again."
            }, status=500)

    except Exception as e:
        # Catch-all for any unexpected errors
        error_message = str(e)
        log_system_error('verify_phone', f'Unexpected error for contact {contact}: {error_message}', e)
        
        # Try to log to AuditLog if we have contact
        if contact:
            try:
                AuditLog.objects.create(
                    user_contact=contact,
                    action='LOGIN_FAILED',
                    device_id=device_id,
                    device_model=device_model,
                    ip_address=ip_address,
                    success=False,
                    failure_reason=f'System error: {error_message}',
                    metadata={'exception': error_message}
                )
            except:
                pass
        
        return JsonResponse({
            "verified": False,
            "message": f"An unexpected error occurred: {error_message}. Please contact support if this persists."
        }, status=500)


@csrf_exempt
def verify_scan(request):
    """Log QR code scans"""
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=405)

    ip_address = get_client_ip(request)
    
    try:
        data = json.loads(request.body)
        contact = data.get("contact")
        device_id = data.get("device_id")
        device_model = data.get("device_model")
        location = data.get("location", "Main Entrance")

        if not contact:
            return JsonResponse({
                "success": False,
                "message": "Contact required"
            }, status=400)

        # Try to get staff
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
        return JsonResponse({
            "success": False,
            "message": f"Error logging scan: {str(e)}"
        }, status=500)


def recent_entry(request):
    """Get recent entry logs"""
    contact = request.GET.get("contact")

    if not contact:
        return JsonResponse({"recent_entry": None})

    try:
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
        return JsonResponse({
            "error": f"Error fetching data: {str(e)}"
        }, status=500)


def audit_report(request):
    """Get audit logs (admin only)"""
    try:
        contact = request.GET.get('contact')
        action = request.GET.get('action')
        limit = int(request.GET.get('limit', 50))
        
        logs = AuditLog.objects.all()
        
        if contact:
            logs = logs.filter(user_contact=contact)
        if action:
            logs = logs.filter(action=action)
        
        logs = logs[:limit]
        
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
        return JsonResponse({
            "error": f"Error generating report: {str(e)}"
        }, status=500)