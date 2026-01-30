from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
import json
from datetime import datetime

# Temporary in-memory storage (we'll replace with DB later)
STAFF_DB = {
    # example:
    # "0241234567": {
    #     "phone_number": "0241234567",
    #     "photo": "staff_0241234567.jpg"
    # }
}

SCAN_DB = []


@csrf_exempt
def verify_phone(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=405)

    try:
        data = json.loads(request.body)
        phone_number = data.get("phone_number")

        if not phone_number:
            return JsonResponse({"error": "Phone number is required"}, status=400)

        staff = STAFF_DB.get(phone_number)

        if not staff:
            return JsonResponse({
                "verified": False,
                "message": "Phone number not found"
            }, status=404)

        return JsonResponse({
            "verified": True,
            "phone_number": staff["phone_number"],
            "photo": staff.get("photo")
        })

    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)


@csrf_exempt
def verify_scan(request):
    if request.method != "POST":
        return JsonResponse({"error": "POST request required"}, status=405)

    try:
        data = json.loads(request.body)
        phone_number = data.get("phone_number")

        if not phone_number:
            return JsonResponse({"error": "Phone number required"}, status=400)

        scan = {
            "phone_number": phone_number,
            "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        }

        SCAN_DB.append(scan)

        return JsonResponse({
            "success": True,
            "scan": scan
        })

    except Exception as e:
        return JsonResponse({"error": str(e)}, status=500)


def recent_entry(request):
    phone_number = request.GET.get("phone_number")

    if not phone_number:
        return JsonResponse({"recent_entry": None})

    for scan in reversed(SCAN_DB):
        if scan["phone_number"] == phone_number:
            return JsonResponse({"recent_entry": scan})

    return JsonResponse({"recent_entry": None})
