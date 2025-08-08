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
  
  #---------------------------------------------------------------------------------
  # check: is LibreOffice available?
  #---------------------------------------------------------------------------------
  def status
    s = run [LIBRE_OFFICE_BIN, "--version"]
    [:text_libre_office_available, s[2] == 0 ]
  end
  
  def convert
    FileUtils.mkdir_p('/tmp/libreoffice_profile')

    env = {
      'HOME' => '/var/www',
      'PATH' => '/usr/bin:/bin',
      'TMPDIR' => '/tmp',
      'XDG_RUNTIME_DIR' => '/tmp',
      'LANG' => 'en_US.UTF-8'
    }

    cmd = [
      LIBRE_OFFICE_BIN,
      '--headless',
      '--convert-to', preview_format,
      '--outdir', tmpdir,
      '-env:UserInstallation=file:///tmp/libreoffice_profile',
      source
    ]

    stdout, stderr, status = Open3.capture3(env, *cmd)

    unless status.success?
      Rails.logger.error("LibreOffice command failed: #{cmd.join(' ')}")
      Rails.logger.error("stdout: #{stdout}") unless stdout.to_s.empty?
      Rails.logger.error("stderr: #{stderr}") unless stderr.to_s.empty?
      raise ConverterShellError
    end

    FileUtils.mv(File.join(tmpdir, outfile), tmptarget)
  end #def
  
end #class
