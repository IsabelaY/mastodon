# frozen_string_literal: true

class TextFormatter
  include ActionView::Helpers::TextHelper
  include ERB::Util
  include RoutingHelper

  URL_PREFIX_REGEX = %r{\A(https?://(www\.)?|xmpp:)}

  DEFAULT_REL = %w(nofollow noopener noreferrer).freeze

  DEFAULT_OPTIONS = {
    multiline: true,
  }.freeze

  attr_reader :text, :options

  # @param [String] text
  # @param [Hash] options
  # @option options [Boolean] :multiline
  # @option options [Boolean] :with_domains
  # @option options [Boolean] :with_rel_me
  # @option options [Array<Account>] :preloaded_accounts
  def initialize(text, options = {})
    @text    = text
    @options = DEFAULT_OPTIONS.merge(options)
  end

  def entities
    @entities ||= Extractor.extract_entities_with_indices(text, extract_url_without_protocol: false)
  end

  def to_s
    return ''.html_safe if text.blank?

    html = rewrite do |entity|
      if entity[:url]
        link_to_url(entity)
      elsif entity[:hashtag]
        link_to_hashtag(entity)
      elsif entity[:screen_name]
        link_to_mention(entity)
      end
    end

    html = simple_format(html, {}, sanitize: false).delete("\n") if multiline?
    html = format_bbcode(html)

    html.html_safe # rubocop:disable Rails/OutputSafety
  end

  class << self
    include ERB::Util

    def shortened_link(url, rel_me: false)
      url = Addressable::URI.parse(url).to_s
      rel = rel_me ? (DEFAULT_REL + %w(me)) : DEFAULT_REL

      prefix      = url.match(URL_PREFIX_REGEX).to_s
      display_url = url[prefix.length, 30]
      suffix      = url[prefix.length + 30..]
      cutoff      = url[prefix.length..].length > 30

      <<~HTML.squish.html_safe # rubocop:disable Rails/OutputSafety
        <a href="#{h(url)}" target="_blank" rel="#{rel.join(' ')}" translate="no"><span class="invisible">#{h(prefix)}</span><span class="#{cutoff ? 'ellipsis' : ''}">#{h(display_url)}</span><span class="invisible">#{h(suffix)}</span></a>
      HTML
    rescue Addressable::URI::InvalidURIError, IDN::Idna::IdnaError
      h(url)
    end
  end

  private

  def rewrite
    entities.sort_by! do |entity|
      entity[:indices].first
    end

    result = +''

    last_index = entities.reduce(0) do |index, entity|
      indices = entity[:indices]
      result << h(text[index...indices.first])
      result << yield(entity)
      indices.last
    end

    result << h(text[last_index..])

    result
  end

  def link_to_url(entity)
    start_i = entity[:indices].first
    end_i = entity[:indices].last

    if start_i >= 5 && text.length > end_i && text[start_i - 5, 5].downcase == "[url="
      return h(entity[:url])
    end

    TextFormatter.shortened_link(entity[:url], rel_me: with_rel_me?)
  end

  def link_to_hashtag(entity)
    hashtag = entity[:hashtag]
    url     = tag_url(hashtag)

    <<~HTML.squish
      <a href="#{h(url)}" class="mention hashtag" rel="tag">#<span>#{h(hashtag)}</span></a>
    HTML
  end

  def link_to_mention(entity)
    username, domain = entity[:screen_name].split('@')

    case domain
    when 'twitter.com'
      return link_to_twitter(username)
    when 'tumblr.com'
      return link_to_tumblr(username)
    when 'deviantart.com'
      return link_to_deviantart(username)
    when 'artstation.com'
      return link_to_artstation(username)
    when 'github.com'
      return link_to_github(username)
    when 'instagram.com'
      return link_to_instagram(username)
    end

    domain           = nil if local_domain?(domain)
    account          = nil

    if preloaded_accounts?
      same_username_hits = 0

      preloaded_accounts.each do |other_account|
        same_username = other_account.username.casecmp(username).zero?
        same_domain   = other_account.domain.nil? ? domain.nil? : other_account.domain.casecmp(domain)&.zero?

        if same_username && !same_domain
          same_username_hits += 1
        elsif same_username && same_domain
          account = other_account
        end
      end
    else
      account = entity_cache.mention(username, domain)
    end

    return "@#{h(entity[:screen_name])}" if account.nil?

    url = ActivityPub::TagManager.instance.url_for(account)
    display_username = same_username_hits&.positive? || with_domains? ? account.pretty_acct : account.username

    <<~HTML.squish
      <span class="h-card" translate="no"><a href="#{h(url)}" class="u-url mention">@<span>#{h(display_username)}</span></a></span>
    HTML
  end

  def link_to_twitter(username)
    "<span class=\"h-card\"><a href=\"https://twitter.com/#{username}\" target=\"blank\" rel=\"noopener noreferrer\" class=\"u-url mention\">@<span>#{username}@twitter.com</span></a></span>"
  end

  def link_to_tumblr(username)
    "<span class=\"h-card\"><a href=\"https://#{username}.tumblr.com\" target=\"blank\" rel=\"noopener noreferrer\" class=\"u-url mention\">@<span>#{username}@tumblr.com</span></a></span>"
  end

  def link_to_deviantart(username)
    "<span class=\"h-card\"><a href=\"https://#{username}.deviantart.com\" target=\"blank\" rel=\"noopener noreferrer\" class=\"u-url mention\">@<span>#{username}@deviantart.com</span></a></span>"
  end

  def link_to_artstation(username)
    "<span class=\"h-card\"><a href=\"https://www.artstation.com/#{username}\" target=\"blank\" rel=\"noopener noreferrer\" class=\"u-url mention\">@<span>#{username}@artstation.com</span></a></span>"
  end

  def link_to_github(username)
    "<span class=\"h-card\"><a href=\"https://github.com/#{username}\" target=\"blank\" rel=\"noopener noreferrer\" class=\"u-url mention\">@<span>#{username}@github.com</span></a></span>"
  end

  def link_to_instagram(username)
    "<span class=\"h-card\"><a href=\"https://www.instagram.com/#{username}\" target=\"blank\" rel=\"noopener noreferrer\" class=\"u-url mention\">@<span>#{username}@instagram.com</span></a></span>"
  end

  def entity_cache
    @entity_cache ||= EntityCache.instance
  end

  def tag_manager
    @tag_manager ||= TagManager.instance
  end

  delegate :local_domain?, to: :tag_manager

  def multiline?
    options[:multiline]
  end

  def with_domains?
    options[:with_domains]
  end

  def with_rel_me?
    options[:with_rel_me]
  end

  def preloaded_accounts
    options[:preloaded_accounts]
  end

  def preloaded_accounts?
    preloaded_accounts.present?
  end

  def format_bbcode(html)
    begin
      allowed_bbcodes = [:i, :b, :color, :quote, :code, :size, :u, :s, :spin, :pulse, :flip, :large, :colorhex, :url]
      html = html.bbcode_to_html(false, {
        :spin => {
          :html_open => '<span class="bbcode__spin">', :html_close => '</span>',
          :description => 'Make text spin',
          :example => 'This is [spin]spin[/spin].'},
        :pulse => {
          :html_open => '<span class="bbcode__pulse">', :html_close => '</span>',
          :description => 'Make text pulse',
          :example => 'This is [pulse]pulse[/pulse].'},
        :b => {
          :html_open => '<b>', :html_close => '</b>',
          :description => 'Make text bold',
          :example => 'This is [b]bold[/b].'},
        :i => {
          :html_open => '<i>', :html_close => '</i>',
          :description => 'Make text italic',
          :example => 'This is [i]italic[/i].'},
        :s => {
          :html_open => '<s>', :html_close => '</s>',
          :description => 'Make text with strike-through',
          :example => 'This is [s]strike-through[/s].'},
        :flip => {
          :html_open => '<span class="bbcode__flip-%direction%">', :html_close => '</span>',
          :description => 'Flip text',
          :example => '[flip=horizontal]This is flip[/flip]',
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /(horizontal|vertical)/,
          :quick_param_format_description => 'The size parameter \'%param%\' is incorrect, a number is expected',
          :param_tokens => [{:token => :direction}]},
        :large => {
          :html_open => '<span class="fa-%size%">', :html_close => '</span>',
          :description => 'Large text',
          :example => '[large=2x]Large text[/large]',
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /(2x|3x|4x|5x)/,
          :quick_param_format_description => 'The size parameter \'%param%\' is incorrect, a number is expected',
          :param_tokens => [{:token => :size}]},
        :colorhex => {
          :html_open => '<span class="bbcode__color" data-bbcodecolor="#%colorhex%;">', :html_close => '</span>',
          :description => 'Change the color of the text',
          :example => '[colorhex=ff0000]This is red[/colorhex]',
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /([0-9a-f]{6})/i,
          :param_tokens => [{:token => :colorhex}]},
        :color => {
          :html_open => '<span class="bbcode__color" data-bbcodecolor="%color%">', :html_close => '</span>',
          :description => 'Use color',
          :example => '[color=red]This is red[/color]',
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /([a-z]+)/i,
          :param_tokens => [{:token => :color}]},
        :size => {
          :html_open => '<span class="bbcode__size" data-bbcodesize="%size%px">', :html_close => '</span>',
          :description => 'Change the size of the text',
          :example => '[size=32]This is 32px[/size]',
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /(\d+)/,
          :quick_param_format_description => 'The size parameter \'%param%\' is incorrect, a number is expected',
          :param_tokens => [{:token => :size}]},
        :url => {
          :html_open => '<a target="_blank" rel="nofollow noopener" href="%url%">%between%', :html_close => '</a>',
          :description => 'Link to another page',
          :example => '[url=http://www.google.com/]link[/url].',
          :require_between => true,
          :allow_quick_param => true, :allow_between_as_param => false,
          :quick_param_format => /^((((http|https|ftp):\/\/)).+)$/,
          :param_tokens => [{:token => :url}],
          :quick_param_format_description => 'The URL should start with http:// https://, ftp://'},
      }, :enable, *allowed_bbcodes)
    rescue Exception => e
    end
    html
  end
end
