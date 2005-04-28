
use strict;
use warnings;
use Carp;
use Config::Context;
use Test::More 'no_plan';


my $Config_File            = 't/testconf.conf';
my $Containing_Config_File = 't/testconf-container.conf';
my $Included_File          = 'testconf.conf';

sub write_config {
    my $filename = shift;
    my $config   = shift;
    open my $fh, '>', $filename or die "Can't clobber temporary config file $filename: $!\n";
    print $fh $config or die "Can't write to temporary config file $filename: $!\n";
    close $fh;
}

# Version 2.27 and earlier of Config::General
# specified included files relative to the current directory,
# not to the included file.

eval { require Config::General; };

my $CG_Included_File;
if ($Config::General::VERSION > 2.28) {
    $CG_Included_File = $Included_File;
}
else {
    $CG_Included_File = $Config_File;
}


my (%Original_Conf, %Modified_Conf, %Modified_SameSize_Conf, %Containing_Conf);


$Original_Conf{'ConfigGeneral'} = <<EOF;
        original = 1
        modified = 0
        fruit    = banana
        truck    = red
EOF
$Modified_Conf{'ConfigGeneral'} = <<EOF;
        original = 0
        modified = 1
        fruit    = plum
        truck    = red
EOF

$Modified_SameSize_Conf{'ConfigGeneral'} = <<EOF;
        original = 0
        modified = 1
        fruit    = banana
        truck    = RED
EOF


$Containing_Conf{'ConfigGeneral'} = <<EOF;
        <<include $CG_Included_File>>
        container = 1
EOF


$Original_Conf{'ConfigScoped'} = <<EOF;
        original = 1
        modified = 0
        fruit    = banana
        truck    = red
EOF
$Modified_Conf{'ConfigScoped'} = <<EOF;
        original = 0
        modified = 1
        fruit    = plum
        truck    = red
EOF
$Modified_SameSize_Conf{'ConfigScoped'} = <<EOF;
        original = 0
        modified = 1
        fruit    = banana
        truck    = RED
EOF
$Containing_Conf{'ConfigScoped'} = <<EOF;
        %include $Included_File
        container = 1
EOF


$Original_Conf{'XMLSimple'} = <<EOF;
       <opt>
        <original>1</original>
        <modified>0</modified>
        <fruit>banana</fruit>
        <truck>red</truck>
       </opt>
EOF
$Modified_Conf{'XMLSimple'} = <<EOF;
       <opt>
        <original>0</original>
        <modified>1</modified>
        <fruit>plum</fruit>
        <truck>red</truck>
       </opt>
EOF

$Modified_SameSize_Conf{'XMLSimple'} = <<EOF;
       <opt>
        <original>0</original>
        <modified>1</modified>
        <fruit>banana</fruit>
        <truck>RED</truck>
       </opt>
EOF


$Containing_Conf{'XMLSimple'} = <<EOF;
       <opt>
        <xi:include href="$Included_File" xmlns:xi="http://www.w3.org/2001/XInclude" />
        <container>1</container>
       </opt>
EOF


