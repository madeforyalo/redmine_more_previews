# encoding: utf-8
#
# RedmineMorePreviews converter to preview office files with LibreOffice
#
# Copyright © 2020 Stephan Wenzel <stephan.wenzel@drwpatent.de>
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
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

    profile = "file://#{PROFILE_PATH}"
    cmd = [
      LIBRE_OFFICE_BIN, '--headless',
      "-env:UserInstallation=#{profile}",
      '--convert-to', preview_format,
      source,
      '--outdir', tmpdir
    ]

    stdout_str, stderr_str, status = Open3.capture3(LO_ENV, *cmd)
    unless status.success?
      Rails.logger.error("[redmine_more_previews][LibreOffice] exit=#{status.exitstatus} cmd=#{cmd.join(' ')} stdout=#{stdout_str} stderr=#{stderr_str}")
      raise "LibreOffice conversion failed (exit #{status.exitstatus})"
    end

    FileUtils.mv(File.join(tmpdir, outfile), tmptarget)
  end #def

end #class
