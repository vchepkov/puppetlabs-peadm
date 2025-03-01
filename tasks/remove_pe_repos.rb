#!/opt/puppetlabs/puppet/bin/ruby
# frozen_string_literal: true

require 'json'
require 'net/http'
require 'puppet'
require_relative '../../ruby_task_helper/files/task_helper.rb'

class RemovePERepoPlatformClasses < TaskHelper
  def task(_params)
    Puppet.initialize_settings

    pe_master_group = groups.find { |obj| obj['name'] == 'PE Master' }

    unless pe_master_group
      raise TaskHelper::Error.new("PE Master group not found!", 'puppetlabs.classifier/not-found')
    end

    platform_classes = pe_master_group['classes'].keys.select { |key| key.start_with?('pe_repo::platform::') }

    return { status: 'success', message: 'No platform classes found.' } if platform_classes.empty?

    remove_classes!(pe_master_group['id'], platform_classes)

    {
      status: 'success',
      message: 'Removed platform classes successfully.',
      removed_classes: platform_classes
    }
  end

  def remove_classes!(group_id, classes)
    update_payload = {
      'classes' => classes.to_h { |class_name| [class_name, nil] }
    }

    response = update_group(group_id, update_payload)

    unless response.code.to_i == 200 || response.code.to_i == 201
      raise TaskHelper::Error.new("Failed to update the group. Response: #{response.code} - #{response.body}", 'puppetlabs.classifier/update-failed')
    end
  end

  def update_group(group_id, group_data)
    net = https(4433)
    request = Net::HTTP::Post.new("/classifier-api/v1/groups/#{group_id}", { 'Content-Type' => 'application/json' })
    request.body = group_data.to_json
    net.request(request)
  end

  def groups
    net = https(4433)
    res = net.get('/classifier-api/v1/groups')
    JSON.parse(res.body)
  end

  def https(port)
    https = Net::HTTP.new(Puppet.settings[:certname], port)
    https.use_ssl = true
    https.cert = OpenSSL::X509::Certificate.new(File.read(Puppet.settings[:hostcert]))
    https.key = OpenSSL::PKey::RSA.new(File.read(Puppet.settings[:hostprivkey]))
    https.verify_mode = OpenSSL::SSL::VERIFY_PEER
    https.ca_file = Puppet.settings[:localcacert]
    https
  end
end

RemovePERepoPlatformClasses.run if __FILE__ == $PROGRAM_NAME