foreach my $driver (keys %Original_Conf) {

    SKIP: {
        my ($conf, %config);

        my $driver_module = 'Config::Context::' . $driver;
        eval "require $driver_module;";

        if ($@) {
            croak "Errors loading $driver_module: $@";
        }
        my $config_module = $driver_module->config_module;
        eval "require $config_module;";

        if ($@) {
            skip "$config_module not installed", 47;
        }

        write_config($Config_File, $Original_Conf{$driver});

        Config::Context->clear_file_cache();

        my ($conf1, $conf2);
        $conf1 = Config::Context->new(
            driver             => $driver,
            file               => $Config_File,
        );
        $conf2 = Config::Context->new(
            driver             => $driver,
            file               => $Config_File,
        );

        ok($conf1->raw eq $conf2->raw, "$driver: Caching ON: raw config objects identical");

        my $config = $conf1->raw;
        is($config->{'original'}, 1,        "$driver: 01.original");
        is($config->{'modified'}, 0,        "$driver: 01.modified");
        is($config->{'fruit'},    'banana', "$driver: 01.fruit");
        is($config->{'truck'},    'red',    "$driver: 01.truck");

        $conf1 = Config::Context->new(
            driver             => $driver,
            file               => $Config_File,
            cache_config_files => 0,
        );
        $conf2 = Config::Context->new(
            driver             => $driver,
            file               => $Config_File,
            cache_config_files => 0,
        );

        ok($conf1->raw ne $conf2->raw, "$driver: Caching OFF: objects differ");

        # Delete file in between first and second read (caching ON)
        $conf1 = Config::Context->new(
            driver             => $driver,
            file               => $Config_File,
        );

        unlink $Config_File;

        eval {
            $conf2 = Config::Context->new(
                driver             => $driver,
                file               => $Config_File,
            );
        };

        ok(!$@, "$driver: Delete, Caching ON, no error");
        ok($conf1->raw eq $conf2->raw, "$driver: Delete, Caching ON:  objects identical");

        # Delete file in between first and second read (caching OFF)
        write_config($Config_File, $Original_Conf{$driver});
        $conf1 = Config::Context->new(
            driver             => $driver,
            file               => $Config_File,
            cache_config_files => 0,
        );

        unlink $Config_File;

        eval {
            $conf2 = Config::Context->new(
                driver             => $driver,
                file               => $Config_File,
                cache_config_files => 0,
            );
        };
        ok($@, "$driver: Delete, Caching OFF, error thrown");



        # Modify before statconfig runs out
        $conf1 = Config::Context->new(
            driver             => $driver,
            file               => $Config_File,
        );

        write_config($Config_File, $Modified_Conf{$driver});

        $conf2 = Config::Context->new(
            driver             => $driver,
            file               => $Config_File,
        );

        ok($conf1->raw eq $conf2->raw, "$driver: Modify before statconfig: Caching ON: objects identical");
        $config = $conf1->raw;
        is($config->{'original'}, 1,        "$driver: 09.original");
        is($config->{'modified'}, 0,        "$driver: 09.modified");
        is($config->{'fruit'},    'banana', "$driver: 09.fruit");
        is($config->{'truck'},    'red',    "$driver: 09.truck");


        # Modify before statconfig runs out (short statconfig)
        write_config($Config_File, $Original_Conf{$driver});
        $conf1 = Config::Context->new(
            driver             => $driver,
            file               => $Config_File,
            stat_config        => 2,
        );

        write_config($Config_File, $Modified_Conf{$driver});
        $conf1 = Config::Context->new(
            driver             => $driver,
            file               => $Config_File,
            stat_config        => 2,
        );

        ok($conf1->raw eq $conf2->raw, "$driver: Modify before (short) statconfig: Caching ON: objects identical");
        $config = $conf1->raw;
        is($config->{'original'}, 1,        "$driver: 11.original");
        is($config->{'modified'}, 0,        "$driver: 11.modified");
        is($config->{'fruit'},    'banana', "$driver: 11.fruit");
        is($config->{'truck'},    'red',    "$driver: 11.truck");

        # Modify after statconfig runs out
        write_config($Config_File, $Original_Conf{$driver});

        $conf1 = Config::Context->new(
            driver             => $driver,
            file               => $Config_File,
            stat_config        => 1,
        );

        sleep 2;
        write_config($Config_File, $Modified_Conf{$driver});

        $conf2 = Config::Context->new(
            driver             => $driver,
            file               => $Config_File,
            stat_config        => 1,
        );

        ok($conf1->raw ne $conf2->raw, "$driver: Modify after statconfig: Caching ON: objects differ");

        $config = $conf1->raw;
        is($config->{'original'}, 1,        "$driver: 13.original");
        is($config->{'modified'}, 0,        "$driver: 13.modified");
        is($config->{'fruit'},    'banana', "$driver: 13.fruit");
        is($config->{'truck'},    'red',    "$driver: 13.truck");

        $config = $conf2->raw;
        is($config->{'original'}, 0,        "$driver: 14.original");
        is($config->{'modified'}, 1,        "$driver: 14.modified");
        is($config->{'fruit'},    'plum',   "$driver: 14.fruit");
        is($config->{'truck'},    'red',    "$driver: 14.truck");

        sleep 2;

        # Modify after statconfig runs out (modified config is same size)
        write_config($Config_File, $Original_Conf{$driver});
        $conf1 = Config::Context->new(
            driver             => $driver,
            file               => $Config_File,
            stat_config        => 1,
        );

        sleep 2;

        write_config($Config_File, $Modified_SameSize_Conf{$driver});
        $conf2 = Config::Context->new(
            driver             => $driver,
            file               => $Config_File,
            stat_config        => 1,
        );

        ok($conf1->raw ne $conf2->raw, "$driver: Modify after statconfig: Caching ON, modified config same size: objects differ");
        $config = $conf1->raw;
        is($config->{'original'}, 1,        "$driver: 15.original");
        is($config->{'modified'}, 0,        "$driver: 15.modified");
        is($config->{'fruit'},    'banana', "$driver: 15.fruit");
        is($config->{'truck'},    'red',    "$driver: 15.truck");

        $config = $conf2->raw;
        is($config->{'original'}, 0,        "$driver: 16.original");
        is($config->{'modified'}, 1,        "$driver: 16.modified");
        is($config->{'fruit'},    'banana', "$driver: 16.fruit");
        is($config->{'truck'},    'RED',    "$driver: 16.truck");


        if ($driver eq 'ConfigGeneral') {
            unless (Config::General->can('files')) {
                skip "Installed Config::General doesn't support 'files'", 11;
            }
        }

        write_config($Config_File, $Original_Conf{$driver});
        write_config($Containing_Config_File, $Containing_Conf{$driver});
        $conf1 = Config::Context->new(
            driver             => $driver,
            file               => $Containing_Config_File,
            stat_config        => 1,
        );

        write_config($Config_File, $Modified_Conf{$driver});
        sleep 2;

        $conf2 = Config::Context->new(
            driver             => $driver,
            file               => $Containing_Config_File,
            stat_config        => 1,
        );

        ok($conf1->raw ne $conf2->raw, "$driver: Include files - Modify after statconfig: Caching ON: objects differ");
        $config = $conf1->raw;
        is($config->{'container'}, 1,        "$driver: 50.container");
        is($config->{'original'},  1,        "$driver: 50.original");
        is($config->{'modified'},  0,        "$driver: 50.modified");
        is($config->{'fruit'},     'banana', "$driver: 50.fruit");
        is($config->{'truck'},     'red',    "$driver: 50.truck");

        $config = $conf2->raw;
        is($config->{'container'}, 1,        "$driver: 51.container");
        is($config->{'original'},  0,        "$driver: 51.original");
        is($config->{'modified'},  1,        "$driver: 51.modified");
        is($config->{'fruit'},     'plum',   "$driver: 51.fruit");
        is($config->{'truck'},     'red',    "$driver: 51.truck");

        unlink $Containing_Config_File;
        unlink $Config_File;
    }
}


