from django.conf import settings
from django.core.mail import send_mail
from django.urls import reverse


def send_verification_email(request, user, token):
    """Send an account verification email containing the activation link."""
    verify_path = reverse('accounts:verify_email', kwargs={'token': token})
    verify_url = f"{settings.SITE_URL}{verify_path}"

    subject = 'Verify your Board Game Catalog account'
    body = (
        f"Hi {user.username},\n\n"
        f"Thanks for registering! Please verify your email address by clicking the link below:\n\n"
        f"{verify_url}\n\n"
        f"If you didn't create this account you can safely ignore this email.\n\n"
        f"— Board Game Catalog"
    )

    send_mail(
        subject=subject,
        message=body,
        from_email=settings.DEFAULT_FROM_EMAIL,
        recipient_list=[user.email],
        fail_silently=False,
    )
