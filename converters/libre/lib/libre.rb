# encoding: utf-8
#
# RedmineMorePreviews converter to preview office files with LibreOffice
#
# Copyright © 2020 Stephan Wenzel <stephan.wenzel@drwpatent.de>
#
# GPL v2 or later
#

require 'open3'
require 'fileutils'

class Libre < RedmineMorePreviews::Conversion
  #---------------------------------------------------------------------------------
  # constants
  #---------------------------------------------------------------------------------
  LIBRE_OFFICE_BIN = '/usr/lib/libreoffice/program/soffice'.freeze
  PROFILE_PATH     = '/tmp/libreoffice_profile'.freeze

  LO_ENV = {
    'HOME'            => '/var/www',
    'PATH'            => '/usr/bin:/bin',
    'TMPDIR'          => '/tmp',
    'XDG_RUNTIME_DIR' => '/tmp',
    'LANG'            => 'en_US.UTF-8'
  }.freeze

  #---------------------------------------------------------------------------------
  # check: is LibreOffice available?
  #---------------------------------------------------------------------------------
  def status
    _stdout, _stderr, status = Open3.capture3(LO_ENV, LIBRE_OFFICE_BIN, '--version')
    [:text_libre_office_available, status.success?]
  rescue Errno::ENOENT
    [:text_libre_office_available, false]
  end

  def convert
    FileUtils.mkdir_p(PROFILE_PATH)

    profile = "file://#{PROFILE_PATH}" # => "file:///tmp/libreoffice_profile"
    cmd = [
      LIBRE_OFFICE_BIN, '--headless',
      "-env:UserInstallation=#{profile}",
      '--convert-to', preview_format,
      source,
      '--outdir', tmpdir
    ]

    stdout_str, stderr_str, status = Open3.capture3(LO_ENV, *cmd)
    unless status.success?
      Rails.logger.error(
        "[redmine_more_previews][LibreOffice] exit=#{status.exitstatus} " \
        "cmd=#{cmd.join(' ')} stdout=#{stdout_str} stderr=#{stderr_str}"
      )
      # Usa la excepción propia del plugin si existe; cae a RuntimeError si no.
      raise defined?(ConverterShellError) ? ConverterShellError : RuntimeError, "LibreOffice conversion failed"
    end

    FileUtils.mv(File.join(tmpdir, outfile), tmptarget)
  end
end
