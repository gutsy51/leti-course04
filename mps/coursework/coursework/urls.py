from django.contrib import admin
from django.urls import path, include

urlpatterns = [
    path('admin/', admin.site.urls),
    path('', include('db_admin.urls')),
    path('auth/', include('django.contrib.auth.urls')),
]
