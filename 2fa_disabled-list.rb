#!/usr/bin/env ruby

# ref: https://github.com/octokit/octokit.rb/blob/master/lib/octokit/client/organizations.rb
# finds github users in target orgs that have 2fa disabled
# passes rubocop interrogation (yay!)

require 'octokit'

organizations = %w[armadillo-field-testing] # will add other orgs later

begin
  # note: requires "owner" access privs, or chokes out with a 422 error
  ockokit_client = Octokit::Client.new(access_token: ENV['GITHUB_TOKEN'])
  ockokit_client.connection_options[:ssl] = { verify: true }
  ockokit_client.auto_paginate = true

  # iterate over orgs
  organizations.each do |github_org|
    puts "Checking org: #{github_org}"
    members = ockokit_client.org_members github_org, filter: '2fa_disabled'
    collabs = ockokit_client.outside_collaborators github_org, filter: '2fa_disabled'

    # iterate over members found
    members.each do |m|
      puts "  #{github_org} - user - #{m[:id]} - #{m[:login]}"
    end

    # iterate over collaborators found
    collabs.each do |m|
      puts "  #{github_org} - collaborator - #{m[:id]} - #{m[:login]}"
    end
  end
rescue Ockokit::Error => ockokit_e
  puts ockokit_e.errno
  puts ockokit_e.error
end

# end of script
