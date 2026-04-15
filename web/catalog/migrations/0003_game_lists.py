import django.db.models.deletion
from django.conf import settings
from django.db import migrations, models


class Migration(migrations.Migration):

    dependencies = [
        ("catalog", "0002_unlinked_barcode"),
        migrations.swappable_dependency(settings.AUTH_USER_MODEL),
    ]

    operations = [
        migrations.CreateModel(
            name="GameList",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                ("name", models.CharField(max_length=100)),
                ("description", models.TextField(blank=True)),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "user",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="game_lists",
                        to=settings.AUTH_USER_MODEL,
                    ),
                ),
            ],
            options={
                "db_table": "game_lists",
                "ordering": ["-created_at"],
                "indexes": [
                    models.Index(fields=["user"], name="game_lists_user_id_idx")
                ],
            },
        ),
        migrations.CreateModel(
            name="GameListEntry",
            fields=[
                (
                    "id",
                    models.BigAutoField(
                        auto_created=True,
                        primary_key=True,
                        serialize=False,
                        verbose_name="ID",
                    ),
                ),
                (
                    "note",
                    models.TextField(blank=True),
                ),
                (
                    "added_via",
                    models.CharField(
                        choices=[("manual", "Manual"), ("barcode", "Barcode")],
                        default="manual",
                        max_length=20,
                    ),
                ),
                ("created_at", models.DateTimeField(auto_now_add=True)),
                ("updated_at", models.DateTimeField(auto_now=True)),
                (
                    "game",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="list_entries",
                        to="catalog.game",
                    ),
                ),
                (
                    "game_list",
                    models.ForeignKey(
                        on_delete=django.db.models.deletion.CASCADE,
                        related_name="entries",
                        to="catalog.gamelist",
                    ),
                ),
            ],
            options={
                "db_table": "game_list_entries",
                "ordering": ["-created_at"],
                "indexes": [
                    models.Index(
                        fields=["game_list"], name="game_list_entries_list_id_idx"
                    ),
                    models.Index(
                        fields=["game"], name="game_list_entries_game_id_idx"
                    ),
                ],
                "unique_together": {("game_list", "game")},
            },
        ),
    ]
