from django.urls import path
from . import views

app_name = 'django_db_app'

urlpatterns = [
    path('', views.IndexView.as_view(), name='index'),
    # path('classifier/',
    #      views.ClassifierView.as_view(),
    #      name='classifier'),
    # path('descendants_by_category/',
    #      views.DescendantsByCategoryView.as_view(),
    #      name='descendants_by_category'),
    # path('parents_by_category/',
    #      views.ParentsByCategoryView.as_view(),
    #      name='parents_by_category'),
    # path('terminal_categories/',
    #      views.TerminalCategoriesView.as_view(),
    #      name='terminal_categories'),
    # path('products_with_params/',
    #      views.ProductsWithParamsView.as_view(),
    #      name='products_with_params'),
    # path('all_products_with_params/',
    #      views.AllProductsWithParamsView.as_view(),
    #      name='all_products_with_params'),
    # path('product_params/',
    #      views.ProductParamsView.as_view(),
    #      name='product_params'),
    # path('products_with_aggregate_params/',
    #      views.ProductsWithAggregateParamsView.as_view(),
    #      name='products_with_aggregate_params'),
]
