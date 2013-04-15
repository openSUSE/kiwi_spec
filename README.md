kiwi\_spec
==========

KIWI acceptance testing based on RSpec

Instructions
------------

### Installation ###

`make bootstrap` command will install all the required dependencies.

### Configuration ###

A valid authorized\_keys file should be placed in
`root/root/.ssh/authorized_keys`.

Then, copy the `cfg/*.sample` files by removing the .sample suffix,
and edit them accordingly. You should have the following files present:
* `cfg/config.xml.template`
* `cfg/config.sh`
* `cfg/kiwi.yml`

**IMPORTANT:** Do _NOT_ use hardcoded value for the architecture when specifying repositories in config.xml.template.
Instead, you should use `#{arch}` as placeholder. kiwi\_spec will detect the server architecture.  

Example below provides valid repository layout for SLES 11 SP2:
```xml
<repository type="rpm-md">
  <source path="https://nu.novell.com/repo/$RCE/SLES11-SP2-Core/sle-11-#{arch}?credentials=NCCcredentials"/>
</repository>
<repository type="rpm-md">
  <source path="https://nu.novell.com/repo/$RCE/SLES11-SP2-Updates/sle-11-#{arch}?credentials=NCCcredentials"/>
</repository>
<repository type="rpm-md">
  <source path="https://nu.novell.com/repo/$RCE/SLES11-SP1-Pool/sle-11-#{arch}?credentials=NCCcredentials"/>
</repository>
<repository type="rpm-md">
  <source path="https://nu.novell.com/repo/$RCE/SLES11-SP1-Updates/sle-11-#{arch}?credentials=NCCcredentials"/>
</repository>
<repository type="rpm-md" priority="110">
  <source path="https://nu.novell.com/repo/$RCE/SLE11-SDK-SP1-Pool/sle-11-#{arch}?credentials=NCCcredentials"/>
</repository>
<repository type="rpm-md" priority="110">
  <source path="https://nu.novell.com/repo/$RCE/SLE11-SDK-SP1-Updates/sle-11-#{arch}?credentials=NCCcredentials"/>
</repository>
<repository type="rpm-md" priority="110">
  <source path="https://nu.novell.com/repo/$RCE/SLE11-SDK-SP2-Core/sle-11-#{arch}?credentials=NCCcredentials"/>
</repository>
<repository type="rpm-md" priority="110">
  <source path="https://nu.novell.com/repo/$RCE/SLE11-SDK-SP2-Updates/sle-11-#{arch}?credentials=NCCcredentials"/>
</repository>
```
Also notice priority of 110 on SDK repositories. It is important for 11-SP2 appliances.

### Run ###

`make kiwi_spec` will run the RSpec tests.
