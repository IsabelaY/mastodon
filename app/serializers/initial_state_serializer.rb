# frozen_string_literal: true

class InitialStateSerializer < ActiveModel::Serializer
  include RoutingHelper

  attributes :meta, :compose, :accounts,
             :media_attachments, :settings,
             :max_toot_chars, :languages

  attribute :critical_updates_pending, if: -> { object&.role&.can?(:view_devops) && SoftwareUpdate.check_enabled? }

  has_one :push_subscription, serializer: REST::WebPushSubscriptionSerializer
  has_one :role, serializer: REST::RoleSerializer

  def max_toot_chars
    StatusLengthValidator::MAX_CHARS
  end

  def meta
    store = {
      streaming_api_base_url: Rails.configuration.x.streaming_api_base_url,
      access_token: object.token,
      locale: I18n.locale,
      domain: Addressable::IDNA.to_unicode(instance_presenter.domain),
      title: instance_presenter.title,
      admin: object.admin&.id&.to_s,
      search_enabled: Chewy.enabled?,
      repository: Mastodon::Version.repository,
      source_url: instance_presenter.source_url,
      version: instance_presenter.version,
      limited_federation_mode: Rails.configuration.x.limited_federation_mode,
      mascot: instance_presenter.mascot&.file&.url,
      profile_directory: Setting.profile_directory,
      trends_enabled: Setting.trends,
      registrations_open: Setting.registrations_mode != 'none' && !Rails.configuration.x.single_user_mode,
      timeline_preview: Setting.timeline_preview,
      activity_api_enabled: Setting.activity_api_enabled,
      single_user_mode: Rails.configuration.x.single_user_mode,
      trends_as_landing_page: Setting.trends_as_landing_page,
      status_page_url: Setting.status_page_url,
      sso_redirect: sso_redirect,
    }

    if object.current_account
      store[:me]                = object.current_account.id.to_s
      store[:unfollow_modal]    = object.current_account.user.setting_unfollow_modal
      store[:boost_modal]       = object.current_account.user.setting_boost_modal
      store[:delete_modal]      = object.current_account.user.setting_delete_modal
      store[:auto_play_gif]     = object.current_account.user.setting_auto_play_gif
      store[:expand_usernames]  = object.current_account.user.setting_expand_usernames
      store[:emoji_size_simple] = object.current_account.user.setting_emoji_size_simple
      store[:emoji_size_detailed] = object.current_account.user.setting_emoji_size_detailed
      store[:emoji_size_name] = object.current_account.user.setting_emoji_size_name
      store[:display_media]     = object.current_account.user.setting_display_media
      store[:expand_spoilers]   = object.current_account.user.setting_expand_spoilers
      store[:reduce_motion]     = object.current_account.user.setting_reduce_motion
      store[:disable_swiping]   = object.current_account.user.setting_disable_swiping
      store[:advanced_layout]   = object.current_account.user.setting_advanced_layout
      store[:use_blurhash]      = object.current_account.user.setting_use_blurhash
      store[:show_cw_box]       = object.current_account.user.setting_show_cw_box
      store[:use_pending_items] = object.current_account.user.setting_use_pending_items
      store[:show_trends]       = Setting.trends && object.current_account.user.setting_trends
    else
      store[:auto_play_gif] = Setting.auto_play_gif
      store[:display_media] = Setting.display_media
      store[:reduce_motion] = Setting.reduce_motion
      store[:use_blurhash]  = Setting.use_blurhash
    end

    store[:disabled_account_id] = object.disabled_account.id.to_s if object.disabled_account
    store[:moved_to_account_id] = object.moved_to_account.id.to_s if object.moved_to_account

    store[:owner] = object.owner&.id&.to_s if Rails.configuration.x.single_user_mode

    store
  end

  def compose
    store = {}

    if object.current_account
      store[:me]                 = object.current_account.id.to_s
      store[:default_privacy]    = object.visibility || object.current_account.user.setting_default_privacy
      store[:default_sensitive]  = object.current_account.user.setting_default_sensitive
      store[:default_federation] = object.current_account.user.setting_default_federation
      store[:default_language]   = object.current_account.user.preferred_posting_language
    end

    store[:text] = object.text if object.text

    store
  end

  def accounts
    store = {}

    ActiveRecord::Associations::Preloader.new(
      records: [object.current_account, object.admin, object.owner, object.disabled_account, object.moved_to_account].compact,
      associations: [:account_stat, { user: :role, moved_to_account: [:account_stat, { user: :role }] }]
    ).call

    store[object.current_account.id.to_s]  = ActiveModelSerializers::SerializableResource.new(object.current_account, serializer: REST::AccountSerializer) if object.current_account
    store[object.admin.id.to_s]            = ActiveModelSerializers::SerializableResource.new(object.admin, serializer: REST::AccountSerializer) if object.admin
    store[object.owner.id.to_s]            = ActiveModelSerializers::SerializableResource.new(object.owner, serializer: REST::AccountSerializer) if object.owner
    store[object.disabled_account.id.to_s] = ActiveModelSerializers::SerializableResource.new(object.disabled_account, serializer: REST::AccountSerializer) if object.disabled_account
    store[object.moved_to_account.id.to_s] = ActiveModelSerializers::SerializableResource.new(object.moved_to_account, serializer: REST::AccountSerializer) if object.moved_to_account

    store
  end

  def media_attachments
    { accept_content_types: MediaAttachment.supported_file_extensions + MediaAttachment.supported_mime_types }
  end

  def languages
    LanguagesHelper::SUPPORTED_LOCALES.map { |(key, value)| [key, value[0], value[1]] }
  end

  private

  def instance_presenter
    @instance_presenter ||= InstancePresenter.new
  end

  def sso_redirect
    "/auth/auth/#{Devise.omniauth_providers[0]}" if ENV['ONE_CLICK_SSO_LOGIN'] == 'true' && ENV['OMNIAUTH_ONLY'] == 'true' && Devise.omniauth_providers.length == 1
  end
end
