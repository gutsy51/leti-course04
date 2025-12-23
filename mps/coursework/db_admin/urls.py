from django.urls import path
from . import views

app_name = 'db_admin'

urlpatterns = [
    path('', views.IndexView.as_view(), name='index'),
    path('products/', views.ProductListView.as_view(), name='product_list'),
    path('product/<int:product_id>/route/', views.RouteMapView.as_view(), name='route_map'),
    path('product/<int:product_id>/costs/', views.MaterialCostsView.as_view(), name='material_costs'),
]
