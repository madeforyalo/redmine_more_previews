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

  def plugin_settings
    @plugin_settings ||= ::Setting['plugin_redmine_more_previews'].to_h
  end

  def libreoffice_bin
    plugin_settings['lo_bin'].presence || '/usr/lib/libreoffice/program/soffice'
  end

  def profile_path
    plugin_settings['lo_profile'].presence || '/tmp/libreoffice_profile'
  end

  def lo_env
    {
      'HOME'            => plugin_settings['home_override'].presence || '/var/www',
      'PATH'            => plugin_settings['path_override'].presence || '/usr/bin:/bin',
      'TMPDIR'          => plugin_settings['tmpdir'].presence || '/tmp',
      'XDG_RUNTIME_DIR' => plugin_settings['xdg_runtime'].presence || '/tmp',
      'LANG'            => 'en_US.UTF-8'
    }
  end

  def lo_timeout
    (plugin_settings['convert_timeout'] || 60).to_i
  end

  def pdf_density
    (plugin_settings['pdf_density'] || 150).to_i
  end

  def pdf_tool
    plugin_settings['pdf_tool'].presence || 'pdftoppm'
  end

  #---------------------------------------------------------------------------------
  # check: is LibreOffice available?
  #---------------------------------------------------------------------------------
  def status
    _stdout, _stderr, status = Open3.capture3(lo_env, libreoffice_bin, '--version')
    [:text_libre_office_available, status.success?]
  rescue Errno::ENOENT
    [:text_libre_office_available, false]
  end

  def convert
    FileUtils.mkdir_p(profile_path)
    profile = "file://#{profile_path}"

    lo_format = preview_format
    if %w[png jpg].include?(preview_format)
      lo_format = 'pdf'
    end

    cmd = [
      libreoffice_bin, '--headless',
      "-env:UserInstallation=#{profile}",
      '--convert-to', lo_format,
      source,
      '--outdir', tmpdir
    ]

    stdout_str = stderr_str = ''
    status = nil
    Open3.popen3(lo_env, *cmd) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      if wait_thr.join(lo_timeout).nil?
        Process.kill('KILL', wait_thr.pid) rescue nil
        stdout_str = stdout.read
        stderr_str = stderr.read
        Rails.logger.error("[redmine_more_previews][LO] exit=timeout cmd='#{cmd.join(' ')}' stdout='#{stdout_str}' stderr='#{stderr_str}'")
        raise "LibreOffice conversion failed (timeout)"
      else
        stdout_str = stdout.read
        stderr_str = stderr.read
        status = wait_thr.value
      end
    end
    unless status&.success?
      Rails.logger.error("[redmine_more_previews][LO] exit=#{status&.exitstatus} cmd='#{cmd.join(' ')}' stdout='#{stdout_str}' stderr='#{stderr_str}'")
      raise "LibreOffice conversion failed (exit #{status&.exitstatus})"
    end

    if %w[png jpg].include?(preview_format)
      base = File.basename(source, File.extname(source))
      pdf_file = File.join(tmpdir, "#{base}.pdf")
      out_file = File.join(tmpdir, outfile)
      tool = pdf_tool
      if tool == 'pdftoppm'
        tool_path = `which pdftoppm 2>/dev/null`.strip
        tool = 'convert' if tool_path.empty?
      end
      if tool == 'pdftoppm'
        cmd2 = [
          'pdftoppm',
          "-#{preview_format == 'jpg' ? 'jpeg' : 'png'}",
          '-singlefile',
          '-r', pdf_density.to_s,
          pdf_file,
          File.join(tmpdir, base)
        ]
        stdout_str, stderr_str, status = Open3.capture3(lo_env, *cmd2)
      else
        cmd2 = [
          'convert',
          '-density', pdf_density.to_s,
          "#{pdf_file}[0]",
          out_file
        ]
        stdout_str, stderr_str, status = Open3.capture3(lo_env, *cmd2)
      end
      unless status.success?
        Rails.logger.error("[redmine_more_previews][PDF] exit=#{status.exitstatus} cmd='#{cmd2.join(' ')}' stdout='#{stdout_str}' stderr='#{stderr_str}'")
        raise "PDF to image conversion failed (exit #{status.exitstatus})"
      end
    end

    FileUtils.mv(File.join(tmpdir, outfile), tmptarget)
  end #def

end #class
