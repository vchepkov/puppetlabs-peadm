# @api private
#
# Deploy a code environment, retrying on failure.
#
# The peadm::code_manager task invokes r10k, which fetches code from the r10k
# remote. That fetch can fail transiently when the git host is briefly
# unreachable, so retry a few times before giving up.
#
# Note this deliberately does not use "puppet code deploy", which exits 0 even
# when the deploy fails and therefore cannot be retried on.
#
# @param targets
#   The primary host, where code manager runs.
# @param environment
#   The code environment to deploy.
# @param max_attempts
#   How many times to attempt the deploy before failing the plan.
# @param retry_interval
#   How long to wait, in seconds, between attempts.
plan peadm::util::deploy_environment (
  Peadm::SingleTargetSpec $targets,
  String[1]               $environment,
  Integer[1]              $max_attempts   = 3,
  Integer[0]              $retry_interval = 30,
) {
  $result = range(1, $max_attempts).reduce(undef) |$memo, $attempt| {
    if $memo =~ NotUndef and $memo.ok {
      $memo
    } else {
      if $attempt > 1 {
        out::message("Deploy of environment ${environment} failed; retrying (attempt ${attempt}) after ${retry_interval}s...")
        ctrl::sleep($retry_interval)
      }
      run_task('peadm::code_manager', $targets,
        _catch_errors => true,
        action        => "deploy ${environment}",
      )
    }
  }

  unless $result.ok {
    fail_plan("Failed to deploy environment ${environment} after ${max_attempts} attempts: ${$result.first.error.message}")
  }

  return $result
}
