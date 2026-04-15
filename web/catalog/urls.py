from django.urls import path

from . import views

app_name = 'catalog'

urlpatterns = [
    # Collection
    path('', views.CollectionView.as_view(), name='collection'),
    path('dismiss-banner/', views.DismissBannerView.as_view(), name='dismiss_banner'),
    path('sync-bgg/', views.SyncBGGView.as_view(), name='sync_bgg'),
    # Game Lists (REQ-GL-020 through REQ-GL-026)
    path('lists/', views.ManageListsView.as_view(), name='lists'),
    path('lists/<int:list_id>/', views.ListDetailView.as_view(), name='list_detail'),
    path('lists/<int:list_id>/update/', views.UpdateListView.as_view(), name='list_update'),
    path('lists/<int:list_id>/delete/', views.DeleteListView.as_view(), name='list_delete'),
    path('lists/<int:list_id>/add/', views.AddToListView.as_view(), name='list_add_game'),
    path('lists/<int:list_id>/entries/<int:entry_id>/remove/', views.RemoveFromListView.as_view(), name='list_remove_entry'),
    path('lists/<int:list_id>/entries/<int:entry_id>/note/', views.UpdateEntryNoteView.as_view(), name='list_update_note'),
]
