import csv
import os
from django.core.management.base import BaseCommand
from django.core.files import File
from django.conf import settings
from users.models import Staff


class Command(BaseCommand):
    help = 'Import staff records from CSV including ID card images'

    def add_arguments(self, parser):
        parser.add_argument('csv_file', type=str, help='Path to CSV file')

    def handle(self, *args, **kwargs):
        csv_file = kwargs['csv_file']
        image_base_path = os.path.join(settings.MEDIA_ROOT, 'import_id_cards')

        created = 0
        skipped = 0

        with open(csv_file, newline='', encoding='utf-8') as file:
            reader = csv.DictReader(file)

            for row in reader:
                phone = row.get('phone_number')

                if not phone:
                    skipped += 1
                    continue

                staff, is_created = Staff.objects.get_or_create(
                    phone_number=phone,
                    defaults={
                        'full_name': row.get('full_name', ''),
                        'staff_id_number': row.get('staff_id_number', ''),
                        'is_active': True,
                    }
                )

                image_name = row.get('id_card_image')
                if image_name:
                    image_path = os.path.join(image_base_path, image_name)
                    if os.path.exists(image_path):
                        with open(image_path, 'rb') as img:
                            staff.id_card_image.save(image_name, File(img), save=True)

                if is_created:
                    created += 1
                else:
                    skipped += 1

        self.stdout.write(
            self.style.SUCCESS(
                f'Import completed: {created} created, {skipped} skipped'
            )
        )
