from django.views.generic import TemplateView
from django.shortcuts import get_object_or_404
from .models import Products, TechOp, Bom, InputResource
from collections import defaultdict
from decimal import Decimal


class IndexView(TemplateView):
    template_name = 'pages/index.html'


class ProductListView(TemplateView):
    template_name = 'pages/product_list.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        context['products'] = Products.objects.all().order_by('code')
        return context


class RouteMapView(TemplateView):
    template_name = 'pages/route_map.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        product_id = self.kwargs['product_id']
        product = get_object_or_404(Products, id=product_id)

        # Получаем маршрутную карту: операции для изделия
        operations = (
            TechOp.objects
            .filter(product=product)
            .select_related(
                'op_class',
                'gwc',
                'gwc__entity',
                'qualification'
            )
            .order_by('pos')
            .values(
                'pos',
                'id',
                'op_class__display_name',
                'gwc__display_name',
                'gwc__entity__display_name',
                'work_time',
                'qualification__display_name',
            )
        )

        # Форматируем данные
        operations_list = []
        for op in operations:
            operations_list.append({
                'pos': op['pos'],
                'op_id': op['id'],
                'op_class_name': op['op_class__display_name'],
                'gwc_name': op['gwc__display_name'],
                'entity_name': op['gwc__entity__display_name'],
                'work_time': float(op['work_time']),
                'qualification': op['qualification__display_name'] or None
            })

        context.update({
            'product': product,
            'operations': operations_list
        })
        return context


class MaterialCostsView(TemplateView):
    template_name = 'pages/material_costs.html'

    def get_context_data(self, **kwargs):
        context = super().get_context_data(**kwargs)
        product_id = self.kwargs['product_id']
        product = get_object_or_404(Products, id=product_id)

        # Словарь для суммирования расходов
        costs = defaultdict(lambda: {
            'product_id': None,
            'product_code': '',
            'product_name': '',
            'total_quantity': Decimal('0.0'),
            'unit': ''
        })

        def process_bom(parent_id, multiplier=Decimal('1.0')):
            """Рекурсивно обходит BOM и накапливает расход."""
            bom_items = Bom.objects.filter(parent_id=parent_id).select_related('child', 'child__measure')
            for item in bom_items:
                # Теперь: Decimal * Decimal
                qty = item.quantity * multiplier
                key = item.child.id
                if costs[key]['product_id'] is None:
                    costs[key].update({
                        'product_id': item.child.id,
                        'product_code': item.child.code,
                        'product_name': item.child.name,
                        'unit': item.child.measure.name_short if item.child.measure else 'шт'
                    })
                costs[key]['total_quantity'] += qty
                # Рекурсивно обрабатываем вложенные компоненты
                process_bom(item.child.id, qty)

        # Шаг 1: Обработка BOM
        process_bom(product_id)

        # Шаг 2: Обработка входных ресурсов
        input_resources = (
            InputResource.objects
            .filter(out_to__product=product)
            .select_related('product', 'product__measure')
            .values(
                'product_id',
                'product__code',
                'product__name',
                'in_quantity',
                'product__measure__name_short'
            )
        )

        for res in input_resources:
            key = res['product_id']
            unit = res['product__measure__name_short'] or 'шт'
            qty = res['in_quantity']  # Это Decimal
            if costs[key]['product_id'] is None:
                costs[key].update({
                    'product_id': key,
                    'product_code': res['product__code'],
                    'product_name': res['product__name'],
                    'unit': unit,
                    'total_quantity': Decimal('0.0')
                })
            costs[key]['total_quantity'] += qty

        # Конвертируем Decimal → float для шаблона (JSON-совместимость)
        costs_list = []
        for item in costs.values():
            item_copy = dict(item)
            if isinstance(item_copy['total_quantity'], Decimal):
                item_copy['total_quantity'] = float(item_copy['total_quantity'])
            costs_list.append(item_copy)

        context.update({
            'product': product,
            'costs': sorted(costs_list, key=lambda x: x['product_code'])
        })
        return context
