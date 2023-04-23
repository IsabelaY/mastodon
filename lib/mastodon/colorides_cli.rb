require_relative '../../config/boot'
require_relative '../../config/environment'
require_relative 'cli_helper'

module Mastodon
  class ColoridesCLI < Thor
    include CLIHelper

    def self.exit_on_failure?
      true
    end

    option :concurrency, type: :numeric, default: 5, aliases: [:c]
    option :dry_run, type: :boolean
    option :date, type: :string, required: true
    desc 'delete-old-accounts', 'Remove accounts that are older than the given date'
    long_desc <<-LONG_DESC
      Remove accounts that are older than the given date
    LONG_DESC
    def delete_old_accounts()
      dry_run = options[:dry_run] ? ' (DRY RUN)' : ''
      del_date = options[:date].to_time
      query = Account.local.joins(:user).where('users.current_sign_in_at < ?', del_date)

      processed, culled = parallelize_with_progress(query.partitioned) do |account|
        next if account.statuses_count >= 10

        say("ID: #{account.id}, Username: #{account.username}, Status count: #{account.statuses_count}, Current sign in: #{account.user_current_sign_in_at}")
        DeleteAccountService.new.call(account, reserve_username: false) unless options[:dry_run]

        1
      end

      say("Visited #{processed} accounts, removed #{culled}#{dry_run}", :green)
    end
  end
end