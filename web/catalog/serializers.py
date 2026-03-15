from rest_framework import serializers

from .models import Game, UserCollection


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
