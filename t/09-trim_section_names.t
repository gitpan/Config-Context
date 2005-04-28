
use strict;
use warnings;

use Test::More 'no_plan';

use Config::Context;

my %Config_Text;

# This test only makes sense for Config::General
$Config_Text{'ConfigGeneral'} = <<'EOF';

    <Path /foo/ >
        foo = 1
    </Path>

    <Location /bar >
        bar = 1
    </Location>

    <Location2 /bar >
        bar = 1
    </Location2>

EOF


foreach my $driver (keys %Config_Text) {
    SKIP: {

        my $driver_module = 'Config::Context::' . $driver;
        eval "require $driver_module;";
        my $config_module = $driver_module->config_module;
        eval "require $config_module;";

        if ($@) {
            skip "$config_module not installed", 10;
        }

        my $conf = Config::Context->new(
            driver => $driver,
            string => $Config_Text{$driver},
            match_sections => [
                {
                    name          => 'Path',
                    match_type     => 'substring',
                    section_type   => 'path',
                },
                {
                    name             => 'Location',
                    match_type        => 'substring',
                    section_type      => 'location',
                    trim_section_names => 0,
                },
                {
                    name             => 'Location2',
                    match_type        => 'substring',
                    section_type      => 'location2',
                    trim_section_names => undef,
                },
            ],
        );

        my %config;

        %config = $conf->context(path => '/foo/');
        is($config{'foo'}, 1,      "$driver: [path => /foo/] foo: 1");
        ok(!exists $config{'bar'}, "$driver: [path => /foo/] bar: not present");

        %config = $conf->context(location => '/bar');
        ok(!exists $config{'foo'}, "$driver: [location => /bar] foo: not present");
        ok(!exists $config{'bar'}, "$driver: [location => /bar] bar: not present");

        %config = $conf->context(location => '/bar ');
        ok(!exists $config{'foo'}, "$driver: [location => /bar ] foo: not present");
        is($config{'bar'}, 1,      "$driver: [location => /bar ] bar: 1");


        %config = $conf->context(location2 => '/bar');
        ok(!exists $config{'foo'}, "$driver: [location2 => /bar] foo: not present");
        ok(!exists $config{'bar'}, "$driver: [location2 => /bar] bar: not present");

        %config = $conf->context(location2 => '/bar ');
        ok(!exists $config{'foo'}, "$driver: [location2 => /bar ] foo: not present");
        is($config{'bar'}, 1,      "$driver: [location2 => /bar ] bar: 1");
    }
}
