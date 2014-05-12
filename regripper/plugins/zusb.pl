#-----------------------------------------------------------
# zusb
#   RegRipper Plugin
#   Display USB device info, actually and very likely the
#   first device connection. 
#   from __future__ import much much more! (ops, that's py!)
#
#   *** WARNING *** POC *** WIP ***
#
# Change history
#
# References
#
# copyright "fpi" francesco.picasso@gmail.com
#-----------------------------------------------------------
package zusb;
use strict;

use Parse::Win32Registry qw( unpack_windows_time
                             unpack_unicode_string
                             unpack_sid
                             unpack_ace
                             unpack_acl
                             unpack_security_descriptor );

my %config = (hive          => "System",
              osmask        => 22,
              hasShortDescr => 1,
              hasDescr      => 0,
              hasRefs       => 0,
              version       => 20991332);

sub getConfig{return %config}

sub getShortDescr {
	return "Collects USB device infoz";
}
sub getDescr{}
sub getRefs {}
sub getHive {return $config{hive};}
sub getVersion {return $config{version};}

my $VERSION = getVersion();

sub pluginmain
{
	my $class = shift;
	my $hive = shift;
	::logMsg("Launching zusb v.".$VERSION);
    ::rptMsg("zusb v.".$VERSION);
    ::rptMsg("(".getHive().") ".getShortDescr()."\n");
	my $reg = Parse::Win32Registry->new($hive);
	my $root_key = $reg->get_root_key;

	my $current;
	my $ccs;
	my $key_path = 'Select';
	my $key;
    
	$key = $root_key->get_subkey($key_path);
    if (!$key) { ::rptMsg($key_path." not found."); return; }
    
    $current = $key->get_value("Current")->get_data();
	$ccs = "ControlSet00".$current;

    # let's index USBSTOR
    my %usbstor_index = indexUsbStor($root_key, $ccs."\\Enum\\USBSTOR");

	$key_path = $ccs."\\Enum\\USB";
	$key = $root_key->get_subkey($key_path);
    if (!$key) { ::rptMsg($key_path." not found."); return; }
    	
    my @subkeys = $key->get_list_of_subkeys();
    ::rptMsg("Got ".scalar(@subkeys)." USB devices\n");
    if (!scalar(@subkeys)) { return; }
    foreach my $s (@subkeys)
    {
        my $tab = '';
        my $deviceID = $s->get_name();
        my $deviceID_rtime = gmtime($s->get_timestamp());
        ::rptMsg('');
        ::rptMsg('deviceID: '.$deviceID);
        ::rptMsg('deviceID registry last written: '.$deviceID_rtime);
        
        my @sk = $s->get_list_of_subkeys();
        ::rptMsg('got '.scalar(@sk).' instances');
        if (!scalar(@sk)) { next; }
        $tab = '  ';
        foreach my $k (@sk)
        {
            my $flag_install_failed = 0;
            my $instanceID = $k->get_name();
            my $instanceID_rtime = gmtime($k->get_timestamp());
            ::rptMsg($tab.'----------');
            ::rptMsg($tab.'instanceID: '.$instanceID);
            ::rptMsg($tab.'instanceID registry last written: '.$instanceID_rtime);
            
            my $class = $k->get_value("Class");
            if ($class) { $class = $class->get_data(); } else { $class = '<no value>'; }
            ::rptMsg($tab.'class: '.$class);
            
            my $service = $k->get_value("Service");
            if ($service) { $service = $service->get_data(); } else { $service = '<no value>'; }
            ::rptMsg($tab.'service: '.$service);
            
            my $driver = $k->get_value("Driver");
            if ($driver) { $driver = $driver->get_data(); } else { $driver = '<no value>'; $flag_install_failed = 1; }
            ::rptMsg($tab.'driver: '.$driver);
            
            # Failed installation
            if ($flag_install_failed) { ::rptMsg($tab.'NOTE: device installation failed'); next; }
            
            my $propk = $k->get_subkey('Properties');
            if (!$propk) { ::rptMsg($tab.'Weird, missing Properties subkey!'); }
            else
            {
                my $bus_device_name = '<no data>';
                # devpkey.h
                # DEVPKEY_Device_BusReportedDeviceDesc {540b947e-8b40-45bc-a8a2-6a0b894cbda2},4
                my $bus_dev_name_key = $propk->get_subkey('{540b947e-8b40-45bc-a8a2-6a0b894cbda2}\\00000004\\00000000');
                if ($bus_dev_name_key)
                {
                    # devpropdef.h
                    # #define DEVPROP_TYPE_STRING 0x00000012  // null-terminated string
                    my $ptype = $bus_dev_name_key->get_value("Type");
                    my $pdata = $bus_dev_name_key->get_value("Data");
                    if ($ptype and $pdata)
                    {
                        if (unpack("V", $ptype->get_data()) == 0x00000012 ) {
                           $bus_device_name = unpack_unicode_string($pdata->get_data());
                        }
                    }
                }
                my $device_install_date = '<no data>';
                # devpkey.h
                # DEVPKEY_Device_InstallDate {83da6326-97a6-4088-9453-a1923f573b29}, 100
                # DEVPKEY_Device_FirstInstallDate {83da6326-97a6-4088-9453-a1923f573b29}, 101
                my $dev_install_date_key = $propk->get_subkey('{83da6326-97a6-4088-9453-a1923f573b29}\\00000064\\00000000');
                if ($dev_install_date_key)
                {
                    # devpropdef.h
                    # #define DEVPROP_TYPE_FILETIME 0x00000010  // file time (FILETIME)
                    my $ptype = $dev_install_date_key->get_value("Type");
                    my $pdata = $dev_install_date_key->get_value("Data");
                    if ($ptype and $pdata)
                    {
                        if (unpack("V", $ptype->get_data()) == 0x00000010 ) {
                            $device_install_date = unpack_windows_time($pdata->get_data());
                            $device_install_date = gmtime($device_install_date);
                        }
                    }
                }
                my $device_first_install_date = '<no data>';
                # devpkey.h
                # DEVPKEY_Device_FirstInstallDate {83da6326-97a6-4088-9453-a1923f573b29}, 101
                my $dev_first_install_date_key = $propk->get_subkey('{83da6326-97a6-4088-9453-a1923f573b29}\\00000065\\00000000');
                if ($dev_first_install_date_key)
                {
                    # devpropdef.h
                    # #define DEVPROP_TYPE_FILETIME 0x00000010  // file time (FILETIME)
                    my $ptype = $dev_first_install_date_key->get_value("Type");
                    my $pdata = $dev_first_install_date_key->get_value("Data");
                    if ($ptype and $pdata)
                    {
                        if (unpack("V", $ptype->get_data()) == 0x00000010 ) {
                            $device_first_install_date = unpack_windows_time($pdata->get_data());
                            $device_first_install_date = gmtime($device_first_install_date);
                        }
                    }
                }
                ::rptMsg($tab.'device name by BUS: '.$bus_device_name);
                ::rptMsg($tab.'device first install date: '.$device_first_install_date);
                ::rptMsg($tab.'device       install date: '.$device_install_date);
                
            }
            
            # going to driver. LastWritten key of driver instance should match
            # the install date, but as usual exceptions exists
            $key_path = $ccs."\\Control\\Class\\".$driver;
            my $okey = $root_key->get_subkey($key_path);            
            if (!$okey) { ::rptMsg($tab."driver path not found!"); }
            else
            {
                my $okey_rtime = gmtime($okey->get_timestamp());
                ::rptMsg($tab.'driver instance registry last written: '.$okey_rtime);
                my $provider_name = $okey->get_value("ProviderName");
                if ($provider_name) { $provider_name = $provider_name->get_data(); } else { $provider_name = '<no value>'; }
                ::rptMsg($tab.'driver provider name: '.$provider_name);

                my $driver_desc = $okey->get_value("DriverDesc");
                if ($driver_desc) { $driver_desc = $driver_desc->get_data(); } else { $driver_desc = '<no value>'; }
                ::rptMsg($tab.'driver description: '.$driver_desc);

                my $inf_section = $okey->get_value("InfSection");
                if ($inf_section) { $inf_section = $inf_section->get_data(); } else { $inf_section = '<no value>'; }
                ::rptMsg($tab.'driver INF section: '.$inf_section);
            }

            if ($service ne 'USBSTOR') { next; }
            if (!$usbstor_index{$instanceID}) { ::rptMsg($tab.'Weird! Cannot find device in USBSTOR!'); next; }

            $key_path = $ccs."\\Enum\\USBSTOR\\".$usbstor_index{$instanceID}[0];
            my $usbstor_family_key = $root_key->get_subkey($key_path);
            if (!$usbstor_family_key) { ::rptMsg($tab."Weird! cannot acces USBSTOR key!!"); next; }

            my $usbstor_key = $usbstor_family_key->get_subkey($usbstor_index{$instanceID}[1]);
            if (!$usbstor_key) { ::rptMsg($tab."Weird! cannot acces USBSTOR instance key!!"); next; }

            my $usbstor_family_name = $usbstor_family_key->get_name();
            my $usbstor_family_key_rtime = gmtime($usbstor_family_key->get_timestamp());
            my $usbstor_name = $usbstor_key->get_name();
            my $usbstor_key_rtime = gmtime($usbstor_key->get_timestamp());
            ::rptMsg($tab.'USBSTOR deviceID: '.$usbstor_family_name);
            ::rptMsg($tab.'USBSTOR deviceID last written: '.$usbstor_family_key_rtime);
            ::rptMsg($tab.'USBSTOR instanceID: '.$usbstor_name);
            ::rptMsg($tab.'USBSTOR instanceID last written: '.$usbstor_key_rtime);

            my $friendly_name = $usbstor_key->get_value("FriendlyName");
            if ($friendly_name) { $friendly_name = $friendly_name->get_data(); } else { $friendly_name = '<no value>'; }
            ::rptMsg($tab.'USBSTOR Friendly Name: '.$friendly_name);

            my $class_usbstor = $usbstor_key->get_value("Class");
            if ($class_usbstor) { $class_usbstor = $class_usbstor->get_data(); } else { $class_usbstor = '<no value>'; }
            ::rptMsg($tab.'USBTOR class: '.$class_usbstor);
            
            my $service_usbstor = $usbstor_key->get_value("Service");
            if ($service_usbstor) { $service_usbstor = $service_usbstor->get_data(); } else { $service_usbstor = '<no value>'; }
            ::rptMsg($tab.'USBSTOR service: '.$service_usbstor);
            
            my $driver_usbstor = $usbstor_key->get_value("Driver");
            if ($driver_usbstor) { $driver_usbstor = $driver_usbstor->get_data(); } else { $driver_usbstor = '<no value>';}
            ::rptMsg($tab.'USBSTOR driver: '.$driver_usbstor);

            if ($service_usbstor ne 'disk') { next; }
            my $diskid_key = $usbstor_key->get_subkey("Device Parameters\\Partmgr");
            if (!$diskid_key) { ::rptMsg($tab."Weird! Cannot access to part manager info!"); next; }
            my $disk_id = $diskid_key->get_value("DiskId");
            if ($disk_id) { $disk_id = $disk_id->get_data(); } else { $disk_id = '<no value>';}
            ::rptMsg($tab.'USBSTOR diskID: '.$disk_id);

            
            
            

        }
    }
}

sub indexUsbStor
{
    my $root_key = shift;
    my $key_path = shift;
    my $key = $root_key->get_subkey($key_path);
    my %usbstor_index;
 
    my @sk = $key->get_list_of_subkeys();
    foreach my $k (@sk)
    {
        my @ik = $k->get_list_of_subkeys();
        foreach my $i (@ik)
        {
            my $iname = $i->get_name();
            my $instanceID = $iname;
            $instanceID =~ s/&[0-9]+$//;
            $usbstor_index{$instanceID} = [$k->get_name(), $iname];
        }
    }
    return %usbstor_index;
}

1;