

use strict;
use warnings;
use Carp;

use Test::More tests => 8;

use Config::Context;

my %Config_Text;

$Config_Text{'ConfigGeneral'} = <<EOF;
    <SeCTION    aaa>
        testval foo
    </SEction>
    <SECTION    aaabbb>
        testval bar
    </section>
    <secTION    aaabbbccc>
        testval baz
    </sECTION>
EOF

$Config_Text{'ConfigScoped'} = <<EOF;
    SeCTION aaa {
        testval = foo
    }

    SECTION aaabbb {
        testval = bar
    }

    secTION aaabbbccc {
        testval = baz
    }
EOF

foreach my $driver (keys %Config_Text) {

    SKIP: {
        my ($conf, %config);

        my $driver_module = 'Config::Context::' . $driver;
        eval "require $driver_module;";
        if ($@) {
            croak "errors requiring $driver_module: $@";
        }
        my $config_module = $driver_module->config_module;
        eval "require $config_module;";

        if ($@) {
            skip "$config_module not installed", 4;
        }

        # Without -LowerCaseNames
        $conf = Config::Context->new(
            driver => $driver,
            string => $Config_Text{$driver},
            match_sections => [
                {
                    name       => 'SectION',
                    match_type => 'substring',
                },
            ],
        );


        %config = $conf->context('wubba');

        %config = $conf->context('aaa');
        ok(!exists $config{'testval'}, "$driver: case sensitive [aaa] testval:   not exists");

        %config = $conf->context('aaabbbccc');
        ok(!exists $config{'testval'}, "$driver: case sensitive [aaabbbccc] testval:   not exists");


        # With -LowerCaseNames
        $conf = Config::Context->new(
            driver           => $driver,
            string           => $Config_Text{$driver},
            lower_case_names => 1,
            match_sections   => [
                {
                    name       => 'SectION',
                    match_type => 'substring',
                },
            ],
        );

        %config = $conf->raw;

        %config = $conf->context('aaa');
        is($config{'testval'},   'foo', "$driver: case insensitive [aaa] testval:   foo");

        %config = $conf->context('aaabbbccc');
        is($config{'testval'},   'baz', "$driver: case insensitive [aaabbbccc] testval:   baz");
    }
}

