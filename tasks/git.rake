module GitCommands
  class ShellError < RuntimeError; end
 
  @logging = ENV['LOGGING'] != "false"
 
  def self.run cmd, *expected_exitstatuses
    puts "+ #{cmd}" if @logging
    output = `#{cmd} 2>&1`
    puts output.gsub(/^/, "- ") if @logging
    expected_exitstatuses << 0 if expected_exitstatuses.empty?
    raise ShellError.new("ERROR: '#{cmd}' failed with exit status #{$?.exitstatus}") unless
      [expected_exitstatuses].flatten.include?( $?.exitstatus )
    output
  end
 
  def self.current_branch
    run("git branch --no-color | grep '*' | cut -d ' ' -f 2").chomp
  end
 
  def self.remote_branch_exists?(branch)
    ! run("git branch -r --no-color | grep '#{branch}'").blank?
  end
 
  def self.ensure_clean_working_directory!
    return if run("git status", 0, 1).match(/working directory clean/)
    raise "Must have clean working directory"
  end
 
  def self.diff_staging
    puts run("git diff HEAD origin/staging")
  end
 
  def self.diff_production
    puts run("git diff origin/staging origin/production")
  end

  def self.push(src_branch, dst_branch)
    raise "origin/#{dst_branch} branch does not exist" unless remote_branch_exists?("origin/#{dst_branch}")
    ensure_clean_working_directory!
    begin
      run "git fetch"
      run "git push -f origin #{src_branch}:#{dst_branch}"
    rescue
      puts "Pushing #{src_branch} to origin/#{dst_branch} failed."
      raise
    end
  end
 
  def self.push_staging
    push(current_branch, "staging")
  end
 
  def self.push_production
    push("origin/staging", "production")
  end
 
  def self.branch(from_branch, to_branch)
    raise "You must specify a from branch name." if from_branch.blank?
    raise "You must specify a to branch name." if to_branch.blank?
    ensure_clean_working_directory!
    run "git fetch"
    run "git branch -f #{to_branch} #{from_branch}"
    run "git checkout #{to_branch}"
  end

  def self.push_and_merge(branch)
    raise "You must specify a branch name." if branch.blank?
    ensure_clean_working_directory!
    run "git checkout #{branch}"
    run "git push origin #{branch}"
    run "git checkout master"
    run "git merge #{branch}"
    run "git push origin master"
  end
 
  def self.pull_template
    ensure_clean_working_directory!
    run "git pull git://github.com/thoughtbot/suspenders.git master"
  end
end
 
namespace :git do
  namespace :push do
    desc "Reset origin's staging branch to be the current branch."
    task :staging do
      GitCommands.push_staging
    end
 
    desc "Reset origin's production branch to origin's staging branch."
    task :production do
      GitCommands.push_production
    end
  end
 
  namespace :diff do
    desc "Show the difference between current branch and origin/staging."
    task :staging do
      GitCommands.diff_staging
    end
 
    desc "Show the difference between origin/staging and origin/production."
    task :production do
      GitCommands.diff_production
    end
  end
 
  namespace :pull do
    desc "Pull updates from suspenders, the thoughtbot rails template."
    task :suspenders do
      GitCommands.pull_template
    end
  end
 
  namespace :branch do
    desc "Branch origin/production into BRANCH locally."
    task :production do
      branch = ENV['BRANCH'].blank? ? 'production' : ENV['BRANCH']
      GitCommands.branch('origin/production', branch)
    end

    desc "Branch origin/staging into BRANCH locally."
    task :staging do
      branch = ENV['BRANCH'].blank? ? 'staging' : ENV['BRANCH']
      GitCommands.branch('origin/staging', branch)
    end
  end

  namespace :merge do
    desc "Push changes from local production branch to origin/production and merge changes with master"
    task :production do
      GitCommands.push_and_merge('production')
    end

    desc "Push changes from local staging branch to origin/staging and merge changes with master"
    task :staging do
      GitCommands.push_and_merge('staging')
    end
  end
end
