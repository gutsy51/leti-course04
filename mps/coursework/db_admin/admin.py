from django.contrib import admin
from django import forms
from .models import (
    Measure, Class, Products, Enum, EnumValue, Parameter,
    ClassParameter, ProductParameter, Bom, BusinessEntity,
    Gwc, TechOp, InputResource, Orders, OrderPos,
    ConfigRule, RulePredicate, RuleCondition
)


# ———————————————————————— Справочники ———————————————————————— #

@admin.register(Measure)
class MeasureAdmin(admin.ModelAdmin):
    list_display = ('name', 'name_short')
    search_fields = ('name', 'name_short')
    ordering = ('name',)
    list_per_page = 20


class ClassForm(forms.ModelForm):
    class Meta:
        model = Class
        fields = '__all__'

    def clean(self):
        cleaned_data = super().clean()
        parent = cleaned_data.get('parent')
        measure = cleaned_data.get('measure')

        if parent == self.instance:
            raise forms.ValidationError("Класс не может быть подклассом самого себя.")
        if parent and parent.measure and measure != parent.measure:
            raise forms.ValidationError(
                "Подкласс должен иметь ту же единицу измерения, что и родительский класс."
            )
        return cleaned_data


@admin.register(Class)
class ClassAdmin(admin.ModelAdmin):
    form = ClassForm
    list_display = ('display_name', 'name', 'parent', 'measure')
    list_filter = ('measure',)
    search_fields = ('name', 'display_name')
    ordering = ('name',)
    raw_id_fields = ('parent',)
    list_per_page = 20


@admin.register(Products)
class ProductsAdmin(admin.ModelAdmin):
    list_display = ('name', 'code', 'class_field', 'measure')
    list_filter = ('class_field', 'measure')
    search_fields = ('name', 'code')
    ordering = ('name',)
    raw_id_fields = ('class_field', 'measure', 'modification', 'change')
    list_per_page = 20


@admin.register(Enum)
class EnumAdmin(admin.ModelAdmin):
    list_display = ('name', 'display_name')
    search_fields = ('name', 'display_name')
    ordering = ('name',)


class EnumValueForm(forms.ModelForm):
    class Meta:
        model = EnumValue
        fields = '__all__'

    def clean(self):
        cleaned_data = super().clean()
        enum = cleaned_data.get('enum')
        if enum:
            fields = [cleaned_data.get(f'value_{t}') for t in ('int', 'real', 'str', 'class')]
            filled = [v for v in fields if v is not None]
            if len(filled) != 1:
                raise forms.ValidationError(
                    "Должно быть заполнено ровно одно значение: целое, вещественное, строка или класс."
                )
        return cleaned_data


@admin.register(EnumValue)
class EnumValueAdmin(admin.ModelAdmin):
    form = EnumValueForm
    list_display = ('enum', 'display_name', 'name', 'get_value')
    list_filter = ('enum',)
    search_fields = ('name', 'display_name')
    ordering = ('enum', 'name')
    list_per_page = 20

    def get_value(self, obj):
        if obj.value_int is not None:
            return str(obj.value_int)
        if obj.value_real is not None:
            return f"{obj.value_real:.2f}"
        if obj.value_str:
            return obj.value_str
        if obj.value_class:
            return str(obj.value_class)
        return "-"
    get_value.short_description = 'Значение'


class ParameterForm(forms.ModelForm):
    class Meta:
        model = Parameter
        fields = '__all__'

    def clean(self):
        cleaned_data = super().clean()
        value_class = cleaned_data.get('value_class')
        if value_class and not value_class.name.startswith('class.'):
            raise forms.ValidationError(
                "Параметр, ссылающийся на класс, должен быть привязан к классу с префиксом 'class.'"
            )
        return cleaned_data


@admin.register(Parameter)
class ParameterAdmin(admin.ModelAdmin):
    form = ParameterForm
    list_display = ('display_name', 'name', 'class_field', 'measure')
    list_filter = ('class_field', 'measure')
    search_fields = ('name', 'display_name')
    ordering = ('class_field', 'name')
    raw_id_fields = ('class_field', 'measure')
    list_per_page = 20


# ———————————————————————— Назначения ———————————————————————— #

@admin.register(ClassParameter)
class ClassParameterAdmin(admin.ModelAdmin):
    list_display = ('class_field', 'parameter', 'is_required', 'min_value', 'max_value')
    list_filter = ('class_field', 'is_required', 'parameter')
    search_fields = ('class_field__name', 'parameter__name')
    raw_id_fields = ('class_field', 'parameter')
    list_per_page = 20


