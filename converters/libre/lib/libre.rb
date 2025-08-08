# encoding: utf-8
#
# RedmineMorePreviews converter to preview office files with LibreOffice
#
# GPL v2 or later
#

require 'open3'
require 'fileutils'

class Libre < RedmineMorePreviews::Conversion
  # ---------------------------
  # Settings helpers
  # ---------------------------
  def plugin_settings
    @plugin_settings ||= (::Setting['plugin_redmine_more_previews'] || {}).to_h
  end

  def libreoffice_bin
    (plugin_settings['lo_bin'].presence || '/usr/lib/libreoffice/program/soffice').to_s
  end

  def profile_path
    (plugin_settings['lo_profile'].presence || '/tmp/libreoffice_profile').to_s
  end

  def lo_env
    {
      'HOME'            => (plugin_settings['home_override'].presence || '/var/www').to_s,
      'PATH'            => (plugin_settings['path_override'].presence || '/usr/bin:/bin').to_s,
      'TMPDIR'          => (plugin_settings['tmpdir'].presence || '/tmp').to_s,
      'XDG_RUNTIME_DIR' => (plugin_settings['xdg_runtime'].presence || '/tmp').to_s,
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
    (plugin_settings['pdf_tool'].presence || 'pdftoppm').to_s # 'pdftoppm' | 'convert'
  end

  # ---------------------------
  # Availability check
  # ---------------------------
  def status
    _stdout, _stderr, status = Open3.capture3(lo_env, libreoffice_bin, '--version')
    [:text_libre_office_available, status.success?]
  rescue Errno::ENOENT
    [:text_libre_office_available, false]
  end

  # ---------------------------
  # Convert
  # ---------------------------
  def convert
    FileUtils.mkdir_p(profile_path)

    # Si el preview esperado es imagen, primero generamos PDF y luego lo rasterizamos.
    lo_format = preview_format
    wants_image = %w[png jpg jpeg].include?(preview_format)
    lo_format = 'pdf' if wants_image

    profile_uri = "file://#{profile_path}"
    cmd = [
      libreoffice_bin, '--headless',
      "-env:UserInstallation=#{profile_uri}",
      '--convert-to', lo_format,
      source,
      '--outdir', tmpdir
    ]

    stdout_str = stderr_str = ''
    status = nil

    Open3.popen3(lo_env, *cmd) do |stdin, stdout, stderr, wait_thr|
      stdin.close
      if wait_thr.join(lo_timeout).nil?
        # timeout
        Process.kill('KILL', wait_thr.pid) rescue nil
        stdout_str = stdout.read rescue ''
        stderr_str = stderr.read rescue ''
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

    # Si queríamos imagen, rasterizamos la primera página del PDF.
    if wants_image
      base      = File.basename(source, File.extname(source))
      pdf_file  = File.join(tmpdir, "#{base}.pdf")
      out_file  = File.join(tmpdir, outfile)
      tool      = pdf_tool

      if tool == 'pdftoppm'
        tool_path = `which pdftoppm 2>/dev/null`.strip
        tool = 'convert' if tool_path.empty?
      end

      if tool == 'pdftoppm'
        # pdftoppm -png/-jpeg -singlefile -r <density> in.pdf out_base
        format_flag = (preview_format == 'jpg' || preview_format == 'jpeg') ? 'jpeg' : 'png'
        cmd2 = [
          'pdftoppm',
          "-#{format_flag}",
          '-singlefile',
          '-r', pdf_density.to_s,
          pdf_file,
          File.join(tmpdir, base)
        ]
      else
        # convert -density <density> in.pdf[0] out.png
        first_page = "#{pdf_file}[0]"
        cmd2 = [
          'convert',
          '-density', pdf_density.to_s,
          first_page,
          out_file
        ]
      end

      stdout2, stderr2, status2 = Open3.capture3(lo_env, *cmd2)
      unless status2.success?
        Rails.logger.error("[redmine_more_previews][PDF] exit=#{status2.exitstatus} cmd='#{cmd2.join(' ')}' stdout='#{stdout2}' stderr='#{stderr2}'")
        raise "PDF to image conversion failed (exit #{status2.exitstatus})"
      end
    end

    # Mover el resultado final a donde Redmine lo espera
    FileUtils.mv(File.join(tmpdir, outfile), tmptarget)
  end
end

