import logging

from django.contrib import messages
from django.contrib.auth import login, get_user_model
from django.contrib.auth.mixins import LoginRequiredMixin
from django.contrib.auth.views import LoginView as DjangoLoginView
from django.http import HttpResponse
from django.shortcuts import render, redirect, get_object_or_404
from django.views import View

from .email import send_verification_email
from .forms import RegistrationForm, LoginForm, ProfileEditForm, APIKeyNameForm
from .models import APIKey

User = get_user_model()
logger = logging.getLogger(__name__)


class RegisterView(View):
    template_name = 'accounts/register.html'

    def get(self, request):
        if request.user.is_authenticated:
            return redirect('catalog:collection')
        return render(request, self.template_name, {'form': RegistrationForm()})

    def post(self, request):
        if request.user.is_authenticated:
            return redirect('catalog:collection')
        form = RegistrationForm(request.POST)
        if form.is_valid():
            user = form.save()
            token = user.generate_verification_token()
            try:
                send_verification_email(request, user, token)
            except Exception:
                logger.exception('Failed to send verification email to %s', user.email)
            request.session['pending_verification_email'] = user.email
            return redirect('accounts:verification_sent')
        return render(request, self.template_name, {'form': form})


class VerificationSentView(View):
    template_name = 'accounts/verification_sent.html'

    def get(self, request):
        email = request.session.get('pending_verification_email', '')
        return render(request, self.template_name, {'email': email})


class VerifyEmailView(View):
    template_name = 'accounts/verify_email.html'

    def get(self, request, token):
        try:
            user = User.objects.get(verification_token=token, is_active=False)
        except User.DoesNotExist:
            return render(request, self.template_name, {'valid': False})

        user.email_verified = True
        user.is_active = True
        user.verification_token = ''
        user.save(update_fields=['email_verified', 'is_active', 'verification_token'])

        request.session.pop('pending_verification_email', None)
        login(request, user, backend='django.contrib.auth.backends.ModelBackend')
        messages.success(request, 'Your email has been verified. Welcome to Board Game Catalog!')
        return redirect('catalog:collection')


class CustomLoginView(DjangoLoginView):
    form_class = LoginForm
    template_name = 'accounts/login.html'

    def get(self, request, *args, **kwargs):
        if request.user.is_authenticated:
            return redirect('catalog:collection')
        return super().get(request, *args, **kwargs)

    def form_invalid(self, form):
        # Give a helpful message if the account exists but isn't verified yet
        username = form.data.get('username', '')
        try:
            unverified = User.objects.get(
                username=username, is_active=False, email_verified=False
            )
            messages.warning(
                self.request,
                f'Please verify your email before logging in. '
                f'Check your inbox at {unverified.email}.',
            )
        except User.DoesNotExist:
            pass
        return super().form_invalid(form)


class ProfileView(LoginRequiredMixin, View):
    login_url = '/accounts/login/'
    template_name = 'accounts/profile.html'

    def get(self, request):
        form = ProfileEditForm(instance=request.user)
        return render(request, self.template_name, {'form': form})

    def post(self, request):
        form = ProfileEditForm(request.POST, instance=request.user)
        if form.is_valid():
            form.save()
            messages.success(request, 'Profile updated.')
            return redirect('accounts:profile')
        return render(request, self.template_name, {'form': form})


class APIKeyListView(LoginRequiredMixin, View):
    login_url = '/accounts/login/'
    template_name = 'accounts/api_keys.html'

    def get(self, request):
        api_keys = APIKey.objects.filter(user=request.user, is_active=True)
        # The newly generated key is passed once through the session so it can
        # be shown to the user immediately after creation.
        new_key = request.session.pop('new_api_key', None)
        return render(request, self.template_name, {
            'api_keys': api_keys,
            'new_key': new_key,
            'name_form': APIKeyNameForm(),
        })


class GenerateAPIKeyView(LoginRequiredMixin, View):
    login_url = '/accounts/login/'

    def post(self, request):
        form = APIKeyNameForm(request.POST)
        if form.is_valid():
            name = form.cleaned_data.get('name', '').strip()
            api_key = APIKey.generate(user=request.user, name=name)
            # Store in session so it can be displayed once on the list page
            request.session['new_api_key'] = api_key.key
            messages.success(
                request,
                'API key generated. Copy it now — it will only be shown once in full.',
            )
        return redirect('accounts:api_keys')


class RevokeAPIKeyView(LoginRequiredMixin, View):
    login_url = '/accounts/login/'

    def post(self, request, key_id):
        api_key = get_object_or_404(APIKey, id=key_id, user=request.user)
        api_key.is_active = False
        api_key.save(update_fields=['is_active'])
        messages.success(
            request,
            f'API key "{api_key.name or "Unnamed"}" has been revoked.',
        )
        return redirect('accounts:api_keys')
