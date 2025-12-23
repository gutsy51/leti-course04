from django.db import models


class Measure(models.Model):
    name = models.TextField(unique=True)
    name_short = models.TextField(unique=True)

    class Meta:
        managed = False
        db_table = 'measure'
        verbose_name = 'Единица измерения'
        verbose_name_plural = 'Единицы измерения'

    def __str__(self):
        return self.name_short or self.name


class Enum(models.Model):
    name = models.TextField()
    display_name = models.TextField()

    class Meta:
        managed = False
        db_table = 'enum'
        verbose_name = 'Перечисление'
        verbose_name_plural = 'Перечисления'

    def __str__(self):
        return self.display_name or self.name


class Class(models.Model):
    name = models.TextField()
    display_name = models.TextField()
    parent = models.ForeignKey('self', models.DO_NOTHING, blank=True, null=True)
    measure = models.ForeignKey(Measure, models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'class'
        verbose_name = 'Класс'
        verbose_name_plural = 'Классы'

    def __str__(self):
        return self.display_name or self.name


class Products(models.Model):
    code = models.TextField(unique=True)
    name = models.TextField()
    measure = models.ForeignKey(Measure, models.DO_NOTHING)
    class_field = models.ForeignKey(Class, models.DO_NOTHING, db_column='class_id', blank=True, null=True)
    modification = models.ForeignKey('self', models.DO_NOTHING, blank=True, null=True, related_name='modified_products')
    change = models.ForeignKey('self', models.DO_NOTHING, blank=True, null=True, related_name='changed_products')

    class Meta:
        managed = False
        db_table = 'products'
        verbose_name = 'Изделие'
        verbose_name_plural = 'Изделия'

    def __str__(self):
        return f"{self.name} ({self.code})"


class BusinessEntity(models.Model):
    class_field = models.ForeignKey(Class, models.DO_NOTHING, db_column='class_id')
    name = models.TextField()
    display_name = models.TextField()
    parent = models.ForeignKey('self', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'business_entity'
        verbose_name = 'Бизнес-объект'
        verbose_name_plural = 'Бизнес-объекты'

    def __str__(self):
        return self.display_name or self.name


class Gwc(models.Model):
    class_field = models.ForeignKey(Class, models.DO_NOTHING, db_column='class_id')
    entity = models.ForeignKey(BusinessEntity, models.DO_NOTHING, db_column='entity_id')
    name = models.TextField()
    display_name = models.TextField()

    class Meta:
        managed = False
        db_table = 'gwc'
        verbose_name = 'Групповой рабочий центр'
        verbose_name_plural = 'Групповые рабочие центры'

    def __str__(self):
        return self.display_name or self.name


class EnumValue(models.Model):
    enum = models.ForeignKey(Enum, models.DO_NOTHING)
    name = models.TextField()
    display_name = models.TextField()
    value_int = models.IntegerField(blank=True, null=True)
    value_real = models.FloatField(blank=True, null=True)
    value_str = models.TextField(blank=True, null=True)
    value_class = models.ForeignKey(Class, models.DO_NOTHING, db_column='value_class', blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'enum_value'
        verbose_name = 'Значение перечисления'
        verbose_name_plural = 'Значения перечислений'

    def __str__(self):
        return self.display_name or self.name


class TechOp(models.Model):
    product = models.ForeignKey(Products, models.DO_NOTHING)
    pos = models.IntegerField()
    op_class = models.ForeignKey(Class, models.DO_NOTHING, related_name='techop_op_class_set')
    prof_class = models.ForeignKey(Class, models.DO_NOTHING, related_name='techop_prof_class_set')
    gwc = models.ForeignKey(Gwc, models.DO_NOTHING)
    qualification = models.ForeignKey(EnumValue, models.DO_NOTHING, blank=True, null=True)
    work_time = models.FloatField()

    class Meta:
        managed = False
        db_table = 'tech_op'
        verbose_name = 'Технологическая операция'
        verbose_name_plural = 'Технологические операции'

    def __str__(self):
        return f"{self.product.name} - {self.pos}"


class Parameter(models.Model):
    class_field = models.ForeignKey(Class, models.DO_NOTHING, db_column='class_id')
    measure = models.ForeignKey(Measure, models.DO_NOTHING)
    name = models.TextField()
    display_name = models.TextField()

    class Meta:
        managed = False
        db_table = 'parameter'
        verbose_name = 'Параметр'
        verbose_name_plural = 'Параметры'

    def __str__(self):
        return self.display_name or self.name


class ConfigRule(models.Model):
    name = models.TextField()
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'config_rule'
        verbose_name = 'Правило конфигурации'
        verbose_name_plural = 'Правила конфигурации'

    def __str__(self):
        return self.name


class RulePredicate(models.Model):
    parameter = models.ForeignKey(Parameter, models.DO_NOTHING)
    value_int = models.IntegerField(blank=True, null=True)
    value_real = models.FloatField(blank=True, null=True)
    value_str = models.TextField(blank=True, null=True)
    enum_value = models.ForeignKey(EnumValue, models.DO_NOTHING, blank=True, null=True)
    operator = models.TextField()

    class Meta:
        managed = False
        db_table = 'rule_predicate'
        verbose_name = 'Условие правила'
        verbose_name_plural = 'Условия правил'

    def __str__(self):
        return f"{self.parameter.name} {self.operator}"


class RuleCondition(models.Model):
    rule = models.ForeignKey(ConfigRule, models.DO_NOTHING)
    predicate = models.ForeignKey(RulePredicate, models.DO_NOTHING)
    order = models.IntegerField(blank=True, null=True)
    logic_op = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'rule_condition'
        verbose_name = 'Условие в правиле'
        verbose_name_plural = 'Условия в правилах'
        # Убираем id
        # id = None  # ← не нужно здесь

    def __str__(self):
        return f"{self.rule.name} - {self.predicate}"


class Bom(models.Model):
    parent = models.ForeignKey(Products, models.DO_NOTHING, related_name='bom_parent_set')
    child = models.ForeignKey(Products, models.DO_NOTHING, related_name='bom_child_set')
    quantity = models.DecimalField(max_digits=18, decimal_places=6)
    config_rule = models.ForeignKey(ConfigRule, models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'bom'
        unique_together = (('parent', 'child', 'config_rule'),)
        verbose_name = 'Состав изделия (BOM)'
        verbose_name_plural = 'Составы изделий (BOM)'

    def __str__(self):
        child_code = self.child.code if self.child else "N/A"
        return f"{self.parent.code} → {child_code}"


class InputResource(models.Model):
    in_to = models.ForeignKey('TechOp', models.DO_NOTHING, db_column='in_to', related_name='input_resources_in')
    out_to = models.ForeignKey('TechOp', models.DO_NOTHING, db_column='out_to', related_name='input_resources_out')
    product = models.ForeignKey('Products', models.DO_NOTHING, db_column='product_id')
    in_quantity = models.DecimalField(max_digits=18, decimal_places=6)
    out_quantity = models.DecimalField(max_digits=18, decimal_places=6)

    class Meta:
        managed = False
        db_table = 'input_resource'
        verbose_name = 'Входной ресурс'
        verbose_name_plural = 'Входные ресурсы'


class ClassParameter(models.Model):
    class_field = models.ForeignKey(Class, models.DO_NOTHING, db_column='class_id')
    parameter = models.ForeignKey(Parameter, models.DO_NOTHING)
    min_value = models.FloatField(blank=True, null=True)
    max_value = models.FloatField(blank=True, null=True)
    is_required = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'class_parameter'
        unique_together = (('class_field', 'parameter'),)
        verbose_name = 'Параметр класса'
        verbose_name_plural = 'Параметры классов'

    def __str__(self):
        return f"{self.class_field} - {self.parameter}"


class ProductParameter(models.Model):
    product = models.ForeignKey('Products', models.DO_NOTHING, db_column='product_id')
    parameter = models.ForeignKey('Parameter', models.DO_NOTHING, db_column='parameter_id')
    value_int = models.IntegerField(blank=True, null=True)
    value_real = models.FloatField(blank=True, null=True)
    value_str = models.TextField(blank=True, null=True)
    value_enum = models.ForeignKey('EnumValue', models.DO_NOTHING, db_column='value_enum', blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'product_parameter'
        verbose_name = 'Значение параметра изделия'
        verbose_name_plural = 'Значения параметров изделий'

    def __str__(self):
        return f"{self.product.name} - {self.parameter.name}"


class Orders(models.Model):
    entity = models.ForeignKey(BusinessEntity, models.DO_NOTHING)
    created_at = models.DateTimeField(auto_now_add=True)
    status = models.TextField()

    class Meta:
        managed = False
        db_table = 'orders'
        verbose_name = 'Заказ'
        verbose_name_plural = 'Заказы'

    def __str__(self):
        return f"Order {self.id} - {self.status}"


class OrderPos(models.Model):
    order = models.ForeignKey(Orders, models.DO_NOTHING)
    product = models.ForeignKey(Products, models.DO_NOTHING)
    quantity = models.DecimalField(max_digits=18, decimal_places=6)

    class Meta:
        managed = False
        db_table = 'order_pos'
        unique_together = (('order', 'product'),)
        verbose_name = 'Позиция заказа'
        verbose_name_plural = 'Позиции заказов'

    def __str__(self):
        return f"{self.order} - {self.product.name}"
