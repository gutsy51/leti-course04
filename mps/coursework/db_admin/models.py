from django.db import models


class Bom(models.Model):
    parent = models.ForeignKey('Products', models.DO_NOTHING, related_name='bom_parent_set')
    child = models.ForeignKey('Products', models.DO_NOTHING, related_name='bom_child_set')
    quantity = models.DecimalField(max_digits=18, decimal_places=6)
    config_rule = models.ForeignKey('ConfigRule', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'bom'
        unique_together = (('parent', 'child', 'config_rule'),)  # Эмуляция составного PK


class BusinessEntity(models.Model):
    class_field = models.ForeignKey('Class', models.DO_NOTHING, db_column='class_id')
    name = models.TextField()
    display_name = models.TextField()
    parent = models.ForeignKey('self', models.DO_NOTHING, blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'business_entity'


class Class(models.Model):
    name = models.TextField()
    display_name = models.TextField()
    parent = models.ForeignKey('self', models.DO_NOTHING, blank=True, null=True)
    measure = models.ForeignKey('Measure', models.DO_NOTHING)

    class Meta:
        managed = False
        db_table = 'class'


class ClassParameter(models.Model):
    class_field = models.ForeignKey(Class, models.DO_NOTHING, db_column='class_id')
    parameter = models.ForeignKey('Parameter', models.DO_NOTHING)
    min_value = models.FloatField(blank=True, null=True)
    max_value = models.FloatField(blank=True, null=True)
    is_required = models.BooleanField()

    class Meta:
        managed = False
        db_table = 'class_parameter'
        unique_together = (('class_field', 'parameter'),)


class ConfigRule(models.Model):
    name = models.TextField()
    description = models.TextField(blank=True, null=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        managed = False
        db_table = 'config_rule'


class Enum(models.Model):
    name = models.TextField()
    display_name = models.TextField()

    class Meta:
        managed = False
        db_table = 'enum'

    def __str__(self):
        return self.display_name or self.name


class EnumValue(models.Model):
    enum = models.ForeignKey('Enum', models.DO_NOTHING)
    name = models.TextField()
    display_name = models.TextField()
    value_int = models.IntegerField(blank=True, null=True)
    value_real = models.FloatField(blank=True, null=True)
    value_str = models.TextField(blank=True, null=True)
    value_class = models.ForeignKey(Class, models.DO_NOTHING, db_column='value_class', blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'enum_value'


class InputResource(models.Model):
    in_to = models.ForeignKey('TechOp', models.DO_NOTHING, related_name='input_resources_in')
    out_to = models.ForeignKey('TechOp', models.DO_NOTHING, related_name='input_resources_out')
    product = models.ForeignKey('Products', models.DO_NOTHING)
    in_quantity = models.DecimalField(max_digits=18, decimal_places=6)
    out_quantity = models.DecimalField(max_digits=18, decimal_places=6)

    class Meta:
        managed = False
        db_table = 'input_resource'
        unique_together = (('in_to', 'out_to', 'product'),)


class Measure(models.Model):
    name = models.TextField(unique=True)
    name_short = models.TextField(unique=True)

    class Meta:
        managed = False
        db_table = 'measure'


class OrderPos(models.Model):
    order = models.ForeignKey('Orders', models.DO_NOTHING)
    product = models.ForeignKey('Products', models.DO_NOTHING)
    quantity = models.DecimalField(max_digits=18, decimal_places=6)

    class Meta:
        managed = False
        db_table = 'order_pos'
        unique_together = (('order', 'product'),)


class Orders(models.Model):
    entity = models.ForeignKey(BusinessEntity, models.DO_NOTHING)
    created_at = models.DateTimeField()
    status = models.TextField()

    class Meta:
        managed = False
        db_table = 'orders'


class Parameter(models.Model):
    class_field = models.ForeignKey(Class, models.DO_NOTHING, db_column='class_id')
    measure = models.ForeignKey(Measure, models.DO_NOTHING)
    name = models.TextField()
    display_name = models.TextField()

    class Meta:
        managed = False
        db_table = 'parameter'


class ProductParameter(models.Model):
    product = models.ForeignKey('Products', models.DO_NOTHING)
    parameter = models.ForeignKey(Parameter, models.DO_NOTHING)
    value_int = models.IntegerField(blank=True, null=True)
    value_real = models.FloatField(blank=True, null=True)
    value_str = models.TextField(blank=True, null=True)
    value_enum = models.ForeignKey(EnumValue, models.DO_NOTHING, db_column='value_enum', blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'product_parameter'
        unique_together = (('product', 'parameter'),)


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


class RuleCondition(models.Model):
    rule = models.ForeignKey(ConfigRule, models.DO_NOTHING)
    predicate = models.ForeignKey('RulePredicate', models.DO_NOTHING)
    order = models.IntegerField(blank=True, null=True)
    logic_op = models.TextField(blank=True, null=True)

    class Meta:
        managed = False
        db_table = 'rule_condition'


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


class TechOp(models.Model):
    product = models.ForeignKey(Products, models.DO_NOTHING)
    pos = models.IntegerField()
    op_class = models.ForeignKey(Class, models.DO_NOTHING, related_name='techop_op_class_set')
