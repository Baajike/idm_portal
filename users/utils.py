import re

def normalize_phone(phone):
    """
    Extract all valid phone numbers from a string
    Example: '0541559753/0547788117'
    """
    if not phone:
        return []

    return re.findall(r'\d{10}', phone)
