begin
  require './bundle/bundler/setup.rb'
rescue LoadError
  STDERR.puts "run 'bundle install --standalone'"
  Kernel.exit 1
end

require 'yaml'
require 'rstuk'

config = YAML::load File.read('./cfg/kiwi.yml')

SERVER = config['server']
PORT = config['port']
TESTDIR = config['testdir']
PIGZ = config['pigz']
VNC_PORT = config['appliance_vnc_port']
APP_PORT = config['appliance_ssh_port']

class TestApp

  attr_accessor :red

  def initialize server
    @dirname = "#{TESTDIR}/kiwi-#{Time.now.strftime("%Y-%m-%d-%H--%M--%S")}"
    @arch = Shell.remote SERVER, 22, "uname -p"
    @arch = @arch.chomp
    @linux32 = ''
    if ['i386', 'i586', 'i686'].include?(@arch)
      repoarch = 'i386'
      @linux32 = 'linux32'
    else
      repoarch = @arch
    end
    config_xml = File.read './cfg/config.xml.template'
    File.open('./config.xml', 'w') {|file| file.puts config_xml.gsub('#{arch}', repoarch)}
    Shell.remote SERVER, PORT, "mkdir #{@dirname}"
    Shell.scp "./config.xml", SERVER, PORT, "#{@dirname}/config.xml"
    Shell.scp "./cfg/config.sh", SERVER, PORT, @dirname
    Shell.scp "./root", SERVER, PORT, @dirname
  end

  def build type
    if type == 'xen' 
      flavour = 'xenFlavour'
      build_type = 'vmx'
    else
      flavour = 'vmxFlavour'
      build_type = type
    end
    pigz = "--gzip-cmd pigz" if PIGZ
    build_command = "cd #{@dirname} && #{@linux32} /usr/sbin/kiwi -b . --type #{build_type} --add-profile #{flavour} -y #{pigz}"
    Shell.remote SERVER, PORT, "#{build_command} --logfile test#{type}.log -d test#{type}build"
    if self.lvm_capable.include? type
      puts 'Building LVM enabled version...'
      Shell.remote SERVER, PORT, "#{build_command} --logfile test#{type}lvm.log -d test#{type}buildlvm --lvm"
    end
  end

  def testdrive type, opts={}
    defaults = {
      lvm: false
    }
    opts = defaults.merge opts
    if opts[:lvm]
      build_dir = "test#{type}buildlvm"
    else
      build_dir = "test#{type}build"
    end
    begin
    start type, build_dir
    sleep 90 # replace with ssh_accessible? from rstuk
    app_tests
    stop type
    rescue => ex #stop kvm even if app_tests failed 
      stop type
      fail ex
    end
  end

  def lvm_capable
    ['oem', 'vmx', 'xen']
  end

  def stop type
    # screen -ls always returns 1 for some reason
    screenlist = Shell.remote(SERVER, PORT, "screen -ls", 1)
    if screenlist.include? "test#{type}"
      Shell.remote SERVER, PORT, "screen -S 'test#{type}' -X quit"
    end
  end
  
  def cleanup
    Shell.remote SERVER, PORT, "rm -rf '#{@dirname}'"
  end

  private

  def start type, build_dir
    if type == 'vmx'
      image_extension = 'vmdk'
    elsif type == 'oem'
      image_extension = 'raw'
      Shell.remote SERVER, PORT, "qemu-img create -b #{@dirname}/#{build_dir}/LimeJeOS-SLES11SP2.#{@arch}-1.12.1.#{image_extension} #{@dirname}/#{build_dir}/LimeJeOS-SLES11SP2.#{@arch}-1.12.1.qcow2 20G -f qcow2"
      image_extension = 'qcow2'
    elsif type == 'iso'
      image_extension = 'iso'
    end
    image_file = "#{@dirname}/#{build_dir}/LimeJeOS-SLES11SP2.#{@arch}-1.12.1.#{image_extension}"
    if type == 'iso'
      drive = "-cdrom #{image_file}"
    else
      drive = "-drive file=#{image_file},boot=on,if=virtio"
    end
    Shell.remote SERVER, PORT, "screen -S 'test#{type}' -d -m qemu-kvm #{drive} -vnc :#{VNC_PORT} -net nic -net user,hostfwd=tcp::#{APP_PORT}-:22"
  end

  def app_tests
    actual_result = Shell.remote(SERVER, APP_PORT, "zypper products")[/\n(.*)\n$/,1]
    expected_result = "i | @System    | SUSE_SLES     | SUSE Linux Enterprise Server 11 SP2 | 11.2-1.513 | #{@arch} | Yes    "
    actual_result.should == expected_result
    #check for mtab / proc/mounts sync, https://bugzilla.novell.com/show_bug.cgi?id=755915#c57 
    Shell.remote SERVER, APP_PORT, "diff /etc/mtab /proc/mounts"
    #touch /dev/shm to check later if appliance was actually rebooted
    Shell.remote SERVER, APP_PORT, "touch /dev/shm/kiwitest"
    Shell.remote SERVER, APP_PORT, "reboot"
    sleep 60
    Shell.remote SERVER, APP_PORT, "test -f /dev/shm/kiwitest", 1
    actual_result = Shell.remote(SERVER, APP_PORT, "zypper products")[/\n(.*)\n$/,1]
    actual_result.should == expected_result
  end

end

describe "Build and testdrive" do
  before :all do
    @app = TestApp.new SERVER
  end

  after :all do
    @app.cleanup unless @app.red
  end

  after :each do
    @app.red = true if example.exception
  end
    
  image_type_to_test= ['oem', 'vmx', 'xen', 'iso', 'pxe']
  image_type_to_test.each do |type|
    it "Test #{type}" do
      puts "Build #{type}"
      @app.build type
      to_testdrive = ['oem', 'vmx', 'iso']
      if to_testdrive.include? type 
        puts "Testdrive #{type}, reboot, check if it survived"
        @app.testdrive type
        @app.testdrive type, lvm: true if @app.lvm_capable.include? type
      end
    end
  end
end
