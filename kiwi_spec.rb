begin
  require './bundle/bundler/setup.rb'
rescue LoadError
  STDERR.puts "run 'bundle install --standalone'"
  Kernel.exit 1
end

require 'yaml'
require 'capybara/rspec'

config = YAML::load File.read(File.join('.', 'kiwi.yml'))

SSH = "ssh root@#{config['server']}"

feature "Build image" do
  context "Build preparation" do
    dirname = "/tmp/kiwi-#{Time.now.strftime("%Y-%m-%d-%H--%M--%S")}"
    arch = `#{SSH} uname -p`.chomp
#    dirname = '/tmp/kiwi-2012-06-24-13--05--46'
    linux32 = ''
    if ['i386', 'i586', 'i686'].include?(arch)
      repoarch = 'i386'
      linux32 = 'linux32'
    else
      repoarch = arch
    end
    config_xml = File.read(File.join('.', 'config.xml.template'))
    File.open(File.join('.', 'config.xml'), 'w') {|file| file.puts config_xml.gsub('#{arch}', repoarch)}
    `#{SSH} mkdir #{dirname}`
    `scp ./config.xml root@#{config['server']}:#{dirname}/config.xml`
    `scp -r ./root root@#{config['server']}:#{dirname}/`
    image_type_to_test= ['oem', 'vmx', 'xen', 'pxe']
    lvm_capable = ['oem', 'vmx']
    image_type_to_test.each do |type|
      scenario "Building #{type}", build:true do
        if type == 'xen' 
          flavour = 'xenFlavour'
          build_type = 'vmx'
        else
          flavour = 'vmxFlavour'
          build_type = type
        end
        build_command = "#{SSH} \"cd #{dirname} && #{linux32} /usr/sbin/kiwi -b . --type #{build_type} --add-profile #{flavour} --logfile test#{type}.log -y\""
        `#{build_command} -d test#{type}build`
        $?.exitstatus.should be == 0
        if lvm_capable.include? type
          puts 'Building LVM enabled version...'
          `#{build_command}  -d test#{type}buildlvm --lvm`
          $?.exitstatus.should be == 0
        end
      end
      to_testdrive = ['oem', 'vmx']
      if to_testdrive.include? type 
        scenario "Testdrive #{type}, reboot, check if it survived", testdrive:true do
          if type == 'vmx'
            image_extension = 'vmdk'
          elsif type == 'oem'
            image_extension = 'raw'
            `#{SSH} qemu-img create -b #{dirname}/test#{type}build/LimeJeOS-SLES11SP2.#{arch}-1.12.1.#{image_extension} #{dirname}/test#{type}build/LimeJeOS-SLES11SP2.#{arch}-1.12.1.qcow2 20G -f qcow2`
            image_extension = 'qcow2'
          end
          image_file = "#{dirname}/test#{type}build/LimeJeOS-SLES11SP2.#{arch}-1.12.1.#{image_extension}"
          puts `#{SSH} screen -S 'test#{type}' -d -m qemu-kvm -vnc :19 -drive file=#{image_file},boot=on,if=virtio -net nic -net user,hostfwd=tcp::5555-:22`
          $?.exitstatus.should be == 0
          sleep 90
          ssh_to_appliance = "ssh  -o \"UserKnownHostsFile /dev/null\" -q -o StrictHostKeyChecking=no root@#{config['server']} -p 5555"
          expected_result = "i | @System    | SUSE_SLES     | SUSE Linux Enterprise Server 11 SP2 | 11.2-1.234 | #{arch} | No     " #fix to yes, clarify baseproduct abscense
          `#{ssh_to_appliance} zypper products`[/\n(.*)\n$/,1].should == expected_result
          #check for mtab / proc/mounts sync, https://bugzilla.novell.com/show_bug.cgi?id=755915#c57 
          `#{ssh_to_appliance} diff /etc/mtab /proc/mounts`
          $?.exitstatus.should be == 0
          #touch /dev/shm to check later if appliance was actually rebooted
          `#{ssh_to_appliance} touch /dev/shm/kiwitest` 
          $?.exitstatus.should be == 0
          `#{ssh_to_appliance} reboot`
          sleep 60
          `#{ssh_to_appliance} test -f /dev/shm/kiwitest`
          $?.exitstatus.should be == 1
          `#{ssh_to_appliance} zypper products`[/\n(.*)\n$/,1].should == expected_result
          `#{SSH} screen -S test#{type} -X quit`
          $?.exitstatus.should be == 0
        end
      end
    end
  end
end
