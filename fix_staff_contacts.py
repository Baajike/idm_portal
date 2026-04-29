from users.models import Staff
count = 0
for s in Staff.objects.all():
    if not s.contact.startswith('0'):
        s.contact = '0' + s.contact
        s.save()
        count += 1
print(f"Fixed {count} staff records.")
