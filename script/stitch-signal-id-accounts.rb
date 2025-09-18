#!/usr/bin/env ruby

#
#  this is intended to copy a production database into beta, change the account id, and stitch the
#  user accounts together properly.
#

require_relative "../config/environment"

ActiveRecord::Base.logger = Logger.new(File::NULL)

ApplicationRecord.with_each_tenant do |tenant|
  puts "\n# tenant: #{tenant}"

  signal_account = SignalId::Account.find_by!(queenbee_id: tenant)
  puts "Found signal account #{signal_account.inspect}"

  account = Account.sole
  if account.tenant_id != tenant
    puts "setting account tenant_id to #{tenant}"
    account.update!(tenant_id: tenant, name: account.name + " (Beta)")
  end

  User.find_each do |user|
    next if user.system? || user.external_user_id.nil?

    signal_user = user.external_user
    next if signal_user.nil?
    next if signal_user.account == account.external_account

    signal_identity = signal_user.identity
    pp signal_identity

    SignalId::Database.on_master do
      signal_user = SignalId::User.find_or_create_by!(identity: signal_identity, account: signal_account)
      puts "Created signal user #{signal_user.inspect} for identity #{signal_identity.inspect}"
      user.external_user_id = signal_user.id
      user.save!
    end
  end
end
