# frozen_string_literal: true

require 'open3'
require 'fileutils'
namespace :redmine_more_previews do
  desc 'Diagnose redmine_more_previews environment'
  task :diagnose => :environment do
    settings = Setting.plugin_redmine_more_previews
    puts "Redmine version: #{Redmine::VERSION.to_s}"
    puts "Ruby version: #{RUBY_VERSION}"
    env = {
      'HOME'            => settings['home_override'] || '/var/www',
      'PATH'            => settings['path_override'] || '/usr/bin:/bin',
      'TMPDIR'          => settings['tmpdir'] || '/tmp',
      'XDG_RUNTIME_DIR' => settings['xdg_runtime'] || '/tmp',
      'LANG'            => 'en_US.UTF-8'
    }
    soffice = settings['lo_bin'] || '/usr/lib/libreoffice/program/soffice'
    begin
      stdout, stderr, status = Open3.capture3(env, soffice, '--version')
      puts "soffice: #{status.success? ? stdout.strip : stderr.strip}"
    rescue => e
      puts "soffice: error (#{e.message})"
    end
    %w[pdftoppm convert].each do |bin|
      path = `which #{bin} 2>/dev/null`.strip
      puts "#{bin}: #{path.empty? ? 'not found' : path}"
    end
    profile = settings['lo_profile'] || '/tmp/libreoffice_profile'
    exist = File.directory?(profile)
    writable = begin
      FileUtils.mkdir_p(profile)
      File.writable?(profile)
    rescue
      false
    end
    puts "UserInstallation dir: #{profile} (exists=#{exist} writable=#{writable})"
  end
end

