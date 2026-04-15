from rest_framework import serializers

from .models import Game, GameList, GameListEntry, UserCollection


class GameSerializer(serializers.ModelSerializer):
    players_display = serializers.CharField(read_only=True)
    play_time_display = serializers.CharField(read_only=True)

    class Meta:
        model = Game
        fields = [
            'id', 'bgg_id', 'upc', 'title', 'year_published',
            'min_players', 'max_players', 'playing_time',
            'thumbnail_url', 'image_url',
            'players_display', 'play_time_display',
        ]


class CollectionItemSerializer(serializers.ModelSerializer):
    game = GameSerializer(read_only=True)

    class Meta:
        model = UserCollection
        fields = [
            'id', 'game', 'source', 'acquisition_date', 'notes',
            'is_lent', 'lent_to', 'lent_date', 'created_at',
        ]


class GameListSerializer(serializers.ModelSerializer):
    entry_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = GameList
        fields = ['id', 'name', 'description', 'entry_count', 'created_at', 'updated_at']


class GameListEntrySerializer(serializers.ModelSerializer):
    game = GameSerializer(read_only=True)

    class Meta:
        model = GameListEntry
        fields = ['id', 'game', 'note', 'added_via', 'created_at', 'updated_at']


class GameListDetailSerializer(serializers.ModelSerializer):
    entries = GameListEntrySerializer(many=True, read_only=True)
    entry_count = serializers.IntegerField(read_only=True)

    class Meta:
        model = GameList
        fields = ['id', 'name', 'description', 'entry_count', 'entries', 'created_at', 'updated_at']
