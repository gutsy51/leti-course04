"""
Заполнение тестовыми данными всех таблиц системы.

Использование:
1. Перейдите в корень проекта (где manage.py)
2. Выполните:
   python manage.py shell
3. В интерактивной оболочке:
   from db_admin.utils.fill_test_data import fill_test_data
   fill_test_data()
"""

from django.db import transaction
from django.db.utils import IntegrityError

from ..models import (
    Measure, Class, Products, Enum, EnumValue,
    Parameter, ClassParameter, ProductParameter,
    BusinessEntity, Gwc, TechOp, InputResource,
    ConfigRule, RulePredicate, RuleCondition,
    Bom, Orders, OrderPos
)


@transaction.atomic
def fill_test_data():
    try:
        print('=== ЗАПОЛНЕНИЕ ТЕСТОВЫМИ ДАННЫМИ ===')

        print('1. Создание единиц измерения...')
        measure_data = [
            ('Штука', 'шт'),
            ('Метр', 'м'),
            ('Килограмм', 'кг'),
            ('Минута', 'мин'),
            ('Тонна', 'т'),
            ('Миллиметр', 'мм'),
        ]
        measures = {}
        for name, short in measure_data:
            m, created = Measure.objects.get_or_create(name=name, name_short=short)
            measures[name] = m
            if created:
                print(f'  + {name} ({short})')

        print('2. Создание классов...')
        c_material = Class.objects.create(name='Материал', display_name='Материалы', measure=measures['Штука'])
        c_pipe = Class.objects.create(name='Труба', display_name='Трубы', measure=measures['Метр'])
        c_fitting = Class.objects.create(name='Фитинг', display_name='Фитинги', measure=measures['Штука'])
        c_department = Class.objects.create(name='Цех', display_name='Подразделения', measure=measures['Штука'])
        c_gwc = Class.objects.create(name='ГРЦ', display_name='Групповые рабочие центры', measure=measures['Штука'])
        c_tool = Class.objects.create(name='Инструмент', display_name='Инструменты', measure=measures['Штука'])

        print('3. Создание параметров...')
        p_diameter = Parameter.objects.create(
            class_field=c_pipe,
            measure=measures['Миллиметр'],
            name='diameter',
            display_name='Диаметр'
        )
        p_length = Parameter.objects.create(
            class_field=c_pipe,
            measure=measures['Метр'],
            name='length',
            display_name='Длина'
        )

        print('4. Назначение параметров классам...')
        ClassParameter.objects.create(
            class_field=c_pipe,
            parameter=p_diameter,
            min_value=10,
            max_value=100,
            is_required=True
        )
        ClassParameter.objects.create(
            class_field=c_pipe,
            parameter=p_length,
            min_value=0.5,
            max_value=6.0,
            is_required=True
        )

        print('5. Создание перечислений...')
        e_qual = Enum.objects.create(name='qualification', display_name='Квалификация')
        ev_q1 = EnumValue.objects.create(
            enum=e_qual,
            name='q1',
            display_name='4 разряд',
            value_int=4
        )
        ev_q2 = EnumValue.objects.create(
            enum=e_qual,
            name='q2',
            display_name='5 разряд',
            value_int=5
        )

        print('6. Создание подразделений...')
        be_welding = BusinessEntity.objects.create(
            class_field=c_department,
            name='welding',
            display_name='Сварочный цех'
        )
        be_machining = BusinessEntity.objects.create(
            class_field=c_department,
            name='machining',
            display_name='Механический цех'
        )

        print('7. Создание групповых рабочих центров...')
        gwc_weld = Gwc.objects.create(
            class_field=c_gwc,
            entity=be_welding,
            name='weld1',
            display_name='Сварочный пост 1'
        )
        gwc_lathe = Gwc.objects.create(
            class_field=c_gwc,
            entity=be_machining,
            name='lathe1',
            display_name='Токарный станок 1'
        )

        print('8. Создание изделий и материалов...')
        p_wire = Products.objects.create(
            code='M.WIRE',
            name='Проволока СВ-08Г2С',
            measure=measures['Килограмм'],
            class_field=c_material
        )
        p_co2 = Products.objects.create(
            code='M.CO2',
            name='Сварочная смесь CO2',
            measure=measures['Килограмм'],
            class_field=c_material
        )
        p_pipe = Products.objects.create(
            code='T.20.800',
            name='Труба 20x2.8, L=800мм',
            measure=measures['Метр'],
            class_field=c_pipe
        )
        p_fitting = Products.objects.create(
            code='F.32.01',
            name='Фитинг переходной 32-01',
            measure=measures['Штука'],
            class_field=c_fitting
        )
        p_nut = Products.objects.create(
            code='11.01.02.022-01',
            name='Гайка',
            measure=measures['Штука'],
            class_field=c_fitting
        )
        p_sht = Products.objects.create(
            code='31.01.07.017',
            name='Штуцер',
            measure=measures['Штука'],
            class_field=c_fitting
        )
        p_ptr1 = Products.objects.create(
            code='КП25.00.21.221',
            name='Патрубок',
            measure=measures['Штука'],
            class_field=c_fitting
        )
        p_ptr2 = Products.objects.create(
            code='КП25.00.21.221-01',
            name='Патрубок модифицированный',
            measure=measures['Штука'],
            class_field=c_fitting,
            modification=p_ptr1
        )
        p_wrench = Products.objects.create(
            code='TOOL.WRENCH.10',
            name='Гаечный ключ 10 мм',
            measure=measures['Штука'],
            class_field=c_tool
        )
        p_pipe_sys = Products.objects.create(
            code='PIPE_SYS_01',
            name='Трубопровод узел 1',
            measure=measures['Штука'],
            class_field=c_pipe
        )

        print('9. Назначение параметров изделиям...')
        ProductParameter.objects.create(
            product=p_pipe,
            parameter=p_diameter,
            value_real=25.0
        )
        ProductParameter.objects.create(
            product=p_pipe,
            parameter=p_length,
            value_real=0.8
        )

        print('10. Формирование спецификаций (BOM)...')
        Bom.objects.create(parent=p_pipe_sys, child=p_wire, quantity=0.15)
        Bom.objects.create(parent=p_pipe_sys, child=p_co2, quantity=0.3)
        Bom.objects.create(parent=p_pipe_sys, child=p_pipe, quantity=2.5)
        Bom.objects.create(parent=p_pipe_sys, child=p_fitting, quantity=3)
        Bom.objects.create(parent=p_pipe_sys, child=p_nut, quantity=2)
        Bom.objects.create(parent=p_pipe_sys, child=p_sht, quantity=1)
        Bom.objects.create(parent=p_pipe_sys, child=p_ptr1, quantity=1)
        Bom.objects.create(parent=p_pipe_sys, child=p_ptr2, quantity=1)

        Bom.objects.create(parent=p_ptr1, child=p_pipe, quantity=0.0542)
        Bom.objects.create(parent=p_ptr2, child=p_pipe, quantity=0.1024)

        print('11. Создание правил конфигурации...')
        rule_bigger_pipe = ConfigRule.objects.create(
            name='bigger_pipe_rule',
            description='Добавлять фланцы, если диаметр > 25 мм'
        )
        pred_diameter = RulePredicate.objects.create(
            parameter=p_diameter,
            value_real=25.0,
            operator='>'
        )
        RuleCondition.objects.create(rule=rule_bigger_pipe, predicate=pred_diameter, order=1)

        print('12. Создание маршрутной карты...')
        op_cut = TechOp.objects.create(
            product=p_pipe_sys,
            pos=1,
            op_class=Class.objects.get_or_create(name='cutting', display_name='Резка', measure=measures['Штука'])[0],
            prof_class=Class.objects.get_or_create(name='sawyer', display_name='Резчик', measure=measures['Штука'])[0],
            gwc=gwc_lathe,
            qualification=ev_q1,
            work_time=15.0
        )
        op_fitup = TechOp.objects.create(
            product=p_pipe_sys,
            pos=2,
            op_class=Class.objects.get_or_create(name='fitup', display_name='Сборка', measure=measures['Штука'])[0],
            prof_class=Class.objects.get_or_create(name='fitter', display_name='Слесарь-сборщик', measure=measures['Штука'])[0],
            gwc=gwc_weld,
            qualification=ev_q2,
            work_time=25.0
        )
        op_weld = TechOp.objects.create(
            product=p_pipe_sys,
            pos=3,
            op_class=Class.objects.get_or_create(name='welding', display_name='Сварка', measure=measures['Штука'])[0],
            prof_class=Class.objects.get_or_create(name='welder', display_name='Сварщик', measure=measures['Штука'])[0],
            gwc=gwc_weld,
            qualification=ev_q2,
            work_time=40.0
        )

        print('13. Назначение входных ресурсов...')
        InputResource.objects.create(in_to=op_weld, out_to=op_cut, product=p_wire, in_quantity=0.15, out_quantity=0.15)
        InputResource.objects.create(in_to=op_weld, out_to=op_cut, product=p_co2, in_quantity=0.3, out_quantity=0.3)
        InputResource.objects.create(in_to=op_fitup, out_to=op_cut, product=p_pipe, in_quantity=2.5, out_quantity=2.5)
        InputResource.objects.create(in_to=op_fitup, out_to=op_fitup, product=p_fitting, in_quantity=3, out_quantity=3)
        InputResource.objects.create(in_to=op_weld, out_to=op_fitup, product=p_pipe_sys, in_quantity=1, out_quantity=1)
        InputResource.objects.create(in_to=op_fitup, out_to=op_fitup, product=p_wrench, in_quantity=1, out_quantity=1)

        print('14. Создание заказов...')
        order1 = Orders.objects.create(entity=be_welding, status='created')
        OrderPos.objects.create(order=order1, product=p_pipe_sys, quantity=5)

        order2 = Orders.objects.create(entity=be_machining, status='confirmed')
        OrderPos.objects.create(order=order2, product=p_pipe, quantity=100)

        print('=== ЗАПОЛНЕНИЕ ЗАВЕРШЕНО УСПЕШНО ===')

    except IntegrityError as e:
        print(f'Ошибка базы данных: {e}')
        raise
    except Exception as e:
        print(f'Непредвиденная ошибка: {e}')
        raise
