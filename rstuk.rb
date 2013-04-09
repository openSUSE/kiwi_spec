require 'open3'

class Shell

  def self.remote server, port, cmd, expected_exit_status = 0
    # We want to avoid host key interactive accept question
    # And avoid test failures due to non English Locale
    puts "ssh: #{cmd}"
    self.do \
      "ssh root@#{server}  -o 'UserKnownHostsFile /dev/null' -o StrictHostKeyChecking=no -p #{port} \"#{cmd}\"",
      expected_exit_status
  end

  def self.local cmd, expected_exit_status = 0
    puts "local: #{cmd}"
    self.do cmd, expected_exit_status
  end

  def self.scp source, server, port, dest
    puts "scp: #{source} root@#{server}:#{dest}"
    self.do "scp -r -P #{port} #{source} root@#{server}:#{dest}", 0
  end

private

  def self.do cmd, expected_exit_status
    self.verify \
      expected_exit_status,
      *(Open3.capture3 "LANG=C; #{cmd}")
  end

  def self.verify expected_exit_status, stdout, stderr, status
    unless status.exitstatus == expected_exit_status
      fail "Exit status: %d Stdout: %s Stderr: %s" % [
        status.exitstatus,
        stdout,
        stderr
      ]
    end
    stdout
  end

end
