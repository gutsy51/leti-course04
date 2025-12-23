from django.contrib import admin
from django.apps import apps

app = apps.get_app_config('db_admin')

for model in app.get_models():
    try:
        admin.site.register(model)
    except Exception as e:
        print(e)
        pass
