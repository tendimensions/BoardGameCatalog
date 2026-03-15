from django import forms
from django.contrib.auth.forms import UserCreationForm, AuthenticationForm

from .models import User


class RegistrationForm(UserCreationForm):
    """
    Registration collects username, email, password, optional BGG username,
    and terms acceptance.  BGG username and email are locked after creation
    (REQ-UM-021, REQ-UM-022).
    """

    email = forms.EmailField(
        required=True,
        widget=forms.EmailInput(attrs={'autocomplete': 'email'}),
    )
    bgg_username = forms.CharField(
        max_length=50,
        required=False,
        label='BoardGameGeek Username',
        help_text='Optional. Cannot be changed after registration.',
        widget=forms.TextInput(attrs={'autocomplete': 'off'}),
    )
    terms = forms.BooleanField(
        required=True,
        label='I accept the terms of service',
        error_messages={'required': 'You must accept the terms of service to create an account.'},
    )

    class Meta:
        model = User
        fields = ('username', 'email', 'bgg_username', 'password1', 'password2')

    def clean_email(self):
        email = self.cleaned_data.get('email', '').lower()
        if User.objects.filter(email__iexact=email).exists():
            raise forms.ValidationError('An account with this email address already exists.')
        return email

    def clean_username(self):
        username = self.cleaned_data.get('username', '')
        if User.objects.filter(username__iexact=username).exists():
            raise forms.ValidationError('This username is already taken.')
        return username

    def save(self, commit=True):
        user = super().save(commit=False)
        user.email = self.cleaned_data['email']
        user.bgg_username = self.cleaned_data.get('bgg_username', '').strip()
        user.is_active = False  # activated only after email verification
        if commit:
            user.save()
        return user


class LoginForm(AuthenticationForm):
    username = forms.CharField(
        widget=forms.TextInput(attrs={'autofocus': True, 'autocomplete': 'username'}),
    )
    password = forms.CharField(
        widget=forms.PasswordInput(attrs={'autocomplete': 'current-password'}),
    )


class ProfileEditForm(forms.ModelForm):
    """Only username is editable (REQ-UM-020). Email and BGG username are read-only."""

    class Meta:
        model = User
        fields = ('username',)

    def clean_username(self):
        username = self.cleaned_data.get('username', '')
        qs = User.objects.filter(username__iexact=username).exclude(pk=self.instance.pk)
        if qs.exists():
            raise forms.ValidationError('This username is already taken.')
        return username


class APIKeyNameForm(forms.Form):
    name = forms.CharField(
        max_length=100,
        required=False,
        label='Key Name (optional)',
        help_text='e.g. "My Android phone" — helps you identify which device uses this key.',
        widget=forms.TextInput(attrs={'placeholder': 'e.g. My Android phone'}),
    )
