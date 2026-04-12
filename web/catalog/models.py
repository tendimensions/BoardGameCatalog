from django.conf import settings
from django.db import models


class Game(models.Model):
    """
    A board game record.
    bgg_id is populated from BoardGameGeek sync.
    upc is populated EXCLUSIVELY from mobile app barcode scans via GameUPC
    (REQ-CM-014, REQ-CM-021, design decision confirmed in REQUIREMENTS-AND-DESIGN.md §14.2).
    """

    bgg_id = models.IntegerField(unique=True, null=True, blank=True)
    upc = models.CharField(max_length=50, blank=True)
    title = models.CharField(max_length=255)
    year_published = models.IntegerField(null=True, blank=True)
    min_players = models.IntegerField(null=True, blank=True)
    max_players = models.IntegerField(null=True, blank=True)
    playing_time = models.IntegerField(null=True, blank=True)
    min_age = models.IntegerField(null=True, blank=True)
    description = models.TextField(blank=True)
    thumbnail_url = models.URLField(max_length=500, blank=True)
    image_url = models.URLField(max_length=500, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'games'
        indexes = [
            models.Index(fields=['bgg_id']),
            models.Index(fields=['upc']),
            models.Index(fields=['title']),
        ]
        ordering = ['title']

    def __str__(self):
        return f"{self.title} ({self.year_published})" if self.year_published else self.title

    @property
    def players_display(self):
        if self.min_players and self.max_players:
            if self.min_players == self.max_players:
                return str(self.min_players)
            return f"{self.min_players}–{self.max_players}"
        return str(self.min_players or self.max_players or '—')

    @property
    def play_time_display(self):
        return f"{self.playing_time} min" if self.playing_time else '—'


class UserCollection(models.Model):
    """
    Tracks which games a user owns and how they were added.
    Lending fields are present now (schema-level) but the lending
    feature is implemented in Phase 6 (REQ-FE-010 through REQ-FE-018).
    """

    SOURCE_BGG = 'bgg_sync'
    SOURCE_MANUAL = 'manual'
    SOURCE_BARCODE = 'barcode'
    SOURCE_CHOICES = [
        (SOURCE_BGG, 'BGG Sync'),
        (SOURCE_MANUAL, 'Manual'),
        (SOURCE_BARCODE, 'Barcode Scan'),
    ]

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='collection'
    )
    game = models.ForeignKey(Game, on_delete=models.CASCADE, related_name='in_collections')
    acquisition_date = models.DateField(null=True, blank=True)
    notes = models.TextField(blank=True)
    source = models.CharField(max_length=50, choices=SOURCE_CHOICES, default=SOURCE_MANUAL)

    # Future (Phase 6): Game lending tracking
    is_lent = models.BooleanField(default=False)
    lent_to = models.CharField(max_length=255, blank=True)
    lent_date = models.DateField(null=True, blank=True)
    lent_notes = models.TextField(blank=True)

    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'user_collections'
        unique_together = [('user', 'game')]
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['game']),
            models.Index(fields=['is_lent']),
        ]

    def __str__(self):
        return f"{self.user.username} owns {self.game.title}"


class PartyList(models.Model):
    """A curated list of games a user plans to bring to an event (Phase 4)."""

    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='party_lists'
    )
    name = models.CharField(max_length=100)
    description = models.TextField(blank=True)
    event_date = models.DateField(null=True, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'party_lists'
        indexes = [models.Index(fields=['owner'])]
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.name} ({self.owner.username})"


class PartyListGame(models.Model):
    """Junction: a game included in a party list."""

    party_list = models.ForeignKey(
        PartyList, on_delete=models.CASCADE, related_name='party_list_games'
    )
    game = models.ForeignKey(Game, on_delete=models.CASCADE)
    added_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'party_list_games'
        unique_together = [('party_list', 'game')]
        indexes = [
            models.Index(fields=['party_list']),
            models.Index(fields=['game']),
        ]


class PartyListShare(models.Model):
    """Grants another user access to a party list (REQ-PL-010, REQ-PL-014)."""

    PERMISSION_VIEW = 'view'
    PERMISSION_EDIT = 'edit'
    PERMISSION_CHOICES = [
        (PERMISSION_VIEW, 'View'),
        (PERMISSION_EDIT, 'Edit'),
    ]

    party_list = models.ForeignKey(
        PartyList, on_delete=models.CASCADE, related_name='shares'
    )
    shared_with_user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='shared_party_lists',
    )
    permission = models.CharField(
        max_length=20, choices=PERMISSION_CHOICES, default=PERMISSION_VIEW
    )
    accepted = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'party_list_shares'
        unique_together = [('party_list', 'shared_with_user')]
        indexes = [
            models.Index(fields=['party_list']),
            models.Index(fields=['shared_with_user']),
        ]


class GameRequest(models.Model):
    """A request to borrow a game from another user for a party (REQ-PL-013)."""

    STATUS_PENDING = 'pending'
    STATUS_ACCEPTED = 'accepted'
    STATUS_DECLINED = 'declined'
    STATUS_CHOICES = [
        (STATUS_PENDING, 'Pending'),
        (STATUS_ACCEPTED, 'Accepted'),
        (STATUS_DECLINED, 'Declined'),
    ]

    party_list = models.ForeignKey(
        PartyList, on_delete=models.CASCADE, related_name='game_requests'
    )
    requester = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='sent_game_requests',
    )
    owner = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='received_game_requests',
    )
    game = models.ForeignKey(Game, on_delete=models.CASCADE)
    message = models.TextField(blank=True)
    status = models.CharField(max_length=20, choices=STATUS_CHOICES, default=STATUS_PENDING)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = 'game_requests'
        indexes = [
            models.Index(fields=['party_list']),
            models.Index(fields=['owner']),
        ]


class UnlinkedBarcode(models.Model):
    """
    A barcode scanned by a user that was not found in GameUPC.com (REQ-CM-040).
    Persisted so the user can link it to a collection game in a follow-up step.
    Deleted immediately if the user dismisses without linking (REQ-CM-048),
    or replaced/updated on subsequent scans of the same UPC by the same user.
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.CASCADE, related_name='unlinked_barcodes'
    )
    upc = models.CharField(max_length=50)
    scanned_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'unlinked_barcodes'
        unique_together = [('user', 'upc')]
        indexes = [models.Index(fields=['user'])]

    def __str__(self):
        return f"{self.upc} (unlinked, {self.user.username})"


class LendingHistory(models.Model):
    """
    Full audit trail for game loans (Phase 6 future enhancement).
    The basic lending state (is_lent, lent_to, lent_date) lives on
    UserCollection; this table captures the complete history.
    """

    user = models.ForeignKey(
        settings.AUTH_USER_MODEL,
        on_delete=models.CASCADE,
        related_name='lending_history',
    )
    game = models.ForeignKey(Game, on_delete=models.CASCADE)
    lent_to = models.CharField(max_length=255)
    lent_date = models.DateField()
    returned_date = models.DateField(null=True, blank=True)
    lent_notes = models.TextField(blank=True)
    return_notes = models.TextField(blank=True)
    created_at = models.DateTimeField(auto_now_add=True)

    class Meta:
        db_table = 'lending_history'
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['game']),
            models.Index(fields=['returned_date']),
        ]
