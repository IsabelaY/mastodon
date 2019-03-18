# frozen_string_literal: true

module HasUserSettings
  extend ActiveSupport::Concern

  included do
    serialize :settings, UserSettingsSerializer
  end

  def settings_attributes=(attributes)
    settings.update(attributes)
  end

  def prefers_noindex?
    settings['noindex']
  end

  def preferred_posting_language
    valid_locale_cascade(settings['default_language'], locale, I18n.locale)
  end

  def setting_auto_play_gif
    settings['web.auto_play']
  end

  def setting_default_sensitive
    settings['default_sensitive']
  end

  def setting_unfollow_modal
    settings['web.unfollow_modal']
  end

  def setting_boost_modal
    settings['web.reblog_modal']
  end

  def setting_delete_modal
    settings['web.delete_modal']
  end

  def setting_reduce_motion
    settings['web.reduce_motion']
  end

  def setting_system_font_ui
    settings['web.use_system_font']
  end

  def setting_noindex
    settings['noindex']
  end

  def setting_theme
    settings['theme']
  end

  def setting_display_media
    settings['web.display_media']
  end

  def setting_expand_spoilers
    settings['web.expand_content_warnings']
  end

  def setting_default_language
    settings['default_language']
  end

  def setting_aggregate_reblogs
    settings['aggregate_reblogs']
  end

  def setting_show_application
    settings['show_application']
  end

  def setting_advanced_layout
    settings['web.advanced_layout']
  end

  def setting_use_blurhash
    settings['web.use_blurhash']
  end

  def setting_use_pending_items
    settings['web.use_pending_items']
  end

  def setting_trends
    settings['web.trends']
  end

  def setting_disable_swiping
    settings['web.disable_swiping']
  end

  def setting_always_send_emails
    settings['always_send_emails']
  end

  def setting_default_privacy
    settings['default_privacy'] || (account.locked? ? 'private' : 'public')
  end

  def allows_report_emails?
    settings['notification_emails.report']
  end

  def allows_pending_account_emails?
    settings['notification_emails.pending_account']
  end

  def allows_appeal_emails?
    settings['notification_emails.appeal']
  end

  def allows_trends_review_emails?
    settings['notification_emails.trends']
  end

  def aggregates_reblogs?
    settings['aggregate_reblogs']
  end

  def shows_application?
    settings['show_application']
  end

  def show_all_media?
    settings['web.display_media'] == 'show_all'
  end

  def hide_all_media?
    settings['web.display_media'] == 'hide_all'
  end

  ## --- Hometown-specific settings from here on ---
  def setting_expand_usernames
    settings['web.expand_usernames']
  end

  def setting_default_federation
    settings['default_federation']
  end

  def setting_norss
    settings['norss']
  end

  def clamp_emoji_size(emoji_size)
    return 1 if emoji_size <= 0
    return 50 if emoji_size >= 50
    return emoji_size
  end

  def setting_emoji_size_simple
    clamp_emoji_size(settings['web.emoji_size_simple'].to_i)
  end

  def setting_emoji_size_detailed
    clamp_emoji_size(settings['web.emoji_size_detailed'].to_i)
  end

  def setting_emoji_size_name
    clamp_emoji_size(settings['web.emoji_size_name'].to_i)
  end

  def setting_bbcode_spin
    settings['web.bbcode_spin']
  end

  def setting_bbcode_pulse
    settings['web.bbcode_pulse']
  end

  def setting_bbcode_flip
    settings['web.bbcode_flip']
  end

  def setting_bbcode_color
    settings['web.bbcode_color']
  end

  def setting_bbcode_large
    settings['web.bbcode_large']
  end

  def setting_bbcode_size
    settings['web.bbcode_size']
  end

  def setting_bbcode_b
    settings['web.bbcode_b']
  end

  def setting_bbcode_i
    settings['web.bbcode_i']
  end

  def setting_bbcode_u
    settings['web.bbcode_u']
  end

  def setting_bbcode_s
    settings['web.bbcode_s']
  end
  
end
