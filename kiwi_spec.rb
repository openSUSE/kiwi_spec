begin
  require './bundle/bundler/setup.rb'
rescue LoadError
  STDERR.puts "run 'bundle install --standalone'"
  Kernel.exit 1
end

require 'yaml'
require './rstuk'

config = YAML::load File.read('./cfg/kiwi.yml')

SERVER = config['server']
PORT = config['port']

describe "Build image" do
  context "Build preparation" do
    dirname = "/tmp/kiwi-#{Time.now.strftime("%Y-%m-%d-%H--%M--%S")}"
    arch = Shell.remote SERVER, 22, "uname -p"
    arch = arch.chomp
    linux32 = ''
    if ['i386', 'i586', 'i686'].include?(arch)
      repoarch = 'i386'
      linux32 = 'linux32'
    elsif arch == 'x86_64'
      repoarch = arch
    end
    config_xml = File.read './cfg/config.xml.template'
    File.open('./config.xml', 'w') {|file| file.puts config_xml.gsub('#{arch}', repoarch)}
    Shell.remote SERVER, PORT, "mkdir #{dirname}"
    Shell.scp "./config.xml", SERVER, PORT, "#{dirname}/config.xml"
    Shell.scp "./root", SERVER, PORT, dirname
    image_type_to_test= ['oem', 'vmx', 'xen', 'pxe']
    lvm_capable = ['oem', 'vmx']
    image_type_to_test.each do |type|
      it "Building #{type}", build:true do
        if type == 'xen' 
          flavour = 'xenFlavour'
          build_type = 'vmx'
        else
          flavour = 'vmxFlavour'
          build_type = type
        end
        build_command = "cd #{dirname} && #{linux32} /usr/sbin/kiwi -b . --type #{build_type} --add-profile #{flavour} --logfile test#{type}.log -y"
        Shell.remote SERVER, PORT, "#{build_command} -d test#{type}build"
        if lvm_capable.include? type
          puts 'Building LVM enabled version...'
          Shell.remote SERVER, PORT, "#{build_command}  -d test#{type}buildlvm --lvm"
        end
      end
      to_testdrive = ['oem', 'vmx']
      if to_testdrive.include? type 
        it "Testdrive #{type}, reboot, check if it survived", testdrive:true do
          if type == 'vmx'
            image_extension = 'vmdk'
          elsif type == 'oem'
            image_extension = 'raw'
            Shell.remote SERVER, PORT, "qemu-img create -b #{dirname}/test#{type}build/LimeJeOS-SLES11SP2.#{arch}-1.12.1.#{image_extension} #{dirname}/test#{type}build/LimeJeOS-SLES11SP2.#{arch}-1.12.1.qcow2 20G -f qcow2"
            image_extension = 'qcow2'
          end
          image_file = "#{dirname}/test#{type}build/LimeJeOS-SLES11SP2.#{arch}-1.12.1.#{image_extension}"
          Shell.remote SERVER, PORT, "screen -S 'test#{type}' -d -m qemu-kvm -vnc :19 -drive file=#{image_file},boot=on,if=virtio -net nic -net user,hostfwd=tcp::5555-:22"
          sleep 90
          ssh_to_appliance = "ssh  -o \"UserKnownHostsFile /dev/null\" -q -o StrictHostKeyChecking=no root@#{config['server']} -p 5555"
          actual_result = Shell.remote(SERVER, 5555, "zypper products")[/\n(.*)\n$/,1]
          expected_result = "i | @System    | SUSE_SLES     | SUSE Linux Enterprise Server 11 SP2 | 11.2-1.234 | #{arch} | No     " #fix to yes, clarify baseproduct abscense
          actual_result.should == expected_result
          #check for mtab / proc/mounts sync, https://bugzilla.novell.com/show_bug.cgi?id=755915#c57 
          Shell.remote SERVER, 5555, "diff /etc/mtab /proc/mounts"
          #touch /dev/shm to check later if appliance was actually rebooted
          Shell.remote SERVER, 5555, "touch /dev/shm/kiwitest"
          Shell.remote SERVER, 5555, "reboot"
          sleep 60
          Shell.remote SERVER, 5555, "test -f /dev/shm/kiwitest", 1
          actual_result = Shell.remote(SERVER, 5555, "zypper products")[/\n(.*)\n$/,1]
          actual_result.should == expected_result
          Shell.remote SERVER, PORT, "screen -S test#{type} -X quit"
        end
      end
    end
  end
end
