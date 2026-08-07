require 'spec_helper'

describe 'peadm::util::deploy_environment' do
  include BoltSpec::Plans

  let(:params) { { 'targets' => 'primary', 'environment' => 'production' } }
  let(:no_wait) { params.merge('retry_interval' => 0) }
  let(:task_params) { { 'action' => 'deploy production', '_catch_errors' => true } }
  let(:network_error) { { 'kind' => 'puppetlabs.tasks/task-error', 'msg' => 'Network is unreachable' } }

  it 'deploys on the first attempt' do
    expect_task('peadm::code_manager')
      .with_targets('primary')
      .with_params(task_params)
      .be_called_times(1)

    expect(run_plan('peadm::util::deploy_environment', params)).to be_ok
  end

  it 'retries and succeeds on a later attempt' do
    allow_out_message

    attempt = 0
    expect_task('peadm::code_manager').with_params(task_params).be_called_times(3).return do |targets:, **_kwargs|
      attempt += 1
      results = targets.map do |target|
        if attempt < 3
          Bolt::Result.from_exception(target, Bolt::Error.new(network_error['msg'], network_error['kind']))
        else
          Bolt::Result.new(target, value: {})
        end
      end
      Bolt::ResultSet.new(results)
    end

    expect(run_plan('peadm::util::deploy_environment', no_wait)).to be_ok
  end

  it 'fails the plan when every attempt fails' do
    allow_out_message

    expect_task('peadm::code_manager')
      .with_params(task_params)
      .be_called_times(3)
      .error_with(network_error)

    result = run_plan('peadm::util::deploy_environment', no_wait)

    expect(result).not_to be_ok
    expect(result.value.msg).to match(%r{Failed to deploy environment production after 3 attempts})
    expect(result.value.msg).to match(%r{Network is unreachable})
  end

  it 'honours max_attempts' do
    allow_out_message

    expect_task('peadm::code_manager')
      .with_params(task_params)
      .be_called_times(5)
      .error_with(network_error)

    result = run_plan('peadm::util::deploy_environment', no_wait.merge('max_attempts' => 5))

    expect(result).not_to be_ok
    expect(result.value.msg).to match(%r{after 5 attempts})
  end
end
