import secrets

from django.contrib import admin
from django.contrib.auth.admin import UserAdmin as BaseUserAdmin

from .models import User, APIKey


@admin.register(User)
class UserAdmin(BaseUserAdmin):
    fieldsets = BaseUserAdmin.fieldsets + (
        ('Board Game Catalog', {
            'fields': ('bgg_username', 'email_verified', 'verification_token'),
        }),
    )
    add_fieldsets = BaseUserAdmin.add_fieldsets + (
        ('Board Game Catalog', {
            'fields': ('email', 'bgg_username'),
        }),
    )
    list_display = ('username', 'email', 'bgg_username', 'email_verified', 'is_active', 'date_joined')
    list_filter = ('email_verified', 'is_active', 'is_staff')
    search_fields = ('username', 'email', 'bgg_username')
    readonly_fields = ('verification_token',)


@admin.register(APIKey)
class APIKeyAdmin(admin.ModelAdmin):
    list_display = ('name', 'user', 'key', 'created_at', 'last_used_at', 'is_active')
    list_filter = ('is_active',)
    search_fields = ('user__username', 'name')
    readonly_fields = ('key', 'created_at', 'last_used_at')
    raw_id_fields = ('user',)

    def save_model(self, request, obj, form, change):
        if not change and not obj.key:
            obj.key = secrets.token_hex(32)
        super().save_model(request, obj, form, change)
