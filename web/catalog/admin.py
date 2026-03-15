from django.contrib import admin

from .models import (
    Game, UserCollection,
    PartyList, PartyListGame, PartyListShare,
    GameRequest, LendingHistory,
)


@admin.register(Game)
class GameAdmin(admin.ModelAdmin):
    list_display = ('title', 'year_published', 'players_display', 'playing_time', 'bgg_id', 'upc')
    list_filter = ('year_published',)
    search_fields = ('title', 'bgg_id', 'upc')
    readonly_fields = ('created_at', 'updated_at')

    @admin.display(description='Players')
    def players_display(self, obj):
        return obj.players_display


@admin.register(UserCollection)
class UserCollectionAdmin(admin.ModelAdmin):
    list_display = ('user', 'game', 'source', 'is_lent', 'acquisition_date', 'created_at')
    list_filter = ('source', 'is_lent')
    search_fields = ('user__username', 'game__title')
    raw_id_fields = ('user', 'game')
    readonly_fields = ('created_at',)


@admin.register(PartyList)
class PartyListAdmin(admin.ModelAdmin):
    list_display = ('name', 'owner', 'event_date', 'created_at')
    search_fields = ('name', 'owner__username')
    raw_id_fields = ('owner',)


@admin.register(PartyListShare)
class PartyListShareAdmin(admin.ModelAdmin):
    list_display = ('party_list', 'shared_with_user', 'permission', 'accepted')
    list_filter = ('permission', 'accepted')
    raw_id_fields = ('party_list', 'shared_with_user')


@admin.register(GameRequest)
class GameRequestAdmin(admin.ModelAdmin):
    list_display = ('game', 'requester', 'owner', 'party_list', 'status', 'created_at')
    list_filter = ('status',)
    search_fields = ('game__title', 'requester__username', 'owner__username')
    raw_id_fields = ('party_list', 'requester', 'owner', 'game')


@admin.register(LendingHistory)
class LendingHistoryAdmin(admin.ModelAdmin):
    list_display = ('user', 'game', 'lent_to', 'lent_date', 'returned_date')
    list_filter = ('returned_date',)
    search_fields = ('user__username', 'game__title', 'lent_to')
    raw_id_fields = ('user', 'game')
