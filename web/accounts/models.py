import secrets

from django.contrib.auth.models import AbstractUser
from django.db import models


class User(AbstractUser):
    """
    Custom user model.  BGG username is optional at registration and
    cannot be changed after creation (REQ-UM-022).
    Email cannot be changed after creation (REQ-UM-021).
    """

    # Tighten username to 50 chars as per the schema
    username = models.CharField(max_length=50, unique=True)
    email = models.EmailField(unique=True)
    bgg_username = models.CharField(max_length=50, blank=True)
    email_verified = models.BooleanField(default=False)
    verification_token = models.CharField(max_length=255, blank=True)

    REQUIRED_FIELDS = ['email']

    class Meta:
        db_table = 'users'

    def generate_verification_token(self):
        """Generate and persist a one-time email verification token."""
        self.verification_token = secrets.token_urlsafe(32)
        self.save(update_fields=['verification_token'])
        return self.verification_token


class APIKey(models.Model):
    """
    API keys used by the mobile application.
    Keys are 256-bit (64 hex chars) cryptographically random values.
    (REQ-UM-023, REQ-UM-024)
    """

    user = models.ForeignKey(User, on_delete=models.CASCADE, related_name='api_keys')
    key = models.CharField(max_length=64, unique=True)
    name = models.CharField(max_length=100, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    last_used_at = models.DateTimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        db_table = 'api_keys'
        indexes = [
            models.Index(fields=['user']),
            models.Index(fields=['key']),
        ]
        ordering = ['-created_at']

    def __str__(self):
        return f"{self.name or 'Unnamed'} ({self.user.username})"

    @classmethod
    def generate(cls, user, name=''):
        """Create and return a new API key for the given user."""
        key = secrets.token_hex(32)  # 64 hex chars = 256 bits
        return cls.objects.create(user=user, key=key, name=name)
