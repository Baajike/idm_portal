from django.core.management.base import BaseCommand, CommandError
from users.models import Staff

class Command(BaseCommand):
    help = 'Clears the registered_device_id for a staff member by phone number'

    def add_arguments(self, parser):
        parser.add_argument('contact', type=str, help='Staff phone number')

    def handle(self, *args, **options):
        contact = options['contact']
        try:
            staff = Staff.objects.get(contact=contact)
            staff.registered_device_id = None
            staff.device_registered_at = None
            staff.device_model = None
            staff.save()
            self.stdout.write(self.style.SUCCESS(f'Successfully cleared device ID for {staff.name} ({contact})'))
        except Staff.DoesNotExist:
            raise CommandError(f'Staff member with contact {contact} does not exist')