class ProductParameterAdminForm(forms.ModelForm):
    class Meta:
        model = ProductParameter
        fields = '__all__'

    def clean(self):
        cleaned_data = super().clean()
        parameter = cleaned_data.get('parameter')
        value_enum = cleaned_data.get('value_enum')

        if parameter and parameter.data_type == 'enum' and not value_enum:
            raise forms.ValidationError("Для параметра типа 'enum' требуется значение из перечисления.")
        if parameter and parameter.data_type != 'enum' and value_enum:
            raise forms.ValidationError("Значение перечисления можно указывать только для параметров типа 'enum'.")
        return cleaned_data


@admin.register(ProductParameter)
class ProductParameterAdmin(admin.ModelAdmin):
    form = ProductParameterAdminForm
    list_display = ('product', 'parameter', 'get_value')
    list_filter = ('parameter',)
    search_fields = ('product__name', 'parameter__name')
    raw_id_fields = ('product', 'parameter', 'value_enum')
    list_per_page = 20

    def get_value(self, obj):
        if obj.value_int is not None:
            return str(obj.value_int)
        if obj.value_real is not None:
            return f"{obj.value_real:.2f}"
        if obj.value_str:
            return obj.value_str
        if obj.value_enum:
            return obj.value_enum.display_name or obj.value_enum.name
        return "-"
    get_value.short_description = 'Значение'


# ———————————————————————— Структуры ———————————————————————— #

@admin.register(Bom)
class BomAdmin(admin.ModelAdmin):
    list_display = ('parent', 'child', 'quantity', 'config_rule')
    list_filter = ('parent', 'config_rule')
    search_fields = ('parent__name', 'child__name', 'parent__code', 'child__code')
    raw_id_fields = ('parent', 'child', 'config_rule')
    list_per_page = 20

    def get_ordering(self, request):
        return ('parent__name', 'child__name')


# ———————————————————————— Производство ———————————————————————— #

@admin.register(BusinessEntity)
class BusinessEntityAdmin(admin.ModelAdmin):
    list_display = ('display_name', 'class_field', 'parent')
    list_filter = ('class_field',)
    search_fields = ('name', 'display_name')
    raw_id_fields = ('class_field', 'parent')
    list_per_page = 20


@admin.register(Gwc)
class GwcAdmin(admin.ModelAdmin):
    list_display = ('display_name', 'class_field', 'entity')
    list_filter = ('class_field', 'entity')
    search_fields = ('name', 'display_name')
    raw_id_fields = ('class_field', 'entity')
    list_per_page = 20


@admin.register(TechOp)
class TechOpAdmin(admin.ModelAdmin):
    list_display = ('product', 'pos', 'op_class', 'gwc', 'work_time')
    list_filter = ('op_class', 'gwc')
    search_fields = ('product__name',)
    raw_id_fields = ('product', 'op_class', 'prof_class', 'gwc', 'qualification')
    list_per_page = 20


@admin.register(InputResource)
class InputResourceAdmin(admin.ModelAdmin):
    list_display = ('in_to', 'out_to', 'product', 'in_quantity', 'out_quantity')
    raw_id_fields = ('in_to', 'out_to', 'product')
    list_per_page = 20


# ———————————————————————— Правила конфигурации ———————————————————————— #

@admin.register(ConfigRule)
class ConfigRuleAdmin(admin.ModelAdmin):
    list_display = ('name', 'created_at')
    search_fields = ('name',)
    date_hierarchy = 'created_at'
    list_per_page = 20


@admin.register(RulePredicate)
class RulePredicateAdmin(admin.ModelAdmin):
    list_display = ('parameter', 'operator', 'get_value')
    list_filter = ('parameter', 'operator')
    raw_id_fields = ('parameter', 'enum_value')
    list_per_page = 20

    def get_value(self, obj):
        if obj.value_int is not None:
            return str(obj.value_int)
        if obj.value_real is not None:
            return str(obj.value_real)
        if obj.value_str:
            return obj.value_str
        if obj.enum_value:
            return obj.enum_value.display_name
        return "-"
    get_value.short_description = 'Значение'


@admin.register(RuleCondition)
class RuleConditionAdmin(admin.ModelAdmin):
    list_display = ('rule', 'predicate', 'order', 'logic_op')
    list_filter = ('rule', 'logic_op')
    raw_id_fields = ('rule', 'predicate')
    list_per_page = 20


# ———————————————————————— Заказы ———————————————————————— #

@admin.register(Orders)
class OrdersAdmin(admin.ModelAdmin):
    list_display = ('id', 'entity', 'created_at', 'status')
    list_filter = ('status', 'created_at')
    search_fields = ('entity__name',)
    date_hierarchy = 'created_at'
    list_per_page = 20


@admin.register(OrderPos)
class OrderPosAdmin(admin.ModelAdmin):
    list_display = ('order', 'product', 'quantity')
    raw_id_fields = ('order', 'product')
    list_per_page = 20
